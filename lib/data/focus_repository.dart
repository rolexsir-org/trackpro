import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart' show debugPrint;

import '../models/focus_models.dart';
import '../services/focus_platform.dart';
import '../util/day_key.dart';
import 'db/database.dart';
import 'focus_engine.dart';

/// Focus Lock's storage: the live session, its checkpoints, its verdict, and the
/// profiles and schedules around it.
///
/// The shape of this class follows one rule: **a focus session is a fact, not a
/// widget**. The countdown on screen is derived from the row, never the other way
/// around, so closing the app, killing the process, rebooting the phone or updating
/// the app cannot change what happened — at worst it costs the seconds since the
/// last checkpoint, and that loss is reported rather than rounded away.
///
/// Four properties are worth stating because they are the ones a reviewer should
/// check:
///
///  1. **Recovery is idempotent.** [recover] reads the one open row, decides what
///     its state must be from the clocks and the platform's report, writes the
///     verdict if it is over, and returns. Run it twice and the second run finds no
///     open row and does nothing. There is no path where a session is ended twice
///     or resurrected.
///  2. **There is at most one live session.** [start] refuses when one exists;
///     [recover] repairs the impossible case (two open rows, from a crash between
///     two writes) by ending the older one as interrupted — a repair that keeps the
///     row and says what happened, rather than deleting evidence.
///  3. **The verdict comes from the engine.** [finish] computes the outcome with
///     `FocusEngine.outcomeFor`; nothing in this file can mark a session complete.
///  4. **Nothing here claims blocking.** Enforcement is whatever the platform
///     reported, funnelled through `FocusEngine.enforcementFor`.
class FocusRepository {
  FocusRepository(
    this.db, {
    this.now = DateTime.now,
    FocusEnforcer? enforcer,
    String Function()? idFactory,
  })  : enforcer = enforcer ?? const NoFocusEnforcer(),
        _idFactory = idFactory;

  final TrackDatabase db;
  FocusDao get dao => db.focusDao;

  /// Injectable clock, so the tests can drive a session through a whole hour
  /// without waiting for one. Note this is the *wall* clock; the monotonic clock
  /// comes from the platform and is stubbed through the enforcer in tests.
  final DateTime Function() now;

  /// The platform seam. Defaults to [NoFocusEnforcer], which reports every
  /// capability as absent: a repository without a platform can time a session but
  /// can never claim to have blocked anything.
  final FocusEnforcer enforcer;

  final String Function()? _idFactory;

  final List<FocusSession> _sessions = <FocusSession>[];
  final List<FocusProfile> _profiles = <FocusProfile>[];
  final List<FocusSchedule> _schedules = <FocusSchedule>[];

  int _idCounter = 0;

  /// Monotonic instant at which the live row was last written (or read back).
  ///
  /// The checkpoint rule is "write at most every [checkpointMs]", and it has to be
  /// measured against what is *in the database*, not against the in-memory
  /// projection — the projection moves every tick, which would make the comparison
  /// permanently smaller than the interval and skip every write.
  int? _lastCheckpointRealtimeMs;

  /// One sync at a time. A foreground, a one-second tick and a lifecycle callback
  /// can arrive together; letting two of them reconcile the same live row means two
  /// writes and, at expiry, two endings for one session.
  bool _syncing = false;

  /// Today, as the local day key every other part of the app uses.
  int get todayKey => dayKey(now());

  /// How much history is loaded. Bounded: the history screen draws weeks, and a
  /// list that grows without limit is a leak with extra steps.
  static const int loadSessions = 400;
  static const int loadDays = 400;

  /// How often a live session is written back. Every tick would be 3,600 writes an
  /// hour; this bounds the worst-case loss from a process death to [checkpointMs]
  /// while keeping the write rate trivial.
  static const int checkpointMs = 15000;

  List<FocusSession> get sessions => List<FocusSession>.unmodifiable(_sessions);
  List<FocusProfile> get profiles => List<FocusProfile>.unmodifiable(_profiles);
  List<FocusSchedule> get schedules => List<FocusSchedule>.unmodifiable(_schedules);

  /// The one live session, if any. Newest first in the list; recovery guarantees
  /// there cannot be more than one.
  FocusSession? get liveSession {
    for (final s in _sessions) {
      if (s.isLive) return s;
    }
    return null;
  }

  /// Ended sessions, newest first.
  List<FocusSession> get history =>
      [for (final s in _sessions) if (s.state == FocusSessionState.ended) s];

  FocusSession? byId(String id) {
    for (final s in _sessions) {
      if (s.id == id) return s;
    }
    return null;
  }

