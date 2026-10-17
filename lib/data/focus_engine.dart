import '../models/focus_models.dart';
import '../util/day_key.dart';

/// Focus Lock's rules, as pure functions.
///
/// Nothing in this file touches a database, a platform channel, a widget or a
/// clock of its own: every function is `(inputs) -> answer`, which is what makes
/// the hard parts of this feature — recovery after a crash, deciding whether a
/// session may call itself complete, deciding what a set of numbers is allowed to
/// claim — testable without a device.
///
/// The three rules that matter most, all enforced here rather than in the UI:
///
///  1. **Enforcement is proved, not assumed.** [enforcementFor] will not return
///     [FocusEnforcement.verified] without evidence that the foreground-app
///     detector actually reported something, and [outcomeFor] will not return a
///     clean completion for a blocking session whose enforcement was never
///     confirmed. "We asked for permission and started a service" is not evidence
///     that anything was blocked.
///  2. **Time is monotonic first.** [recover] uses the platform's monotonic clock
///     (Android `SystemClock.elapsedRealtime()`) as the source of truth, falls back
///     to the wall clock only when it must, and treats a *backwards* monotonic clock
///     as a device restart rather than silently inventing the missing hours.
///  3. **The pause budget is real.** A mode that enforces something loses that
///     enforcement while paused, so pausing past the mode's budget turns a clean
///     completion into [FocusOutcome.completedDegraded]. Pausing is never blocked
///     and never punished — it is recorded.
///
/// Android's own limits are stated in the code rather than glossed over:
/// `UsageStatsManager` is a *usage reporting* API, not a blocking API. There is no
/// public Android API that prevents another app from starting. Track Pro's App Blocking
/// is therefore a best-effort mechanism: a user-granted overlay window plus user-
/// granted usage access, used to notice a selected app coming to the front and cover
/// it. It can be defeated by any app that does not surface usage events, by a device
/// that refuses to report them, and by the user pressing Home. Those limits are why
/// [FocusEnforcement.armed] exists and why the app never says "blocked" without
/// [FocusEnforcement.verified].
class FocusEngine {
  const FocusEngine._();

  // --------------------------------------------------------------- durations
  /// The durations offered as one-tap options.
  static const List<int> presetMinutes = <int>[15, 25, 45, 60];

  /// Bounds for a custom duration. The lower bound is where a session stops being
  /// a session; the upper bound keeps a live session from outliving the waking day.
  static const int minCustomMinutes = 5;
  static const int maxCustomMinutes = 180;

  /// How long the user may pause before the session stops counting as a clean
  /// completion. `null` means unlimited, which is correct for a pure timer: a
  /// standard session enforces nothing but its own clock, so pausing it costs
  /// nothing but the time itself.
  static Duration? pauseBudgetFor(FocusMode mode) => switch (mode) {
        FocusMode.standard => null,
        FocusMode.blocking => const Duration(minutes: 5),
        FocusMode.deep => const Duration(minutes: 3),
      };

  static int clampMinutes(int minutes) =>
      minutes.clamp(minCustomMinutes, maxCustomMinutes);

  // ------------------------------------------------------------- enforcement
  /// What actually happened to enforcement, derived from what the platform
  /// reported — never from what the user selected.
  ///
  /// The order of the checks is the whole point:
  ///   * no blocking requested → [FocusEnforcement.timerOnly];
  ///   * the backing service is gone, or a permission was revoked mid-session →
  ///     [FocusEnforcement.lost] (the rest of the session was unprotected);
  ///   * a required permission is missing → [FocusEnforcement.unavailable]
  ///     (nothing is being enforced at all);
  ///   * service alive, permissions held, and at least one foreground event has
  ///     been observed → [FocusEnforcement.verified];
  ///   * otherwise → [FocusEnforcement.armed]: set up, unproven.
  ///
  /// `detectionEvents` is the count of foreground-app events the monitor reported
  /// during this session. It is the single piece of evidence that separates "the
  /// mechanism is running" from "the mechanism works".
  static FocusEnforcement enforcementFor({
    required bool blockingRequested,
    required bool serviceAlive,
    required bool permissionLostMidSession,
    required bool overlayGranted,
    required bool usageAccessGranted,
    required int detectionEvents,
  }) {
    if (!blockingRequested) return FocusEnforcement.timerOnly;
    if (permissionLostMidSession || !serviceAlive) return FocusEnforcement.lost;
    if (!overlayGranted || !usageAccessGranted) return FocusEnforcement.unavailable;
    return detectionEvents > 0 ? FocusEnforcement.verified : FocusEnforcement.armed;
  }

