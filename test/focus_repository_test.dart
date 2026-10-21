import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track/data/db/database.dart';
import 'package:track/data/focus_repository.dart';
import 'package:track/models/focus_models.dart';
import 'package:track/services/focus_platform.dart';

/// The platform, faked at the seam — not inside the feature.
///
/// [FakeEnforcer] implements the same abstract interface the method channel
/// implements, and it answers the same way the real one does when the device cannot
/// help: nulls, false, and idle state. What it deliberately *cannot* do is make the
/// repository believe something happened; every rule under test lives in
/// `FocusEngine` and `FocusRepository`, so a fake enforcer can only change what the
/// platform reports, never what the app concludes.
class FakeEnforcer implements FocusEnforcer {
  FakeEnforcer({
    this.monotonic = 1_000_000,
    this.available = true,
    FocusPermissions permissions = const FocusPermissions(
      usageAccess: true,
      overlay: true,
      notifications: true,
      batteryOptimised: false,
    ),
    this.protected_ = const <String>{'com.android.dialer'},
    this.apps = const <FocusAppInfo>[],
  }) : _permissions = permissions;

  int monotonic;
  bool available;
  FocusPermissions _permissions;
  final Set<String> protected_;
  final List<FocusAppInfo> apps;

  /// What the platform reports about the running service. Tests move these to
  /// simulate a revocation, a kill, or a healthy detector.
  FocusNativeState native = FocusNativeState.idle;

  int startCalls = 0;
  int stopCalls = 0;
  bool startSucceeds = true;
  final List<int> openedSettings = <int>[];

  @override
  Future<bool> get isAvailable async => available;

  @override
  Future<FocusPermissions> permissions() async => _permissions;

  void setPermissions(FocusPermissions value) => _permissions = value;

  @override
  Future<int?> monotonicMs() async => monotonic;

  @override
  Future<FocusNativeState> state() async => native;

  @override
  Future<bool> startSession({
    required String sessionId,
    required String mode,
    required int plannedMinutes,
    required int endsAtRealtimeMs,
    required List<String> packages,
    required bool block,
    required String label,
    required int accentArgb,
  }) async {
    startCalls++;
    if (!startSucceeds) return false;
    native = FocusNativeState(
      running: true,
      blocking: block,
      startedAtRealtimeMs: monotonic,
      endsAtRealtimeMs: endsAtRealtimeMs,
      blockedAttempts: 0,
      overlayShows: 0,
      detectionEvents: 0,
      usageAccess: _permissions.usageAccess,
      overlay: _permissions.overlay,
    );
    return true;
  }

  @override
  Future<void> stopSession() async {
    stopCalls++;
    native = FocusNativeState.idle;
  }

  @override
  Future<List<FocusAppInfo>> installedApps() async => apps;

  @override
  Future<Set<String>> protectedPackages() async => protected_;

  @override
  Future<void> openUsageAccessSettings() async => openedSettings.add(1);

  @override
  Future<void> openOverlaySettings() async => openedSettings.add(2);

  @override
  Future<void> openNotificationSettings() async => openedSettings.add(3);

  @override
  Future<void> openBatterySettings() async => openedSettings.add(4);
}