  // ---------------------------------------------------------------- hydrate
  Future<void> hydrate() async {
    var from = dayKey(now());
    for (var i = 1; i < loadDays; i++) {
      from = previousDayKey(from);
    }

    _sessions
      ..clear()
      ..addAll([
        for (final row in await dao.allSessions(fromDay: from)) _toModel(row),
      ]);

    _profiles
      ..clear()
      ..addAll([
        for (final row in await dao.allProfiles())
          FocusProfile(
            id: row.id,
            name: row.name,
            mode: FocusMode.fromStorage(row.mode) ?? FocusMode.standard,
            minutes: row.minutes,
            commitmentId: row.commitmentId,
            packages: _decodeList(row.packagesJson),
            sort: row.sort,
          ),
      ]);

    _schedules
      ..clear()
      ..addAll([
        for (final row in await dao.allSchedules())
          FocusSchedule(
            id: row.id,
            mode: FocusMode.fromStorage(row.mode) ?? FocusMode.standard,
            minutes: row.minutes,
            hour: row.hour,
            minute: row.minute,
            weekdays: _decodeWeekdays(row.weekdaysJson),
            commitmentId: row.commitmentId,
            packages: _decodeList(row.packagesJson),
            enabled: row.enabled,
            notificationId: row.notificationId,
          ),
      ]);

    await _repairMultipleLiveSessions();
    _lastCheckpointRealtimeMs = liveSession?.segmentStartedAtRealtimeMs;
  }

  /// The state that should be impossible: two open rows. It can only come from a
  /// crash between two writes, and it cannot be fixed by pretending it did not
  /// happen — the older session is ended as interrupted, which is the truth about a
  /// session nothing was supervising, and both rows stay in the history.
  Future<void> _repairMultipleLiveSessions() async {
    final live = [for (final s in _sessions) if (s.isLive) s];
    if (live.length < 2) return;
    live.sort((a, b) => a.startedAtWallMs.compareTo(b.startedAtWallMs));
    for (final stale in live.sublist(0, live.length - 1)) {
      await finish(
        stale,
        reason: FocusEndReason.serviceLost,
        // The newer session's enforcement service is the one that is running; the
        // repair must not switch it off.
        stopEnforcement: false,
        reasonNote: 'a second session was started before this one was closed',
      );
    }
  }

  /// Carries forward evidence of an unenforced interval. A later healthy service
  /// can prove that it works *now*; it cannot prove that it covered the portion of
  /// this same session that ran before it was healthy.
  ///
  /// `armed` deliberately remains upgradeable to `verified`: it means the service
  /// and grants were present but no selected app had yet been observed, not that an
  /// unprotected interval is known to have happened.
  FocusEnforcement _carryEnforcementHistory(
    FocusEnforcement previous,
    FocusEnforcement reported,
  ) {
    if (previous == FocusEnforcement.lost) return FocusEnforcement.lost;
    if (previous == FocusEnforcement.unavailable &&
        reported != FocusEnforcement.unavailable &&
        reported != FocusEnforcement.timerOnly) {
      return FocusEnforcement.lost;
    }
    return reported;
  }

  // ------------------------------------------------------------------ start
  /// Starts a session. The row is written **before** the platform is asked to
  /// enforce anything, so a crash between the two steps leaves a recoverable
  /// session rather than an enforcement service with nothing recording it.
  ///
  /// [requestedPackages] is sanitised here as well as on the platform side:
  /// protected packages (dialer, launcher, system UI, keyboards, Track Pro itself) can
  /// never end up in a block list, whatever a caller passes.
  Future<FocusSession> start({
    required FocusMode mode,
    required int minutes,
    required List<String> requestedPackages,
    String? commitmentId,
    String? goalLabel,
    int accentArgb = 0xFF5B7CFA,
  }) async {
    final existing = liveSession;
    if (existing != null) {
      throw StateError(
        'FocusRepository.start called while session ${existing.id} is live. '
        'There is at most one live session; the caller must end or recover it first.',
      );
    }

    final wall = now();
    final monotonic = await enforcer.monotonicMs();
    final deviceProtected = await enforcer.protectedPackages();
    final sanitized = FocusEngine.sanitizeBlockList(requestedPackages, deviceProtected: deviceProtected);
    final plannedMinutes = FocusEngine.clampMinutes(minutes);
    final wantsBlocking = mode != FocusMode.standard && sanitized.allowed.isNotEmpty;

    var session = FocusSession(
      id: _newId(),
      mode: mode,
      plannedMinutes: plannedMinutes,
      goalLabel: (goalLabel ?? '').trim().isEmpty ? 'Focus session' : goalLabel!.trim(),
      commitmentId: commitmentId,
      startedAtWallMs: wall.millisecondsSinceEpoch,
      startedAtRealtimeMs: monotonic ?? 0,
      // The segment only starts accruing once we know the monotonic clock. With no
      // monotonic clock the wall clock is used and the session is marked as
      // unverified timing, which the summary states in words.
      segmentStartedAtRealtimeMs: monotonic,
      enforcement: FocusEnforcement.unavailable,
      timingVerified: monotonic != null,
      blockedPackages: sanitized.allowed,
      day: dayKey(wall),
    );

    await dao.upsert(_toRow(session));

    if (wantsBlocking) {
      final started = await enforcer.startSession(
        sessionId: session.id,
        mode: mode.storage,
        plannedMinutes: plannedMinutes,
        endsAtRealtimeMs: (monotonic ?? 0) + session.plannedMs,
        packages: sanitized.allowed,
        block: true,
        label: session.goalLabel,
        accentArgb: accentArgb,
      );
      final native = started ? await enforcer.state() : FocusNativeState.idle;
      session = session.copyWith(
        // A start that the platform refused was never running — it is `unavailable`,
        // not `lost` (which means enforcement stopped mid-session).
        // A launch that returned true but did not leave the actual blocking
        // service alive is an initial setup failure, not a "lost" session. `lost`
        // is reserved for something that was running and stopped later.
        enforcement: started && native.running && native.blocking
            ? FocusEngine.enforcementFor(
                blockingRequested: true,
                serviceAlive: true,
                permissionLostMidSession: false,
                overlayGranted: native.overlay,
                usageAccessGranted: native.usageAccess,
                detectionEvents: native.detectionEvents,
                overlayShows: native.overlayShows,
              )
            : FocusEnforcement.unavailable,
        blockedAttempts: native.blockedAttempts,
        overlayShows: native.overlayShows,
        detectionEvents: native.detectionEvents,
      );
      await dao.upsert(_toRow(session));
    } else {
      session = session.copyWith(enforcement: FocusEnforcement.timerOnly);
      await dao.upsert(_toRow(session));
    }

    _sessions.insert(0, session);
    _lastCheckpointRealtimeMs = monotonic;
    return session;
  }