  /// Whether the enforcement state that ended the session should downgrade a
  /// would-be completion. Standard sessions enforce nothing beyond their timer, so
  /// they are never downgraded for enforcement.
  static bool becomesDegraded(FocusMode mode, FocusEnforcement enforcement) {
    if (mode == FocusMode.standard) return false;
    return !enforcement.isConfirmed;
  }

  // ------------------------------------------------------------------- time
  /// Reads a live session back into arithmetic, whatever happened to the app.
  ///
  /// [nowRealtimeMs] is the platform's monotonic clock. [nowWallMs] is the wall
  /// clock. [monotonicAvailable] is false when the platform channel is missing
  /// (a test host, or a non-Android build), in which case the wall clock is used
  /// and the session is marked [FocusSession.timingVerified] = false by the caller.
  ///
  /// Nothing here mutates anything, and calling it twice with the same inputs
  /// gives the same answer — the property the repository's idempotent recovery
  /// depends on.
  static FocusRecovery recover({
    required FocusSession session,
    required int nowRealtimeMs,
    required int nowWallMs,
    bool monotonicAvailable = true,
  }) {
    final planned = session.plannedMs;
    final wallDelta = nowWallMs - session.startedAtWallMs;

    if (session.state == FocusSessionState.ended) {
      return FocusRecovery(
        session: session,
        elapsedMs: session.focusMs,
        remainingMs: (planned - session.focusMs).clamp(0, planned),
        expired: session.focusMs >= planned,
        rebooted: false,
        monotonicTrusted: session.timingVerified,
        clockMovedBackwards: false,
        timedOutWhileAway: false,
        staleByMs: 0,
      );
    }

    if (!monotonicAvailable) {
      // Wall clock only. Two failure modes this cannot absorb, both reported
      // rather than smoothed over: a wall clock that moved backwards (elapsed
      // stays at the last checkpoint) and a paused session (which accrues nothing).
      final back = wallDelta < session.wallSpanMs;
      final fromCheckpoint = session.state == FocusSessionState.paused || back;
      final estimate =
          fromCheckpoint ? session.focusMs : session.focusMs + (wallDelta - session.wallSpanMs);
      final elapsed = estimate.clamp(session.focusMs, planned);
      return FocusRecovery(
        session: session,
        elapsedMs: elapsed,
        remainingMs: planned - elapsed,
        expired: elapsed >= planned,
        rebooted: false,
        monotonicTrusted: false,
        clockMovedBackwards: back,
        timedOutWhileAway: elapsed >= planned,
        staleByMs: 0,
      );
    }

    final segmentStart = session.segmentStartedAtRealtimeMs;
    final delta = nowRealtimeMs - session.startedAtRealtimeMs;

    // A monotonic clock that runs backwards is a device restart: `elapsedRealtime`
    // counts from boot. The time between the last checkpoint and the restart is
    // unknowable, so it is not counted.
    if (delta < 0 || (segmentStart != null && nowRealtimeMs < segmentStart)) {
      return FocusRecovery(
        session: session,
        elapsedMs: session.focusMs,
        remainingMs: (planned - session.focusMs).clamp(0, planned),
        expired: false,
        rebooted: true,
        monotonicTrusted: true,
        clockMovedBackwards: false,
        timedOutWhileAway: false,
        staleByMs: 0,
      );
    }

    var elapsed = session.focusMs;
    if (segmentStart != null) {
      elapsed += nowRealtimeMs - segmentStart;
    } else if (session.state == FocusSessionState.running) {
      // A running session with no segment start should not exist (start and resume
      // both set one), but a defensive branch that counts nothing would freeze the
      // countdown for an hour. The wall clock is the wrong clock, but it is a clock.
      final wallServed = wallDelta - session.wallSpanMs;
      if (wallServed > 0) elapsed += wallServed;
    }
    if (elapsed > planned) elapsed = planned;

    // Independent cross-check: the wall clock should have advanced by roughly the
    // focus time plus the paused time. A large disagreement is worth recording
    // (it explains a countdown that looks wrong in the history), but the monotonic
    // clock is what decides.
    final expectedWall = session.wallSpanMs + (segmentStart != null ? nowRealtimeMs - segmentStart : 0);
    final drift = wallDelta - expectedWall;
    final staleBy = segmentStart != null ? nowRealtimeMs - segmentStart : 0;

    return FocusRecovery(
      session: session,
      elapsedMs: elapsed,
      remainingMs: planned - elapsed,
      expired: elapsed >= planned,
      rebooted: false,
      monotonicTrusted: true,
      clockMovedBackwards: drift < -2000,
      timedOutWhileAway: elapsed >= planned,
      staleByMs: staleBy,
    );
  }