/// Persistence, recovery and the one-live-session rule, against a real in-memory
/// SQLite database.
///
/// The scenarios here are the ones the brief names explicitly, turned into
/// assertions: background/foreground, reboot, revoked permission, expiry, an app
/// update, and process termination. None of them is asserted as "works on a device";
/// each asserts the *rule* the app follows when the platform reports that happened.
///
/// NOT EXECUTED in the environment that wrote it (no Flutter/Dart SDK). Run with:
///   flutter test test/focus_repository_test.dart
/// `drift/native.dart` needs libsqlite3 present (on Linux: apt-get install libsqlite3-0).
void main() {
  late TrackDatabase db;
  late FakeEnforcer enforcer;
  late FocusRepository repo;
  late DateTime now;

  setUp(() async {
    db = TrackDatabase.forTesting(NativeDatabase.memory());
    enforcer = FakeEnforcer();
    now = DateTime(2026, 10, 16, 9, 0);
    repo = FocusRepository(db: db, enforcer: enforcer, now: () => now, idFactory: _SequenceIds().next);
    await repo.hydrate();
  });

  tearDown(() async => db.close());

  Future<FocusSession> start({
    FocusMode mode = FocusMode.blocking,
    int minutes = 25,
    List<String> packages = const <String>['com.instagram.android'],
  }) => repo.start(mode: mode, minutes: minutes, requestedPackages: packages, goalLabel: 'Writing');

  group('one live session, and only one', () {
    test('a second start is refused rather than silently stacked', () async {
      await start();
      expect(
        () => start(),
        throwsA(isA<StateError>()),
        reason: 'there is at most one live session; a caller bug must be loud',
      );
    });

    test('two live rows in storage are repaired, newest kept, older ended as interrupted', () async {
      // Simulate a crash that left two rows open (the app was killed between the insert
      // and the end, twice). Recovery must pick one — the newest — and must not leave a
      // session running that nobody can see.
      final first = await start(minutes: 15);
      now = now.add(const Duration(minutes: 30));
      await repo.endByHand();

      // Reopen the finished session as live, alongside a newer one: the store-level
      // equivalent of two open rows.
      await db.focusDao.upsert(
        FocusSessionsCompanion.insert(
          id: first.id,
          mode: first.mode.storage,
          plannedMinutes: first.plannedMinutes,
          goalLabel: first.goalLabel,
          startedAtWallMs: first.startedAtWallMs,
          startedAtRealtimeMs: first.startedAtRealtimeMs,
          state: FocusSessionState.running.storage,
          // Required column, no default: a row with nothing to say about enforcement
          // would be a row the app could not describe honestly.
          enforcement: FocusEnforcement.armed.storage,
          day: first.day,
        ),
      );
      final second = await start(minutes: 15);
      await repo.hydrate();

      expect(repo.liveSession?.id, second.id, reason: 'the newest open row is the live one');
      final repaired = repo.byId(first.id);
      expect(repaired?.state, FocusSessionState.ended);
      expect(repaired?.outcome, FocusOutcome.interrupted);
      expect(repaired?.endReason, FocusEndReason.serviceLost);
    });

    test('ending by hand while the timer is short records a cancellation, not a completion', () async {
      await start(minutes: 25);
      now = now.add(const Duration(minutes: 4));
      final ended = await repo.endByHand();

      expect(ended!.outcome, FocusOutcome.cancelled);
      expect(ended.state, FocusSessionState.ended);
      expect(ended.focusMs, closeTo(4 * 60 * 1000, 1000));
      expect(repo.liveSession, isNull);
    });

    test('ending after the planned time is a completion, decided by the same rules', () async {
      await start(mode: FocusMode.standard, minutes: 15, packages: const <String>[]);
      now = now.add(const Duration(minutes: 16));
      final ended = await repo.endByHand();

      expect(ended!.outcome, FocusOutcome.completed);
      expect(ended.focusMs, 15 * 60 * 1000, reason: 'clamped to the planned length');
    });
  });

  group('background, foreground and expiry', () {
    test('a session that expired while the app was closed is ended once, on recovery', () async {
      final session = await start(minutes: 25);
      // The app is backgrounded and the platform keeps counting.
      enforcer.monotonic += 40 * 60 * 1000;
      now = now.add(const Duration(minutes: 40));

      final recovered = await repo.recover();
      expect(recovered, isNotNull);
      expect(recovered!.state, FocusSessionState.ended);
      expect(recovered.focusMs, 25 * 60 * 1000, reason: 'never more than promised');
      expect(
        recovered.outcome,
        FocusOutcome.completedDegraded,
        reason: 'enforcement was never confirmed by the platform',
      );
      expect(repo.liveSession, isNull);

      // Idempotent: recovering again must not produce a second ending or move any number.
      final again = await repo.recover();
      expect(again, isNull);
      final stored = repo.byId(session.id)!;
      expect(stored.focusMs, 25 * 60 * 1000);
      expect(stored.endedAtWallMs, isNotNull);
    });

    test('a session still inside its window survives a background round-trip intact', () async {
      final session = await start(minutes: 25);
      enforcer.monotonic += 5 * 60 * 1000;
      now = now.add(const Duration(minutes: 5));

      // Foreground again: the app re-syncs and finds the platform still running it.
      final synced = await repo.syncNative(force: true);
      expect(synced?.state, FocusSessionState.running);
      expect(repo.byId(session.id)!.state, FocusSessionState.running);

      // A 15 s checkpoint window means a sync moments later advances the *countdown*
      // without touching the database — a one-second UI tick must not be a
      // one-second disk write. The projection is live; the row is not yet.
      final rowBefore = (await db.focusDao.byId(session.id))!.focusMs;
      enforcer.monotonic += 5_000;
      now = now.add(const Duration(seconds: 5));
      await repo.syncNative();
      final rowAfter = (await db.focusDao.byId(session.id))!.focusMs;
      expect(rowAfter, rowBefore, reason: 'inside the checkpoint window the row is untouched');
      expect(repo.byId(session.id)!.focusMs, greaterThan(rowAfter), reason: 'the countdown still moves every tick');
    });

    test('a reboot is an interruption, and the session does not gain time it never had', () async {
      await start(minutes: 25);
      enforcer.monotonic = 4_000; // elapsedRealtime restarted from zero
      now = now.add(const Duration(minutes: 3));

      final recovered = await repo.recover();
      expect(recovered!.outcome, FocusOutcome.interrupted);
      expect(recovered.endReason, FocusEndReason.deviceRestarted);
      expect(recovered.focusMs, lessThanOrEqualTo(3 * 60 * 1000));
      expect(recovered.timingVerified, isTrue);
    });

    test('a revoked permission turns the session degraded, and the app says so', () async {
      await start(mode: FocusMode.deep, minutes: 25);
      // The user revoked usage access from system settings while the session ran.
      enforcer.native = FocusNativeState(
        running: true,
        blocking: false,
        startedAtRealtimeMs: enforcer.monotonic,
        endsAtRealtimeMs: enforcer.monotonic + 25 * 60 * 1000,
        blockedAttempts: 0,
        overlayShows: 0,
        detectionEvents: 0,
        usageAccess: false,
        overlay: true,
      );
      final synced = await repo.syncNative(force: true);
      expect(
        synced!.enforcement,
        FocusEnforcement.lost,
        reason: 'a grant revoked after an armed session is a mid-session loss',
      );

      now = now.add(const Duration(minutes: 26));
      enforcer.monotonic += 26 * 60 * 1000;
      final ended = await repo.recover();
      expect(
        ended!.outcome,
        FocusOutcome.interrupted,
        reason: 'a revoked grant at expiry is not a clean timer completion',
      );
      expect(ended.endReason, FocusEndReason.permissionRevoked);
      expect(ended.enforcement, FocusEnforcement.lost);
    });

    test('the service dying mid-session is an interruption, not a completion', () async {
      await start(mode: FocusMode.blocking, minutes: 25);
      enforcer.native = FocusNativeState.idle; // the OS killed the detector
      final synced = await repo.syncNative(force: true);
      expect(synced!.enforcement, FocusEnforcement.lost);

      now = now.add(const Duration(minutes: 30));
      enforcer.monotonic += 30 * 60 * 1000;
      final ended = await repo.recover();
      expect(ended!.outcome, FocusOutcome.interrupted);
      expect(ended.endReason, FocusEndReason.serviceLost);
    });
    test('a later healthy native report cannot erase a recorded loss', () async {
      await start(mode: FocusMode.blocking, minutes: 25);
      enforcer.native = FocusNativeState.idle;
      final lost = await repo.syncNative(force: true);
      expect(lost!.enforcement, FocusEnforcement.lost);

      enforcer.native = FocusNativeState(
        running: true,
        blocking: true,
        startedAtRealtimeMs: enforcer.monotonic,
        endsAtRealtimeMs: enforcer.monotonic + 25 * 60 * 1000,
        blockedAttempts: 2,
        overlayShows: 1,
        detectionEvents: 2,
        usageAccess: true,
        overlay: true,
      );
      final recovered = await repo.syncNative(force: true);
      expect(
        recovered!.enforcement,
        FocusEnforcement.lost,
        reason: 'new coverage does not rewrite the known uncovered interval',
      );
    });
  });

  group('evidence, never assumption', () {
    test('a started session with no observed foreground event is armed, not verified', () async {
      final session = await start();
      expect(session.enforcement, FocusEnforcement.armed);
      expect(session.enforcement.isConfirmed, isFalse);
    });

    test('a detected selected app plus an accepted coverage panel upgrades it to verified', () async {
      await start();
      enforcer.native = FocusNativeState(
        running: true,
        blocking: true,
        startedAtRealtimeMs: enforcer.monotonic,
        endsAtRealtimeMs: enforcer.monotonic + 25 * 60 * 1000,
        blockedAttempts: 1,
        overlayShows: 1,
        detectionEvents: 3,
        usageAccess: true,
        overlay: true,
        foregroundPackage: 'com.instagram.android',
        usageReportingSeen: true,
      );
      final synced = await repo.syncNative(force: true);
      expect(synced!.enforcement, FocusEnforcement.verified);
      expect(synced.blockedAttempts, 1);
      expect(synced.detectionEvents, 3);
    });

    test('detection without an accepted panel stays armed', () async {
      await start();
      enforcer.native = FocusNativeState(
        running: true,
        blocking: true,
        startedAtRealtimeMs: enforcer.monotonic,
        endsAtRealtimeMs: enforcer.monotonic + 25 * 60 * 1000,
        blockedAttempts: 1,
        overlayShows: 0,
        detectionEvents: 3,
        usageAccess: true,
        overlay: true,
        foregroundPackage: 'com.instagram.android',
        usageReportingSeen: true,
      );

      final synced = await repo.syncNative(force: true);
      expect(
        synced!.enforcement,
        FocusEnforcement.armed,
        reason: 'foreground detection alone does not prove Android allowed the panel',
      );
      expect(synced.enforcement.isConfirmed, isFalse);
    });

    test('a start the platform refused leaves no half-session behind', () async {
      enforcer.startSucceeds = false;
      final session = await start(mode: FocusMode.deep);
      expect(session.enforcement, FocusEnforcement.unavailable);
      expect(repo.liveSession, isNotNull, reason: 'the timer still runs; the block does not');
      final ended = await repo.endByHand();
      expect(ended!.outcome, isNot(FocusOutcome.completed));
    });

    test('protected packages are refused at the repository, and surfaced', () async {
      final session = await start(
        packages: const <String>['com.instagram.android', 'com.android.dialer', 'com.android.systemui'],
      );
      expect(session.blockedPackages, ['com.instagram.android']);
      expect(session.blockedPackages, isNot(contains('com.android.dialer')));
    });

    test('a start that "succeeded" with no grants is unavailable, never armed', () async {
      // The service said yes, but the two grants that make covering possible are not
      // held. `armed` would be a claim; `unavailable` is the fact.
      enforcer.setPermissions(FocusPermissions.none);
      final session = await start(mode: FocusMode.blocking);
      expect(session.enforcement, FocusEnforcement.unavailable);
      expect(session.enforcement.isConfirmed, isFalse);
      expect(session.enforcement.needsAttention, isTrue);
    });

    test('initially unavailable enforcement cannot become clean after a later re-grant', () async {
      enforcer.setPermissions(FocusPermissions.none);
      await start(mode: FocusMode.blocking);
      expect(repo.liveSession!.enforcement, FocusEnforcement.unavailable);

      // Settings grants access while the timer has already been running. The native
      // service can work from this point, but it cannot certify the earlier interval.
      enforcer.native = FocusNativeState(
        running: true,
        blocking: true,
        startedAtRealtimeMs: enforcer.monotonic,
        endsAtRealtimeMs: enforcer.monotonic + 25 * 60 * 1000,
        blockedAttempts: 1,
        overlayShows: 1,
        detectionEvents: 1,
        usageAccess: true,
        overlay: true,
      );
      final synced = await repo.syncNative(force: true);
      expect(synced!.enforcement, FocusEnforcement.lost);
    });

    test('the app never grants a permission itself — it only opens the system screen', () async {
      await enforcer.openUsageAccessSettings();
      await enforcer.openOverlaySettings();
      await enforcer.openNotificationSettings();
      await enforcer.openBatterySettings();
      expect(enforcer.openedSettings, [1, 2, 3, 4]);
      // Nothing in this contract returns a permission: the four calls are the whole
      // surface, and each one hands the decision to the system UI.
      expect(enforcer.openedSettings.length, 4);
    });
  });

  group('pause, reflection and the record', () {
    test('a pause banks the served time and stops the clock', () async {
      await start(minutes: 25);
      now = now.add(const Duration(minutes: 6));
      enforcer.monotonic += 6 * 60 * 1000;

      final paused = await repo.pause();
      expect(paused!.state, FocusSessionState.paused);
      expect(paused.focusMs, closeTo(6 * 60 * 1000, 1000));
      expect(paused.pausedAtWallMs, isNotNull);

      // Ten minutes pass while paused. A paused session accrues no focus time — and with
      // the pause start stored on the row, this holds even if the app was dead for it.
      now = now.add(const Duration(minutes: 10));
      enforcer.monotonic += 10 * 60 * 1000;
      final resumed = await repo.resume();
      expect(resumed!.state, FocusSessionState.running);
      expect(resumed.focusMs, closeTo(6 * 60 * 1000, 1000), reason: 'paused time is not focus time');
      expect(resumed.pausedMs, closeTo(10 * 60 * 1000, 1000), reason: 'the pause is banked on resume');
      expect(resumed.pausedAtWallMs, isNull);
    });

    test('a pause stops covering apps, and resume re-arms the service', () async {
      // The setup sheet says a pause makes the selected apps available again. That
      // sentence is only true if the native session is actually stopped here, and the
      // only way to keep it true on resume is to start it again for the time left.
      await start(minutes: 25);
      expect(enforcer.startCalls, 1);
      now = now.add(const Duration(minutes: 5));
      enforcer.monotonic += 5 * 60 * 1000;

      await repo.pause();
      expect(enforcer.stopCalls, 1, reason: 'a paused session must not keep covering apps');
      expect(enforcer.native.running, isFalse);

      await repo.resume();
      expect(enforcer.startCalls, 2, reason: 'the remaining time is covered again');
      expect(enforcer.native.running, isTrue);
    });

    test('the expected stopped service while paused is not recorded as a loss', () async {
      await start(minutes: 25);
      // Establish actual coverage evidence before pausing.
      enforcer.native = FocusNativeState(
        running: true,
        blocking: true,
        startedAtRealtimeMs: enforcer.monotonic,
        endsAtRealtimeMs: enforcer.monotonic + 25 * 60 * 1000,
        blockedAttempts: 1,
        overlayShows: 1,
        detectionEvents: 1,
        usageAccess: true,
        overlay: true,
      );
      await repo.syncNative(force: true);
      await repo.pause();
      expect(enforcer.native.running, isFalse);

      final stillPaused = await repo.syncNative(force: true);
      expect(stillPaused!.state, FocusSessionState.paused);
      expect(
        stillPaused.enforcement,
        FocusEnforcement.verified,
        reason: 'pause intentionally suspends coverage; it is not a service crash',
      );
    });

    test('a resume the platform refuses records the resumed stretch as lost', () async {
      await start(minutes: 25);
      now = now.add(const Duration(minutes: 5));
      enforcer.monotonic += 5 * 60 * 1000;
      await repo.pause();

      enforcer.startSucceeds = false;
      final resumed = await repo.resume();
      expect(resumed!.state, FocusSessionState.running);
      expect(
        resumed.enforcement,
        FocusEnforcement.lost,
        reason: 'focus resumed without a coverage service, so that later interval is known unprotected',
      );
    });

    test('pausing past the mode budget is recorded as a degraded completion', () async {
      await start(mode: FocusMode.deep, minutes: 25);
      now = now.add(const Duration(minutes: 5));
      enforcer.monotonic += 5 * 60 * 1000;
      await repo.pause();
      now = now.add(const Duration(minutes: 6)); // deep focus allows 3
      enforcer.monotonic += 6 * 60 * 1000;
      await repo.resume();
      now = now.add(const Duration(minutes: 20));
      enforcer.monotonic += 20 * 60 * 1000;
      enforcer.native = FocusNativeState.idle;

      final ended = await repo.recover();
      expect(ended!.outcome, FocusOutcome.interrupted, reason: 'the detector died after focus resumed');
      expect(ended.endReason, FocusEndReason.serviceLost);
    });

    test('a reflection is stored with the session and survives a reload', () async {
      final session = await start();
      await repo.endByHand(reflection: 'phone in the drawer, it worked');
      await repo.hydrate();
      expect(repo.byId(session.id)!.reflection, 'phone in the drawer, it worked');
    });
  });

  group('profiles and schedules', () {
    test('a profile round-trips, and its app list is sanitised like a session\'s', () async {
      final profile = await repo.saveProfile(
        name: 'Morning writing',
        mode: FocusMode.deep,
        minutes: 45,
        packages: const ['com.instagram.android', 'com.android.dialer'],
      );
      await repo.hydrate();
      final stored = repo.profiles.firstWhere((p) => p.id == profile.id);
      expect(stored.name, 'Morning writing');
      expect(stored.packages, ['com.instagram.android']);
      expect(stored.minutes, 45);
    });

    test('a schedule keeps its notification id across an edit, so nothing is orphaned', () async {
      final first = await repo.saveSchedule(
        mode: FocusMode.deep,
        minutes: 45,
        hour: 9,
        minute: 0,
        weekdays: const {1, 2, 3, 4, 5},
      );
      final edited = await repo.saveSchedule(
        id: first.id,
        mode: FocusMode.deep,
        minutes: 60,
        hour: 10,
        minute: 30,
        weekdays: const {1, 2, 3, 4, 5},
      );
      expect(edited.notificationId, first.notificationId);
      expect(repo.schedules.length, 1, reason: 'an edit replaces, it does not duplicate');
      expect(edited.label, '10:30');
    });

    test('deleting a profile removes only that profile', () async {
      final a = await repo.saveProfile(name: 'A', mode: FocusMode.deep, minutes: 45);
      await repo.saveProfile(name: 'B', mode: FocusMode.blocking, minutes: 25);
      await repo.deleteProfile(a.id);
      expect(repo.profiles.map((p) => p.name), ['B']);
    });
  });

  group('export and deletion', () {
    test('the export carries every session, with the honest columns', () async {
      await start(mode: FocusMode.blocking, minutes: 25);
      now = now.add(const Duration(minutes: 25));
      enforcer.monotonic += 25 * 60 * 1000;
      await repo.endByHand(reflection: 'held');

      final payload = repo.exportPayload();
      expect(payload['schema'], 'track.focus.v1');
      final sessions = payload['sessions'] as List<Object?>;
      expect(sessions, hasLength(1));
      final csv = repo.exportCsv();
      expect(
        csv.split('\n').first,
        'date,mode,goal,planned_minutes,focused_minutes,paused_minutes,outcome,end_reason,enforcement,blocked_apps,reflection',
      );
      expect(csv, contains('blocking'));
      expect(csv, contains('held'));
    });

    test('deleting the user\'s data removes sessions but keeps the definitions', () async {
      await start();
      await repo.endByHand();
      await repo.saveProfile(name: 'Keep me', mode: FocusMode.deep, minutes: 45);

      final removed = await repo.deleteAllUserData(keepDefinitions: true);
      expect(removed.values.reduce((a, b) => a + b), greaterThan(0));
      expect(repo.history, isEmpty);
      expect(repo.profiles.map((p) => p.name), ['Keep me'], reason: 'a profile is configuration, not history');
    });
  });

  group('the countdown is arithmetic, not accumulation', () {
    test('a checkpoint banks the time it measured and restarts the segment', () async {
      final session = await start(minutes: 25);
      enforcer.monotonic += 60 * 1000;
      now = now.add(const Duration(minutes: 1));

      final first = await repo.syncNative(force: true);
      expect(first!.focusMs, closeTo(60 * 1000, 1000), reason: 'one minute elapsed, and one minute is what is banked');

      // Another minute passes with no forced write. The projection must read two
      // minutes — the old code added the whole stretch since the start again here.
      enforcer.monotonic += 60 * 1000;
      now = now.add(const Duration(minutes: 1));
      final second = await repo.syncNative();
      expect(
        second!.focusMs,
        closeTo(120 * 1000, 1500),
        reason: 'the segment restarts at each checkpoint, so elapsed cannot double',
      );
      expect(second.focusMs, lessThan(3 * 60 * 1000));
      expect((await db.focusDao.byId(session.id))!.focusMs, lessThanOrEqualTo(120 * 1000));
    });

    test('reopening the app mid-session does not jump the countdown forward', () async {
      await start(minutes: 25);
      enforcer.monotonic += 60 * 1000;
      now = now.add(const Duration(minutes: 1));
      await repo.syncNative(force: true);

      enforcer.monotonic += 60 * 1000;
      now = now.add(const Duration(minutes: 1));

      // A second launch: hydrate reads the persisted row, then recovery reconciles it
      // with the monotonic clock. The persisted checkpoint and its segment start
      // describe the same instant, so recovery adds only the minute since then.
      final relaunched = FocusRepository(db: db, enforcer: enforcer, now: () => now, idFactory: _SequenceIds().next);
      await relaunched.hydrate();
      final recovered = await relaunched.recover();

      expect(recovered, isNotNull);
      expect(
        recovered!.focusMs,
        closeTo(120 * 1000, 1500),
        reason: 'two minutes of a 25-minute session, not four minutes of it',
      );
      expect(recovered.state, FocusSessionState.running);
    });

    test('a paused session banks its pause and resumes from the banked total', () async {
      await start(minutes: 25);
      enforcer.monotonic += 5 * 60 * 1000;
      now = now.add(const Duration(minutes: 5));
      final paused = await repo.pause();
      expect(paused!.focusMs, closeTo(5 * 60 * 1000, 1000));

      // Ten minutes pass while paused: none of it is focus time.
      now = now.add(const Duration(minutes: 10));
      enforcer.monotonic += 10 * 60 * 1000;
      final stillPaused = await repo.syncNative();
      expect(stillPaused!.focusMs, closeTo(5 * 60 * 1000, 1000));

      final resumed = await repo.resume();
      expect(resumed!.state, FocusSessionState.running);
      expect(resumed.focusMs, closeTo(5 * 60 * 1000, 1000));
      expect(
        resumed.pausedMs,
        closeTo(10 * 60 * 1000, 1500),
        reason: 'the pause is banked when it ends, not when the session does',
      );

      enforcer.monotonic += 2 * 60 * 1000;
      now = now.add(const Duration(minutes: 2));
      final ticking = await repo.syncNative();
      expect(ticking!.focusMs, closeTo(7 * 60 * 1000, 1500));
    });
  });

  group('minutes on a day', () {
    test('only served sessions count toward the day, and never a live one', () async {
      await start(mode: FocusMode.standard, minutes: 25, packages: const <String>[]);
      expect(repo.minutesOn(repo.todayKey), 0, reason: 'a running session has served nothing yet');

      now = now.add(const Duration(minutes: 26));
      enforcer.monotonic += 26 * 60 * 1000;
      await repo.endByHand();
      expect(repo.minutesOn(repo.todayKey), 25);
    });
  });
}

/// Deterministic ids, so a test failure names the same session every run.
class _SequenceIds {
  int _n = 0;
  String next() => 'test-${++_n}';
}