  // ------------------------------------------------------------- checkpoint
  /// Re-reads the platform and writes what it reported onto the live session.
  ///
  /// Called on a timer while a session runs, and on every app lifecycle change.
  /// Returns the reconciled session, or null when there was nothing live to update
  /// — which is how the caller learns the session ended while it was away.
  Future<FocusSession?> syncNative({bool force = false}) async {
    final live = liveSession;
    if (live == null) return null;
    if (_syncing) return live;
    _syncing = true;
    try {
      return await _syncNative(live, force: force);
    } finally {
      _syncing = false;
    }
  }

  Future<FocusSession?> _syncNative(FocusSession live, {required bool force}) async {
    final monotonic = await enforcer.monotonicMs();
    final recovery = FocusEngine.recover(
      session: live,
      nowRealtimeMs: monotonic ?? 0,
      nowWallMs: now().millisecondsSinceEpoch,
      monotonicAvailable: monotonic != null,
    );

    // A reboot ends the session before any time arithmetic matters: Track Pro no
    // longer knows what happened while the phone was off.
    if (recovery.rebooted) {
      return finish(live, reason: FocusEndReason.deviceRestarted);
    }

    // Blocking is deliberately suspended while paused. `pause()` stops the
    // foreground service, so treating that expected stopped state as a service
    // failure would permanently label every paused blocking session `lost` on the
    // next one-second tick. If the final focused second was already served, finish
    // from the stored evidence rather than blaming the intentionally stopped service.
    if (live.state == FocusSessionState.paused) {
      if (recovery.expired) {
        return finish(
          live,
          reason: FocusEndReason.timer,
          focusMs: live.plannedMs,
        );
      }
      return live;
    }

    final native = await enforcer.state();
    final blockingRequested = live.enforcement.intendsToBlock;
    // A session that began with a working/armed mechanism and then loses a required
    // grant is `lost`, not merely `unavailable`. The distinction records that some
    // portion of this very session was no longer enforced.
    final permissionLostMidSession = blockingRequested &&
        live.enforcement != FocusEnforcement.unavailable &&
        (!native.overlay || !native.usageAccess);

    // While time remains, a stopped service or a revoked permission degrades the
    // live session's enforcement (`lost` or `unavailable`) rather than killing the
    // timer underneath the user — the session screen shows the honesty banner and
    // the user can finish the timer or end by hand. When the planned time is behind
    // us (`recovery.expired`), either event is recorded as an interruption rather
    // than silently becoming a timer completion.
    if (recovery.expired) {
      if (permissionLostMidSession) {
        return finish(live, reason: FocusEndReason.permissionRevoked, native: native, focusMs: live.plannedMs);
      }
      if (live.enforcement == FocusEnforcement.lost ||
          (blockingRequested && (!native.running || !native.blocking))) {
        return finish(live, reason: FocusEndReason.serviceLost, native: native, focusMs: live.plannedMs);
      }
      return finish(
        live,
        reason: FocusEndReason.timer,
        native: native.running ? native : null,
        focusMs: live.plannedMs,
      );
    }

    final reportedEnforcement = FocusEngine.enforcementFor(
      blockingRequested: blockingRequested,
      serviceAlive: blockingRequested ? native.running && native.blocking : true,
      permissionLostMidSession: permissionLostMidSession,
      overlayGranted: blockingRequested ? native.overlay : true,
      usageAccessGranted: blockingRequested ? native.usageAccess : true,
      detectionEvents: native.detectionEvents,
      overlayShows: native.overlayShows,
    );
    // A later re-grant/restart cannot rewrite the part of this same session that
    // was already unprotected. Resume may re-arm the native service, but the record
    // remains honest about the gap.
    final enforcement = _carryEnforcementHistory(live.enforcement, reportedEnforcement);

    // `recovery.elapsedMs` is `focusMs + (now - segmentStartedAtRealtimeMs)`.
    // Banking it into `focusMs` while leaving the old segment start in place would
    // make the *next* recovery add the same stretch again — which is why a session
    // used to gain time on every checkpoint, and why reopening the app mid-session
    // could jump the countdown forward by minutes. The segment restarts at the same
    // instant the elapsed figure is banked, so the two always describe the same
    // moment.
    final rebased = live.state == FocusSessionState.running && monotonic != null;
    final updated = live.copyWith(
      focusMs: recovery.elapsedMs,
      segmentStartedAtRealtimeMs: rebased ? monotonic : null,
      enforcement: enforcement,
      blockedAttempts: native.blockedAttempts,
      overlayShows: native.overlayShows,
      detectionEvents: native.detectionEvents,
      timingVerified: recovery.monotonicTrusted,
    );
    _replace(updated);

    // The row is only rewritten when something moved (or the caller forced it), so
    // a one-second UI tick is not a one-second database write.
    final sinceCheckpoint = monotonic == null || _lastCheckpointRealtimeMs == null
        ? checkpointMs
        : monotonic - _lastCheckpointRealtimeMs!;
    final moved = sinceCheckpoint >= checkpointMs ||
        updated.blockedAttempts != live.blockedAttempts ||
        updated.overlayShows != live.overlayShows ||
        updated.detectionEvents != live.detectionEvents ||
        updated.enforcement != live.enforcement ||
        force;
    if (moved) {
      await dao.upsert(_toRow(updated));
      _lastCheckpointRealtimeMs = monotonic;
    }
    return updated;
  }