  // ---------------------------------------------------------------- outcomes
  /// The only place a session's verdict is decided.
  ///
  /// [focusMs] is the final banked focus time, [plannedMs] the planned duration.
  /// The rules, in order:
  ///
  ///  1. A session that ended because Track Pro could not continue — service stopped,
  ///     device restarted, app updated, permission revoked — is
  ///     [FocusOutcome.interrupted]. Track Pro does not know what happened while it was
  ///     off, so it does not claim the session.
  ///  2. Ending early by hand is [FocusOutcome.cancelled], unless the time was
  ///     already served, in which case it is judged like a timer completion.
  ///  3. A timer completion is clean only when the mode's rules were in force:
  ///     standard sessions always are; blocking and deep sessions need
  ///     [FocusEnforcement.verified]. Anything less is
  ///     [FocusOutcome.completedDegraded], and the summary says which rule lapsed.
  static FocusOutcome outcomeFor({
    required FocusMode mode,
    required int focusMs,
    required int plannedMs,
    required FocusEnforcement enforcement,
    required FocusEndReason reason,
    required bool timingVerified,
  }) {
    switch (reason) {
      case FocusEndReason.serviceLost:
      case FocusEndReason.deviceRestarted:
      case FocusEndReason.permissionRevoked:
      case FocusEndReason.appUpdated:
        return FocusOutcome.interrupted;
      case FocusEndReason.cancelled:
      case FocusEndReason.userEnded:
        if (focusMs < plannedMs) return FocusOutcome.cancelled;
        break;
      case FocusEndReason.timer:
        break;
    }

    if (becomesDegraded(mode, enforcement)) return FocusOutcome.completedDegraded;
    // An unverified timing source does not by itself degrade a standard session —
    // there is nothing else to verify — but it does for a session that claims to
    // have enforced something, because "45 minutes" is one of the rules being
    // claimed.
    if (!timingVerified && mode != FocusMode.standard) return FocusOutcome.completedDegraded;
    return FocusOutcome.completed;
  }

  /// Why a session is not a clean completion, in one sentence for the summary.
  /// Empty for a clean completion: it needs no explanation.
  static String degradedReason({
    required FocusMode mode,
    required FocusOutcome outcome,
    required FocusEnforcement enforcement,
    required FocusEndReason reason,
    required int pausedMs,
    bool timingVerified = true,
  }) {
    if (outcome == FocusOutcome.completed) return '';
    switch (outcome) {
      case FocusOutcome.interrupted:
        return switch (reason) {
          FocusEndReason.deviceRestarted =>
            'The device restarted during this session, so Track Pro could not keep it running. '
                'It is recorded as interrupted rather than completed, because what happened while '
                'the phone was off cannot be verified.',
          FocusEndReason.appUpdated =>
            'Track Pro was updated while this session was running, which stops a focus session. '
                'It is recorded as interrupted.',
          FocusEndReason.permissionRevoked =>
            'A permission this session relied on was revoked, so the rules you selected were not '
                'in force. It is recorded as interrupted.',
          _ =>
            'The service that enforces this session stopped before the timer ran out, so the rest '
                'of the session was not enforced. It is recorded as interrupted.',
        };
      case FocusOutcome.cancelled:
        return 'Ended early by hand. Nothing was lost, and nothing is claimed: this is a cancelled '
            'session, not a completed one.';
      case FocusOutcome.completedDegraded:
        if (!timingVerified) {
          return 'The time was served, but the length of it could not be checked against a '
              'monotonic clock on this device, so it is recorded as a degraded completion.';
        }
        final budget = pauseBudgetFor(mode);
        if (budget != null && pausedMs > budget.inMilliseconds) {
          return 'The time was served, but ${_minutes(pausedMs)} of it were paused — more than the '
              '${budget.inMinutes}-minute budget this mode allows. Recorded as a degraded completion.';
        }
        return switch (enforcement) {
          FocusEnforcement.unavailable =>
            'App blocking needed a permission that is not granted, so it was not enforcing anything '
                'during this session. The time counts; the block does not.',
          FocusEnforcement.armed =>
            'App blocking was set up and running, but this device never confirmed that it could see '
                'which app was in the foreground, so Track Pro cannot say that anything was blocked. '
                'Recorded as a degraded session rather than a clean one.',
          FocusEnforcement.lost =>
            'App blocking stopped part-way through this session, so part of it was unprotected.',
          _ =>
            'A rule you selected was not in force for the whole session, so this is recorded as a '
                'degraded completion rather than a clean one.',
        };
      case FocusOutcome.completed:
        return '';
    }
  }

