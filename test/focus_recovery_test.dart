import 'package:flutter_test/flutter_test.dart';
import 'package:track/data/focus_engine.dart';
import 'package:track/models/focus_models.dart';

/// The recovery matrix: everything that can happen to a session while nobody is
/// looking at it, and the single answer the app is allowed to give for each.
///
/// This file is deliberately engine-only and database-free. Recovery is where a
/// habit app lies most easily — "you completed your session" is a kinder sentence
/// than "your phone restarted 4 minutes in" — so the rules are asserted here, in
/// isolation, without a repository, a platform or a clock to argue with.
///
/// The scenarios, all named by the brief:
///  * background/foreground (a checkpoint taken while the app was away),
///  * reboot (the monotonic clock resets),
///  * permission revocation (the platform reports less than it did),
///  * expiry (the planned time is behind us),
///  * an app update (Android stops the service),
///  * process termination (the app comes back to a session it did not supervise).
///
/// NOT EXECUTED in the environment that wrote it (no Flutter/Dart SDK).
///   flutter test test/focus_recovery_test.dart
void main() {
  const minutes = 60 * 1000;

  FocusSession live({
    FocusMode mode = FocusMode.deep,
    FocusEnforcement enforcement = FocusEnforcement.verified,
    int plannedMinutes = 25,
    int focusMs = 0,
    int pausedMs = 0,
    int? segmentStart = 1_000_000,
    int? pausedAtWallMs,
    FocusSessionState state = FocusSessionState.running,
    bool timingVerified = true,
  }) {
    return FocusSession(
      id: 's1',
      mode: mode,
      plannedMinutes: plannedMinutes,
      goalLabel: 'Writing',
      startedAtWallMs: 1_700_000_000_000,
      startedAtRealtimeMs: 1_000_000,
      segmentStartedAtRealtimeMs: segmentStart,
      pausedAtWallMs: pausedAtWallMs,
      focusMs: focusMs,
      pausedMs: pausedMs,
      state: state,
      enforcement: enforcement,
      timingVerified: timingVerified,
      day: 20261016,
    );
  }

  group('background → foreground, a few minutes later', () {
    test('the segment is added to the banked time, not restarted from zero', () {
      final r = FocusEngine.recover(
        session: live(focusMs: 5 * minutes, segmentStart: 1_000_000, plannedMinutes: 25),
        nowRealtimeMs: 1_000_000 + 3 * minutes,
        nowWallMs: 1_700_000_180_000,
      );
      expect(r.elapsedMs, 8 * minutes);
      expect(r.remainingMs, 17 * minutes);
      expect(r.expired, isFalse);
      // How long the current segment has been running — the number the checkpoint
      // logic uses to decide whether the row needs rewriting.
      expect(r.staleByMs, 3 * minutes);
    });

    test('a running session with no segment start falls back to the wall clock', () {
      // This combination should not occur (start and resume both set a segment), but a
      // defensive branch that counted nothing would freeze the countdown for an hour.
      // The wall clock is the wrong clock — and it is still a clock.
      final r = FocusEngine.recover(
        session: live(focusMs: 4 * minutes, segmentStart: null, plannedMinutes: 25),
        nowRealtimeMs: 1_000_000 + 30 * minutes,
        nowWallMs: 1_700_000_000_000 + 30 * minutes,
      );
      expect(r.elapsedMs, 25 * minutes, reason: 'clamped to the plan');
      expect(r.staleByMs, 0, reason: 'no segment to measure');
      expect(r.expired, isTrue);
    });
  });

  group('reboot', () {
    test('the monotonic clock resetting is a reboot, not a negative session', () {
      final r = FocusEngine.recover(
        session: live(focusMs: 12 * minutes, segmentStart: 999_000_000, plannedMinutes: 45),
        nowRealtimeMs: 9_000, // the device came back up a few seconds ago
        nowWallMs: 1_700_030_000_000,
      );
      expect(r.rebooted, isTrue);
      expect(r.elapsedMs, 12 * minutes, reason: 'only what was banked survives a restart');
      expect(r.elapsedMs, isNonNegative);
      expect(r.remainingMs, 33 * minutes);
      expect(r.timedOutWhileAway, isFalse);
    });

    test('a reboot after the planned time still does not invent a completion', () {
      final r = FocusEngine.recover(
        session: live(focusMs: 20 * minutes, segmentStart: 999_000_000, plannedMinutes: 20),
        nowRealtimeMs: 500,
        nowWallMs: 1_700_090_000_000,
      );
      expect(r.rebooted, isTrue);
      expect(r.elapsedMs, 20 * minutes);
      // Recovery refuses to call even a full-length session expired after a restart:
      // the verdict belongs to `outcomeFor`, which will make it `interrupted` because
      // the device restarted. Recovery never upgrades an outcome on its own.
      expect(r.expired, isFalse);
    });

    test('the wall clock moving backwards does not undo the monotonic one', () {
      final r = FocusEngine.recover(
        session: live(focusMs: 0, segmentStart: 1_000_000, plannedMinutes: 25),
        nowRealtimeMs: 1_000_000 + 5 * minutes,
        // The user set the date back a week mid-session.
        nowWallMs: 1_699_400_000_000,
      );
      expect(r.elapsedMs, 5 * minutes);
      expect(r.clockMovedBackwards, isTrue);
      expect(r.monotonicTrusted, isTrue);
    });
  });

  group('expiry', () {
    test('returning an hour after a 25-minute session ends it at the plan, not at the hour', () {
      final r = FocusEngine.recover(
        session: live(focusMs: 0, segmentStart: 1_000_000, plannedMinutes: 25),
        nowRealtimeMs: 1_000_000 + 85 * minutes,
        nowWallMs: 1_700_005_100_000,
      );
      expect(r.expired, isTrue);
      expect(r.timedOutWhileAway, isTrue);
      expect(r.elapsedMs, 25 * minutes);
      expect(r.remainingMs, 0);
    });

    test('a paused session that outlived its window is still not a completion', () {
      final r = FocusEngine.recover(
        session: live(
          focusMs: 10 * minutes,
          pausedMs: 2 * minutes,
          segmentStart: null,
          pausedAtWallMs: 1_700_000_120_000,
          state: FocusSessionState.paused,
          plannedMinutes: 25,
        ),
        nowRealtimeMs: 1_000_000 + 90 * minutes,
        nowWallMs: 1_700_005_400_000,
      );
      expect(r.elapsedMs, 10 * minutes, reason: 'a paused session accrues nothing');
      expect(r.remainingMs, 15 * minutes);
    });
  });

  group('permission revocation and app updates', () {
    test('a revoked permission is unenforced time, and the note says which', () {
      final note = FocusEngine.degradedReason(
        mode: FocusMode.blocking,
        outcome: FocusOutcome.interrupted,
        enforcement: FocusEnforcement.lost,
        reason: FocusEndReason.permissionRevoked,
        pausedMs: 0,
      );
      expect(note, contains('permission'));
      expect(note, contains('interrupted'));
      expect(note, isNot(contains('completed')));
    });

    test('an app update that stops the service is an interruption, and it is named', () {
      final note = FocusEngine.degradedReason(
        mode: FocusMode.deep,
        outcome: FocusOutcome.interrupted,
        enforcement: FocusEnforcement.lost,
        reason: FocusEndReason.appUpdated,
        pausedMs: 0,
      );
      expect(note, contains('updated'));
      expect(note, contains('interrupted'));
    });

    test('an enforcement state that was never confirmed produces a caveat, not silence', () {
      final note = FocusEngine.degradedReason(
        mode: FocusMode.blocking,
        outcome: FocusOutcome.completedDegraded,
        enforcement: FocusEnforcement.armed,
        reason: FocusEndReason.timer,
        pausedMs: 0,
      );
      expect(note, contains('never confirmed'));
    });

    test('losing enforcement after a clean-looking timer still cannot read as clean', () {
      final outcome = FocusEngine.outcomeFor(
        mode: FocusMode.blocking,
        enforcement: FocusEnforcement.lost,
        reason: FocusEndReason.permissionRevoked,
        focusMs: 25 * minutes,
        plannedMs: 25 * minutes,
        timingVerified: true,
      );
      expect(outcome.isClean, isFalse);
      expect(outcome, FocusOutcome.interrupted);
    });
  });

  group('process termination', () {
    test('a session reopened after a kill keeps its banked time and its enforcement verdict', () {
      // What a killed process leaves behind: focusMs as of the last checkpoint, a
      // segment start from before the kill, and whatever enforcement was last written.
      final r = FocusEngine.recover(
        session: live(
          focusMs: 7 * minutes,
          segmentStart: null,
          enforcement: FocusEnforcement.armed,
          plannedMinutes: 25,
        ),
        nowRealtimeMs: 1_000_000 + 4 * minutes,
        nowWallMs: 1_700_000_240_000,
      );
      expect(r.elapsedMs, 7 * minutes, reason: 'no segment to add — the clock stopped with the process');
      expect(r.session.enforcement, FocusEnforcement.armed);
      expect(r.session.enforcement.isConfirmed, isFalse,
          reason: 'a kill cannot upgrade what the platform last reported');
    });

    test('wall-clock timing is recorded as unverified rather than trusted', () {
      final r = FocusEngine.recover(
        session: live(segmentStart: null, timingVerified: false, plannedMinutes: 25),
        nowRealtimeMs: 0,
        nowWallMs: 1_700_004_000_000,
        monotonicAvailable: false,
      );
      expect(r.monotonicTrusted, isFalse);
    });
  });

  group('the summary a recovered session gets', () {
    test('an interrupted session keeps its time in the history and explains itself', () {
      final session = live(
        focusMs: 9 * minutes,
        enforcement: FocusEnforcement.lost,
      ).copyWith(
        state: FocusSessionState.ended,
        outcome: FocusOutcome.interrupted,
        endReason: FocusEndReason.deviceRestarted,
        endedAtWallMs: 1_700_000_540_000,
      );
      final summary = FocusEngine.summaryFor(session);
      expect(summary.headline, 'Session interrupted');
      expect(summary.minutesFocused, 9);
      expect(summary.detail, contains('9 min'));
      expect(summary.cleanlinessNote, contains('restarted'));
    });

    test('a cancelled session says it cost the user nothing', () {
      final session = live(focusMs: 3 * minutes).copyWith(
        state: FocusSessionState.ended,
        outcome: FocusOutcome.cancelled,
        endReason: FocusEndReason.cancelled,
        endedAtWallMs: 1_700_000_180_000,
      );
      final summary = FocusEngine.summaryFor(session);
      expect(summary.headline, 'Session ended early');
      expect(summary.detail, contains('costs you nothing'));
      expect(summary.minutesFocused, 3);
    });

    test('an unrecorded outcome is never described as a completion', () {
      final session = live(); // still running, no outcome
      final summary = FocusEngine.summaryFor(session);
      expect(summary.headline, 'Session ended early');
      expect(summary.session.outcome, isNull);
    });
  });
}