  // ------------------------------------------------------------- pause / end
  Future<FocusSession?> pause() async {
    final live = liveSession;
    if (live == null || live.state != FocusSessionState.running) return live;
    final monotonic = await enforcer.monotonicMs();
    final recovery = FocusEngine.recover(
      session: live,
      nowRealtimeMs: monotonic ?? 0,
      nowWallMs: now().millisecondsSinceEpoch,
      monotonicAvailable: monotonic != null,
    );
    // A tap that races the final second must not turn a served session into a
    // paused one; reconciliation records the real timer/service verdict instead.
    if (recovery.expired) return _syncNative(live, force: true);
    final paused = live.copyWith(
      state: FocusSessionState.paused,
      focusMs: recovery.elapsedMs,
      pausedMs: live.pausedMs,
      pausedAtWallMs: now().millisecondsSinceEpoch,
      clearSegment: true,
    );
    await dao.upsert(_toRow(paused));
    _lastCheckpointRealtimeMs = monotonic;
    _replace(paused);

    // The setup sheet promises that a pause stops covering the selected apps, and
    // that promise was false: the service kept running on its own fixed end time, so
    // apps stayed out of reach while the countdown stood still. Stopping the native
    // session here is what makes the copy true; [resume] re-arms it for the time
    // that is actually left.
    if (live.mode != FocusMode.standard && paused.blockedPackages.isNotEmpty) {
      await enforcer.stopSession();
    }
    return paused;
  }

  /// Resumes a paused session. The paused stretch is banked first, so the countdown
  /// cannot silently include it.
  Future<FocusSession?> resume() async {
    final live = liveSession;
    if (live == null || live.state != FocusSessionState.paused) return live;
    final monotonic = await enforcer.monotonicMs();
    final wall = now().millisecondsSinceEpoch;
    // The pause is banked here, not at the end: whatever happens next, the time the
    // user was not focusing is already accounted for and cannot be counted as focus.
    final sincePause = live.pausedAtWallMs == null ? 0 : (wall - live.pausedAtWallMs!).clamp(0, 24 * 3600 * 1000).toInt();
    // Focus time, unlike wall time, does not advance while paused. A session that
    // was paused exactly at its final focused second is already complete; do not
    // resurrect it into a zero-second running row.
    if (live.focusMs >= live.plannedMs) {
      return finish(live, reason: FocusEndReason.timer, focusMs: live.plannedMs);
    }
    var resumed = live.copyWith(
      state: FocusSessionState.running,
      segmentStartedAtRealtimeMs: monotonic,
      clearSegment: monotonic == null,
      clearPause: true,
      pausedMs: live.pausedMs + sincePause,
    );
    await dao.upsert(_toRow(resumed));
    _lastCheckpointRealtimeMs = monotonic;
    _replace(resumed);

    // A long pause can outlive the platform's own end time: the service stops at
    // start + planned minutes, because it counts wall time and knows nothing about
    // pauses. Resuming used to leave a running timer with a dead detector, so the
    // rest of the session was recorded as unenforced. The platform seam can start the
    // same session id again for the time that is actually left.
    if (resumed.enforcement.intendsToBlock && resumed.blockedPackages.isNotEmpty) {
      if (monotonic == null) {
        // The platform service needs a monotonic expiry. Without one, this resumed
        // stretch is a timer-only stretch even if the part before the pause was
        // verified; it must not inherit that earlier proof.
        resumed = resumed.copyWith(
          enforcement: _carryEnforcementHistory(resumed.enforcement, FocusEnforcement.lost),
          timingVerified: false,
        );
        await dao.upsert(_toRow(resumed));
        _replace(resumed);
      } else {
        final nativeBeforeStart = await enforcer.state();
        if (!nativeBeforeStart.running || !nativeBeforeStart.blocking) {
          final leftMs = (resumed.plannedMs - resumed.focusMs).clamp(0, resumed.plannedMs).toInt();
          if (leftMs > 0) {
            final started = await enforcer.startSession(
              sessionId: resumed.id,
              mode: resumed.mode.storage,
              plannedMinutes: (leftMs / 60000).ceil().clamp(1, 24 * 60).toInt(),
              endsAtRealtimeMs: monotonic + leftMs,
              packages: resumed.blockedPackages,
              block: true,
              label: resumed.goalLabel,
              // The accent is presentation only; the session row is the record.
              accentArgb: 0xFF5B7CFA,
            );
            // A failed re-arm leaves the *resumed* part of the session uncovered.
            // That is a genuine mid-session loss, unlike a failed initial launch.
            final native = await enforcer.state();
            final reported = started
                ? FocusEngine.enforcementFor(
                    blockingRequested: true,
                    serviceAlive: native.running && native.blocking,
                    permissionLostMidSession: resumed.enforcement != FocusEnforcement.unavailable &&
                        (!native.overlay || !native.usageAccess),
                    overlayGranted: native.overlay,
                    usageAccessGranted: native.usageAccess,
                    detectionEvents: native.detectionEvents,
                    overlayShows: native.overlayShows,
                  )
                : FocusEnforcement.lost;
            resumed = resumed.copyWith(
              enforcement: _carryEnforcementHistory(resumed.enforcement, reported),
              blockedAttempts: native.blockedAttempts,
              overlayShows: native.overlayShows,
              detectionEvents: native.detectionEvents,
            );
            await dao.upsert(_toRow(resumed));
            _replace(resumed);
          }
        }
      }
    }
    return resumed;
  }