  /// The end-of-session summary, assembled from the stored row so it can never
  /// disagree with the record.
  static FocusSummary summaryFor(FocusSession session) {
    final minutes = (session.focusMs / 60000).round();
    final outcome = session.outcome ?? FocusOutcome.cancelled;
    final headline = switch (outcome) {
      FocusOutcome.completed => '$minutes-minute focus session',
      FocusOutcome.completedDegraded => '$minutes minutes, with a caveat',
      FocusOutcome.interrupted => 'Session interrupted',
      FocusOutcome.cancelled => 'Session ended early',
    };
    final detail = switch (outcome) {
      FocusOutcome.completed =>
        'Timer ran out. ${session.mode.label.toLowerCase()} rules were in force for the whole '
            'session.',
      FocusOutcome.completedDegraded =>
        'You focused for $minutes minutes. One of the rules you selected was not in force for all '
            'of it, so it is not counted as a clean run.',
      FocusOutcome.interrupted =>
        'Recorded as interrupted. The time before the interruption — ${_minutes(session.focusMs)} — '
            'is still in your history.',
      FocusOutcome.cancelled =>
        'You stopped it after ${_minutes(session.focusMs)}. Recorded as cancelled, which costs you '
            'nothing.',
    };
    return FocusSummary(
      session: session,
      headline: headline,
      detail: detail,
      cleanlinessNote: degradedReason(
        mode: session.mode,
        outcome: outcome,
        enforcement: session.enforcement,
        reason: session.endReason ?? FocusEndReason.timer,
        pausedMs: session.pausedMs,
        timingVerified: session.timingVerified,
      ),
      blockedApps: session.blockedPackages,
      minutesFocused: minutes,
    );
  }

  // ------------------------------------------------------------------ pauses
  /// Whether pausing is allowed right now, and what it costs. Both modes that
  /// enforce something can be paused at any time — a session that cannot be paused
  /// is a trap — but a pause means the selected apps are available again, and that
  /// is stated before and during the pause rather than discovered afterwards.
  static bool pauseSuspendsEnforcement(FocusMode mode) => mode != FocusMode.standard;

  /// Pauses are unlimited everywhere; only the *completion verdict* depends on the
  /// budget, and [pausedBeyondBudget] is what the UI warns about before it happens.
  static bool pausedBeyondBudget(FocusMode mode, int pausedMs) {
    final budget = pauseBudgetFor(mode);
    return budget != null && pausedMs > budget.inMilliseconds;
  }