  /// Ends the session by hand. [reason] defaults to [FocusEndReason.cancelled];
  /// pass [FocusEndReason.userEnded] when the time was already served.
  Future<FocusSession?> endByHand({String? reflection}) async {
    final live = liveSession;
    if (live == null) return null;
    final monotonic = await enforcer.monotonicMs();
    final recovery = FocusEngine.recover(
      session: live,
      nowRealtimeMs: monotonic ?? 0,
      nowWallMs: now().millisecondsSinceEpoch,
      monotonicAvailable: monotonic != null,
    );
    final native = await enforcer.state();
    return finish(
      live,
      reason: recovery.expired ? FocusEndReason.userEnded : FocusEndReason.cancelled,
      native: native,
      focusMs: recovery.elapsedMs,
      reflection: reflection,
    );
  }

  /// Writes the verdict for a session. **The only way an outcome is decided.**
  ///
  /// The paused time is banked from the monotonic clock first, so a session that
  /// was paused for ten minutes never reports those ten minutes as focus time, and
  /// the pause budget check has the real number to work with.
  Future<FocusSession> finish(
    FocusSession session, {
    required FocusEndReason reason,
    FocusNativeState? native,
    int? focusMs,
    String? reflection,
    String? reasonNote,
    bool stopEnforcement = true,
  }) async {
    final monotonic = await enforcer.monotonicMs();
    final wall = now().millisecondsSinceEpoch;
    final recovery = FocusEngine.recover(
      session: session,
      nowRealtimeMs: monotonic ?? 0,
      nowWallMs: wall,
      monotonicAvailable: monotonic != null,
    );

    // Paused time is whatever wall time is unaccounted for; on a session that ended
    // while paused, that is everything since the last checkpoint.
    var bankedFocus = focusMs ?? recovery.elapsedMs;
    if (bankedFocus > session.plannedMs) bankedFocus = session.plannedMs;
    var paused = session.pausedMs;
    if (session.state == FocusSessionState.paused && session.pausedAtWallMs != null) {
      // The final pause is banked from its own start, so the pause budget is judged
      // on the real number even when the session ends while paused.
      paused += (wall - session.pausedAtWallMs!).clamp(0, 24 * 3600 * 1000).toInt();
    }

    // `pause()` intentionally stops the coverage service. Ending from that state
    // must preserve the evidence collected before the pause, rather than convert
    // an expected idle native state into a fictional service failure.
    final enforcementSuspendedByPause = session.state == FocusSessionState.paused &&
        reason != FocusEndReason.permissionRevoked &&
        reason != FocusEndReason.serviceLost;
    final permissionLostMidSession = !enforcementSuspendedByPause &&
        native != null &&
        session.enforcement.intendsToBlock &&
        session.enforcement != FocusEnforcement.unavailable &&
        (!native.overlay || !native.usageAccess);
    final reportedEnforcement = native == null || enforcementSuspendedByPause
        ? session.enforcement
        : FocusEngine.enforcementFor(
            blockingRequested: session.enforcement.intendsToBlock || native.blocking,
            serviceAlive: native.running &&
                (session.enforcement.intendsToBlock ? native.blocking : true),
            permissionLostMidSession: permissionLostMidSession,
            overlayGranted: native.overlay,
            usageAccessGranted: native.usageAccess,
            detectionEvents: native.detectionEvents,
            overlayShows: native.overlayShows,
          );
    final enforcement = _carryEnforcementHistory(session.enforcement, reportedEnforcement);

    final outcome = FocusEngine.outcomeFor(
      mode: session.mode,
      focusMs: bankedFocus,
      plannedMs: session.plannedMs,
      enforcement: enforcement,
      reason: reason,
      timingVerified: session.timingVerified && recovery.monotonicTrusted,
      pausedMs: paused,
    );

    final ended = session.copyWith(
      state: FocusSessionState.ended,
      outcome: outcome,
      enforcement: enforcement,
      endReason: reason,
      focusMs: bankedFocus,
      pausedMs: paused,
      clearSegment: true,
      endedAtWallMs: wall,
      blockedAttempts: native?.blockedAttempts ?? session.blockedAttempts,
      overlayShows: native?.overlayShows ?? session.overlayShows,
      detectionEvents: native?.detectionEvents ?? session.detectionEvents,
      timingVerified: session.timingVerified && recovery.monotonicTrusted,
      reflection: reflection ?? session.reflection,
    );

    await dao.endSession(
      id: ended.id,
      focusMs: ended.focusMs,
      pausedMs: ended.pausedMs,
      outcome: ended.outcome!.storage,
      endReason: ended.endReason!.storage,
      enforcement: ended.enforcement.storage,
      blockedAttempts: ended.blockedAttempts,
      overlayShows: ended.overlayShows,
      detectionEvents: ended.detectionEvents,
      timingVerified: ended.timingVerified,
      endedAtWallMs: ended.endedAtWallMs!,
      reflection: ended.reflection,
    );

    _replace(ended);
    _lastCheckpointRealtimeMs = null;
    if (stopEnforcement) await enforcer.stopSession();
    debugPrint(
      'FocusRepository: session ${ended.id} ended as ${outcome.storage} '
      '(${reason.storage}, enforcement ${enforcement.storage}'
      '${reasonNote == null ? '' : ', $reasonNote'})',
    );
    return ended;
  }

  // ---------------------------------------------------------------- recovery
  /// Called once at start-up and again on every foreground.
  ///
  /// Returns the session that was repaired, or null when there was nothing to
  /// repair. Idempotent by construction: the verdict is written once, and the
  /// second call finds no open row.
  Future<FocusSession?> recover() async {
    final live = liveSession;
    if (live == null) return null;

    // Let the platform have the first word: if the service is still running, it has
    // been counting the whole time and its numbers are the ones to use.
    return syncNative(force: true);
  }

  /// Writes the platform's view of the enforcement for a *running* session without
  /// waiting for the next tick. Called right after the app returns to the
  /// foreground, and after the user grants a permission mid-session.
  Future<FocusSession?> refreshEnforcement() => syncNative(force: true);

  // ------------------------------------------------------------- reflection
  Future<FocusSession?> setReflection(String id, String? text) async {
    final session = byId(id);
    if (session == null) return null;
    final trimmed = (text ?? '').trim();
    final updated = session.copyWith(reflection: trimmed.isEmpty ? '' : trimmed);
    await dao.setReflection(id, trimmed.isEmpty ? null : trimmed);
    _replace(updated);
    return updated;
  }

  // ---------------------------------------------------------------- profiles
  Future<FocusProfile> saveProfile({
    String? id,
    required String name,
    required FocusMode mode,
    required int minutes,
    String? commitmentId,
    List<String> packages = const <String>[],
  }) async {
    final deviceProtected = await enforcer.protectedPackages();
    final sanitized = FocusEngine.sanitizeBlockList(packages, deviceProtected: deviceProtected);
    final trimmed = name.trim().isEmpty ? '${mode.shortLabel} ${minutes}m' : name.trim();
    final profile = FocusProfile(
      id: id ?? _newId(),
      name: trimmed,
      mode: mode,
      minutes: FocusEngine.clampMinutes(minutes),
      commitmentId: commitmentId,
      packages: sanitized.allowed,
      sort: _profiles.length,
    );
    await dao.upsertProfile(FocusProfilesCompanion.insert(
      id: profile.id,
      name: profile.name,
      mode: profile.mode.storage,
      minutes: profile.minutes,
      commitmentId: Value(profile.commitmentId),
      packagesJson: Value(jsonEncode(profile.packages)),
      sort: Value(profile.sort),
    ));
    _profiles.removeWhere((p) => p.id == profile.id);
    _profiles.add(profile);
    return profile;
  }

  Future<void> deleteProfile(String id) async {
    await dao.deleteProfile(id);
    _profiles.removeWhere((p) => p.id == id);
  }