  // ------------------------------------------------------------------- stats
  /// Aggregates for the history screen. Every nullable field is null because the
  /// sample is too small — the same discipline `MomentumSnapshot.rate` uses.
  static FocusStats statsFor(List<FocusSession> sessions, {required int todayKey}) {
    final ended = [for (final s in sessions) if (s.state == FocusSessionState.ended) s]
      ..sort((a, b) => b.startedAtWallMs.compareTo(a.startedAtWallMs));
    if (ended.isEmpty) return FocusStats.empty;

    var completed = 0, degraded = 0, interrupted = 0, cancelled = 0;
    var minutes7 = 0, minutesTotal = 0;
    // "Last 7 days" includes today, so it starts at midnight six days ago.
    final weekFloor = dateOfDayKey(todayKey).subtract(const Duration(days: 6)).millisecondsSinceEpoch;

    final starts = <int>[];
    for (final s in ended) {
      switch (s.outcome ?? FocusOutcome.cancelled) {
        case FocusOutcome.completed:
          completed++;
          break;
        case FocusOutcome.completedDegraded:
          degraded++;
          break;
        case FocusOutcome.interrupted:
          interrupted++;
          break;
        case FocusOutcome.cancelled:
          cancelled++;
          break;
      }
      final isServed = s.outcome?.servedTime ?? false;
      if (isServed) {
        final minutes = (s.focusMs / 60000).round();
        minutesTotal += minutes;
        if (s.startedAtWallMs >= weekFloor) minutes7 += minutes;
        final start = DateTime.fromMillisecondsSinceEpoch(s.startedAtWallMs);
        starts.add(start.hour * 60 + start.minute);
      }
    }

    // Most-recent-first streak of clean completions.
    var streak = 0;
    for (final s in ended) {
      if (s.outcome == FocusOutcome.completed) {
        streak++;
      } else {
        break;
      }
    }

    // A "you usually start around …" claim needs a habit behind it. Below the
    // threshold the field stays null and the screen prints the count instead.
    final typical = starts.length < FocusStats.minSessionsForPattern ? null : _median(starts);

    return FocusStats(
      endedSessions: ended.length,
      completed: completed,
      degraded: degraded,
      interrupted: interrupted,
      cancelled: cancelled,
      minutesLast7Days: minutes7,
      minutesTotal: minutesTotal,
      cleanStreak: streak,
      typicalStartMinute: typical,
    );
  }

  static int _median(List<int> values) {
    final sorted = List<int>.from(values)..sort();
    final mid = sorted.length ~/ 2;
    return sorted.length.isOdd ? sorted[mid] : ((sorted[mid - 1] + sorted[mid]) / 2).round();
  }

  /// `08:30` from a minute-of-day. Used for the typical-start figure.
  static String clockLabel(int minuteOfDay) {
    final h = (minuteOfDay ~/ 60) % 24;
    final m = minuteOfDay % 60;
    final suffix = h < 12 ? 'am' : 'pm';
    final twelve = h % 12 == 0 ? 12 : h % 12;
    return m == 0 ? '$twelve$suffix' : '$twelve:${m < 10 ? '0$m' : m}$suffix';
  }

  // -------------------------------------------------------- protected packages
  /// Packages that must never be blocked, whatever a profile says.
  ///
  /// This list exists in Dart as well as in the Kotlin side on purpose: the Kotlin
  /// side resolves the device's *actual* dialer, launcher and system UI, and this
  /// list is the second line of defence so a hand-edited profile, a stale export,
  /// or a future bug cannot leave a user unable to place a call, answer the phone,
  /// reach Settings, or leave the blocked app.
  ///
  /// The rules behind it:
  ///  * **Emergency and telephony.** The dialer, the phone app, telecom and the
  ///    emergency handler are never covered. A focus session must never be the
  ///    reason someone cannot call for help.
  ///  * **The way out.** System UI, the launcher and Settings are never covered, so
  ///    Home, Recents and the notification shade keep working. A block with no exit
  ///    is a trap, and a trap is not a product feature.
  ///  * **The keyboard.** Input methods are excluded: covering the IME breaks
  ///    text entry in every app, including the system's own dialogs.
  ///  * **The updater and the store.** Package installer and Play Store are
  ///    excluded so a session can never leave the device in a half-updated state.
  ///  * **Track Pro itself** and, optionally, the user's own additions.
  static const Set<String> alwaysProtected = <String>{
    // telephony and emergency
    'com.android.dialer',
    'com.android.phone',
    'com.android.server.telecom',
    'com.android.emergency',
    'com.android.incallui',
    'com.google.android.dialer',
    // the way out of any app
    'com.android.systemui',
    'com.android.settings',
    'android',
    // the keyboard and permission prompts
    'com.google.android.inputmethod.latin',
    'com.android.inputmethod.latin',
    'com.android.permissioncontroller',
    'com.google.android.permissioncontroller',
    // updates and installs
    'com.android.packageinstaller',
    'com.google.android.packageinstaller',
    'com.android.vending',
    'com.android.providers.downloads',
    // Track Pro itself
    'com.track.app',
  };