  // --------------------------------------------------------------- schedules
  /// Saves a recurring reminder. [notificationId] is generated here and stored, so
  /// the schedule can always cancel exactly what it scheduled.
  Future<FocusSchedule> saveSchedule({
    String? id,
    required FocusMode mode,
    required int minutes,
    required int hour,
    required int minute,
    Set<int> weekdays = const <int>{},
    String? commitmentId,
    List<String> packages = const <String>[],
    bool enabled = true,
  }) async {
    final existingMatches = id == null ? const <FocusSchedule>[] : _schedules.where((s) => s.id == id);
    final existing = existingMatches.isEmpty ? null : existingMatches.first;
    final deviceProtected = await enforcer.protectedPackages();
    final sanitized = FocusEngine.sanitizeBlockList(packages, deviceProtected: deviceProtected);
    final schedule = FocusSchedule(
      id: id ?? _newId(),
      mode: mode,
      minutes: FocusEngine.clampMinutes(minutes),
      hour: hour.clamp(0, 23).toInt(),
      minute: minute.clamp(0, 59).toInt(),
      weekdays: weekdays,
      commitmentId: commitmentId,
      packages: sanitized.allowed,
      enabled: enabled,
      // Stable across edits of the same schedule, so rescheduling replaces rather
      // than duplicates.
      notificationId: existing?.notificationId ?? _nextNotificationId(),
    );
    await dao.upsertSchedule(FocusSchedulesCompanion.insert(
      id: schedule.id,
      mode: schedule.mode.storage,
      minutes: schedule.minutes,
      hour: schedule.hour,
      minute: schedule.minute,
      weekdaysJson: Value(jsonEncode(schedule.weekdays.toList()..sort())),
      commitmentId: Value(schedule.commitmentId),
      packagesJson: Value(jsonEncode(schedule.packages)),
      enabled: Value(schedule.enabled),
      notificationId: schedule.notificationId,
    ));
    _schedules.removeWhere((s) => s.id == schedule.id);
    _schedules.add(schedule);
    return schedule;
  }

  Future<void> setScheduleEnabled(String id, {required bool enabled}) async {
    await dao.setScheduleEnabled(id, enabled: enabled);
    final i = _schedules.indexWhere((s) => s.id == id);
    if (i >= 0) _schedules[i] = _schedules[i].copyWith(enabled: enabled);
  }

  Future<void> deleteSchedule(String id) async {
    await dao.deleteSchedule(id);
    _schedules.removeWhere((s) => s.id == id);
  }

  // -------------------------------------------------------------------- stats
  Future<FocusStats> stats({required int todayKey}) async =>
      FocusEngine.statsFor(_sessions, todayKey: todayKey);

  /// Minutes focused today, from the rows. Used by Today's focus card so it cannot
  /// disagree with the history.
  int minutesOn(int day) {
    var ms = 0;
    for (final s in _sessions) {
      if (s.day != day) continue;
      if (s.state != FocusSessionState.ended) continue;
      if (!(s.outcome?.servedTime ?? false)) continue;
      ms += s.focusMs;
    }
    return (ms / 60000).round();
  }

  // ------------------------------------------------------------------- export
  /// Focus sessions and schedules, for the user's own export.
  ///
  /// What is *not* here: any usage history. The app never collects which apps were
  /// used or for how long — it reacts to the foreground app during a session and
  /// keeps only the package ids the user chose to restrict, plus a count. That
  /// restraint is the reason this export can be handed to anyone.
  Map<String, Object?> exportPayload() => {
        'format': 'track.focus.v1',
        'totals': {
          'sessions': _sessions.length,
          'ended': history.length,
          'live': liveSession == null ? 0 : 1,
          'profiles': _profiles.length,
          'schedules': _schedules.length,
        },
        'sessions': [
          for (final s in _sessions)
            {
              'id': s.id,
              'mode': s.mode.storage,
              'goal': s.goalLabel,
              'routine': s.commitmentId,
              'date': isoDayKey(s.day),
              'planned_minutes': s.plannedMinutes,
              'focused_ms': s.focusMs,
              'paused_ms': s.pausedMs,
              'state': s.state.storage,
              'outcome': s.outcome?.storage,
              'end_reason': s.endReason?.storage,
              'enforcement': s.enforcement.storage,
              'timing_verified': s.timingVerified,
              'blocked_attempts': s.blockedAttempts,
              'blocked_apps': s.blockedPackages,
              'reflection': s.reflection,
            },
        ],
        'profiles': [
          for (final p in _profiles)
            {'id': p.id, 'name': p.name, 'mode': p.mode.storage, 'minutes': p.minutes, 'apps': p.packages},
        ],
        'schedules': [
          for (final s in _schedules)
            {
              'id': s.id,
              'mode': s.mode.storage,
              'minutes': s.minutes,
              'at': s.label,
              'weekdays': s.weekdays.toList()..sort(),
              'enabled': s.enabled,
            },
        ],
      };

  /// One row per session. Readable in a spreadsheet, which is the point.
  String exportCsv() {
    final lines = <String>[
      'date,mode,goal,planned_minutes,focused_minutes,paused_minutes,outcome,end_reason,enforcement,blocked_apps,reflection',
    ];
    for (final s in sessions) {
      lines.add([
        isoDayKey(s.day),
        s.mode.storage,
        _csv(s.goalLabel),
        '${s.plannedMinutes}',
        '${(s.focusMs / 60000).round()}',
        '${(s.pausedMs / 60000).round()}',
        s.outcome?.storage ?? 'live',
        s.endReason?.storage ?? '',
        s.enforcement.storage,
        '${s.blockedPackages.length}',
        _csv(s.reflection ?? ''),
      ].join(','));
    }
    return lines.join('\n');
  }

  static String _csv(String raw) {
    final needsQuotes = raw.contains(',') || raw.contains('"') || raw.contains('\n');
    final escaped = raw.replaceAll('"', '""');
    return needsQuotes ? '"$escaped"' : escaped;
  }

  // -------------------------------------------------------------- data rights
  /// Called by "delete all data". Session records go; profiles are kept unless the
  /// caller asks for definitions too, matching the tracker tables.
  Future<Map<String, int>> deleteAllUserData({bool keepDefinitions = true}) async {
    final removed = await dao.deleteAllUserData(keepDefinitions: keepDefinitions);
    await hydrate();
    return removed;
  }

  // ------------------------------------------------------------------ helpers
  void _replace(FocusSession session) {
    final i = _sessions.indexWhere((s) => s.id == session.id);
    if (i >= 0) {
      _sessions[i] = session;
    } else {
      _sessions.insert(0, session);
    }
  }

  String _newId() {
    final factory = _idFactory;
    if (factory != null) return factory();
    _idCounter++;
    return 'focus-${now().microsecondsSinceEpoch}-$_idCounter';
  }

  int _nextNotificationId() {
    var max = 3900;
    for (final s in _schedules) {
      if (s.notificationId > max) max = s.notificationId;
    }
    return max + 1;
  }

  FocusSession _toModel(FocusSessionRow r) => FocusSession(
        id: r.id,
        mode: FocusMode.fromStorage(r.mode) ?? FocusMode.standard,
        plannedMinutes: r.plannedMinutes,
        goalLabel: r.goalLabel,
        commitmentId: r.commitmentId,
        startedAtWallMs: r.startedAtWallMs,
        startedAtRealtimeMs: r.startedAtRealtimeMs,
        segmentStartedAtRealtimeMs: r.segmentStartedAtRealtimeMs,
        pausedAtWallMs: r.pausedAtWallMs,
        focusMs: r.focusMs,
        pausedMs: r.pausedMs,
        state: FocusSessionState.fromStorage(r.state),
        outcome: FocusOutcome.fromStorage(r.outcome),
        enforcement: FocusEnforcement.fromStorage(r.enforcement),
        endReason: FocusEndReason.fromStorage(r.endReason),
        blockedAttempts: r.blockedAttempts,
        overlayShows: r.overlayShows,
        detectionEvents: r.detectionEvents,
        timingVerified: r.timingVerified,
        blockedPackages: _decodeList(r.blockedPackagesJson),
        endedAtWallMs: r.endedAtWallMs,
        reflection: r.reflection,
        day: r.day,
        source: r.source,
      );

  FocusSessionsCompanion _toRow(FocusSession s) => FocusSessionsCompanion.insert(
        id: s.id,
        mode: s.mode.storage,
        plannedMinutes: s.plannedMinutes,
        goalLabel: s.goalLabel,
        commitmentId: Value(s.commitmentId),
        startedAtWallMs: s.startedAtWallMs,
        startedAtRealtimeMs: s.startedAtRealtimeMs,
        segmentStartedAtRealtimeMs: Value(s.segmentStartedAtRealtimeMs),
        pausedAtWallMs: Value(s.pausedAtWallMs),
        focusMs: Value(s.focusMs),
        pausedMs: Value(s.pausedMs),
        state: s.state.storage,
        outcome: Value(s.outcome?.storage),
        enforcement: s.enforcement.storage,
        endReason: Value(s.endReason?.storage),
        blockedAttempts: Value(s.blockedAttempts),
        overlayShows: Value(s.overlayShows),
        detectionEvents: Value(s.detectionEvents),
        timingVerified: Value(s.timingVerified),
        blockedPackagesJson: Value(jsonEncode(s.blockedPackages)),
        endedAtWallMs: Value(s.endedAtWallMs),
        reflection: Value(s.reflection),
        day: s.day,
        source: Value(s.source),
      );

  /// Missing and malformed weekdays are dropped rather than defaulted: a schedule
  /// that silently fires every day because its JSON was corrupt would be worse than
  /// one that fires on no day until the user looks at it.
  static Set<int> _decodeWeekdays(String raw) {
    final out = <int>{};
    for (final value in _decodeList(raw)) {
      final day = int.tryParse(value);
      if (day != null && day >= 1 && day <= 7) out.add(day);
    }
    return out;
  }

  static List<String> _decodeList(String raw) {
    if (raw.isEmpty) return const <String>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return [for (final v in decoded) if (v is String) v];
      }
    } catch (_) {
      // A corrupt blob is not worth a crash: the list is treated as empty, which
      // under-claims rather than over-claims.
    }
    return const <String>[];
  }
}