  /// Packages that are excluded by *intent* rather than by name, resolved on the
  /// platform side and passed in: the default launcher, the default dialer, the
  /// default SMS app and the system's assist app. A device can have any package
  /// name for all four.
  static bool isProtected(String packageName, {Set<String> deviceProtected = const <String>{}}) =>
      alwaysProtected.contains(packageName) || deviceProtected.contains(packageName);

  /// Cleans a requested block list. Returns what will be used and what was
  /// refused, so the setup screen can say "3 apps skipped because they are needed
  /// to make a call or leave an app" instead of silently dropping them.
  static ({List<String> allowed, List<String> refused}) sanitizeBlockList(
    Iterable<String> requested, {
    Set<String> deviceProtected = const <String>{},
  }) {
    final allowed = <String>[];
    final refused = <String>[];
    for (final raw in requested) {
      final id = raw.trim();
      if (id.isEmpty) continue;
      if (isProtected(id, deviceProtected: deviceProtected)) {
        refused.add(id);
      } else if (!allowed.contains(id)) {
        allowed.add(id);
      }
    }
    return (allowed: allowed, refused: refused);
  }

  /// The line shown before a session starts, so cancellation behaviour is known in
  /// advance rather than discovered mid-session. Kept as a pure function of the
  /// mode so the setup sheet and the session screen cannot disagree.
  static String cancellationCopy(FocusMode mode) => switch (mode) {
        FocusMode.standard =>
          'Ending is a tap away at any time. Nothing is blocked in this mode, so ending early '
              'simply records a shortened session.',
        FocusMode.blocking =>
          'Ending is a tap away at any time. While the session runs, the apps you selected are '
              'covered when you open them; ending the session releases them immediately.',
        FocusMode.deep =>
          'Ending takes a deliberate press-and-hold, because "deep" is a rule you chose — not a '
              'trap. If a pause pushes past the ',
              '${pauseBudgetFor(FocusMode.deep)!.inMinutes}-minute budget the session is still recorded, but '
              'not as a clean completion.',
      };
}

/// `12 min` / `1 h 05` — durations in the units people use.
String focusDurationLabel(int milliseconds) {
  final minutes = (milliseconds / 60000).round();
  if (minutes < 60) return '$minutes min';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '$h h' : '$h h ${m < 10 ? '0$m' : m}';
}

/// `18:42` — the countdown, floored so it never shows a second that has not
/// elapsed, and capped at a day so a corrupt row cannot print nonsense.
String focusCountdownLabel(int milliseconds) {
  final total = (milliseconds / 1000).floor().clamp(0, 24 * 3600);
  final m = total ~/ 60;
  final s = total % 60;
  return '$m:${s < 10 ? '0$s' : s}';
}

/// Minutes, rounded, for prose inside this file.
String _minutes(int milliseconds) => '${(milliseconds / 60000).round()} min';

/// The words the app uses for the focus modes.
///
/// Kept beside the rules so a mode's copy and its behaviour cannot drift apart:
/// the limitation sentence on the setup sheet and the enforcement value the engine
/// records come from the same file.
extension FocusModeText on FocusMode {
  String get label => switch (this) {
        FocusMode.standard => 'Standard focus',
        FocusMode.blocking => 'App blocking',
        FocusMode.deep => 'Deep focus',
      };

  String get shortLabel => switch (this) {
        FocusMode.standard => 'Standard',
        FocusMode.blocking => 'Blocking',
        FocusMode.deep => 'Deep',
      };

  String get emoji => switch (this) {
        FocusMode.standard => '🎯',
        FocusMode.blocking => '🛡️',
        FocusMode.deep => '🌒',
      };

  /// What the mode does, said plainly.
  String get blurb => switch (this) {
        FocusMode.standard =>
          'A timer and a quiet screen. Track Pro holds its own reminders while a session runs. '
              'Nothing outside the app is touched.',
        FocusMode.blocking =>
          'The apps you choose are covered while the session runs, using the overlay access you '
              'grant. Android has no public API that can prevent another app from opening, so this '
              'is best-effort — read the limitations before you rely on it.',
        FocusMode.deep =>
          'The stricter rules you configure: a smaller pause budget and a press-and-hold to end. '
              'It is not a kiosk, and it never takes the device over.',
      };

  /// The honest limitation, shown on the setup sheet *before* a mode is chosen. A
  /// user who finds out afterwards that "blocking" was advisory is a user who will
  /// never trust the feature again.
  String get limitation => switch (this) {
        FocusMode.standard => 'No blocking. Notifications from other apps still arrive.',
        FocusMode.blocking =>
          'Best-effort: needs two permissions, cannot stop an app launching, and pressing Home '
              'leaves the blocked app.',
        FocusMode.deep =>
          'Best-effort, plus a pause budget. It cannot cover the notification shade, system '
              'dialogs, or the Home and Recents buttons.',
      };
}

/// The words for how much of a session was actually enforced. Used by the session
/// screen, the summary and the history so one label means one thing everywhere.
extension FocusEnforcementText on FocusEnforcement {
  String get label => switch (this) {
        FocusEnforcement.timerOnly => 'Timer only',
        FocusEnforcement.unavailable => 'Not blocking',
        FocusEnforcement.armed => 'Blocking set up, unconfirmed',
        FocusEnforcement.verified => 'Blocking verified',
        FocusEnforcement.lost => 'Blocking lost',
      };

  /// The sentence printed under the countdown. Never claims more than the value.
  String get detail => switch (this) {
        FocusEnforcement.timerOnly => 'This session enforces its timer and nothing else.',
        FocusEnforcement.unavailable =>
          'Not blocking: a permission this mode needs is not granted, so nothing is being '
              'restricted.',
        FocusEnforcement.armed =>
          'Blocking is running, but this device has not yet reported which app you opened, so '
              'Track Pro cannot confirm it is working.',
        FocusEnforcement.verified =>
          'Blocking is working: this device is reporting the app you open, and selected apps are '
              'covered.',
        FocusEnforcement.lost =>
          'Blocking stopped during this session. The rest of the time was not enforced.',
      };

  /// Colour token name for the UI, so the state is legible at a glance without any
  /// screen inventing its own mapping.
  String get tone => switch (this) {
        FocusEnforcement.verified => 'full',
        FocusEnforcement.armed => 'minimum',
        FocusEnforcement.unavailable || FocusEnforcement.lost => 'danger',
        FocusEnforcement.timerOnly => 'rest',
      };
}

/// The words for how a session ended.
extension FocusOutcomeText on FocusOutcome {
  String get label => switch (this) {
        FocusOutcome.completed => 'Completed',
        FocusOutcome.completedDegraded => 'Completed, degraded',
        FocusOutcome.interrupted => 'Interrupted',
        FocusOutcome.cancelled => 'Cancelled',
      };

  String get emoji => switch (this) {
        FocusOutcome.completed => '✅',
        FocusOutcome.completedDegraded => '⚠️',
        FocusOutcome.interrupted => '⛔',
        FocusOutcome.cancelled => '⏹️',
      };

  /// Colour token name from `Editorial`, resolved in the UI layer.
  String get tone => switch (this) {
        FocusOutcome.completed => 'full',
        FocusOutcome.completedDegraded => 'minimum',
        FocusOutcome.interrupted => 'danger',
        FocusOutcome.cancelled => 'rest',
      };
}

/// The words for why a session stopped.
extension FocusEndReasonText on FocusEndReason {
  String get label => switch (this) {
        FocusEndReason.timer => 'timer reached zero',
        FocusEndReason.userEnded => 'ended after the time was up',
        FocusEndReason.cancelled => 'ended early',
        FocusEndReason.serviceLost => 'the enforcing service stopped',
        FocusEndReason.deviceRestarted => 'the device restarted',
        FocusEndReason.permissionRevoked => 'a permission was revoked',
        FocusEndReason.appUpdated => 'Track Pro was updated',
      };
}
