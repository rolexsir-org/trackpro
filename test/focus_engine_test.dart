import 'package:flutter_test/flutter_test.dart';
import 'package:track/data/focus_engine.dart';
import 'package:track/models/focus_models.dart';

/// Focus Lock's rules, as tests.
///
/// These are the rules the whole feature is judged on, and every one of them is a
/// statement about **what the app is allowed to claim**:
///
///   * `verified` requires evidence. A service that is running and a permission that
///     is granted are not evidence that an app was ever seen or covered.
///   * A session that lost enforcement is never a clean completion.
///   * A monotonic clock that went backwards (a reboot) is an interrupted session, not
///     a session with a negative duration.
///   * Protected packages cannot be covered, no matter what the caller asks for.
///
/// NOTE: this file has never been executed in the environment it was written in —
/// there is no Flutter/Dart SDK there. It is written to run under `flutter test` on a
/// machine that has one, and it is listed as NOT TESTED until it has.
void main() {
  const minutes = 60 * 1000;

  FocusSession session({
    FocusMode mode = FocusMode.blocking,
    FocusSessionState state = FocusSessionState.running,
    FocusOutcome? outcome,
    FocusEnforcement enforcement = FocusEnforcement.timerOnly,
    FocusEndReason? endReason,
    int focusMs = 0,
    int pausedMs = 0,
    int plannedMinutes = 25,
    int? segmentStartedAtRealtimeMs = 1000,
    List<String> blockedPackages = const <String>[],
    int blockedAttempts = 0,
    int detectionEvents = 0,
    bool timingVerified = true,
    String? reflection,
    String id = 's1',
    int startedAtWallMs = 1_700_000_000_000,
  }) {
    return FocusSession(
      id: id,
      mode: mode,
      plannedMinutes: plannedMinutes,
      goalLabel: 'Focus session',
      startedAtWallMs: startedAtWallMs,
      startedAtRealtimeMs: 1000,
      segmentStartedAtRealtimeMs: segmentStartedAtRealtimeMs,
      focusMs: focusMs,
      pausedMs: pausedMs,
      state: state,
      outcome: outcome,
      enforcement: enforcement,
      endReason: endReason,
      blockedAttempts: blockedAttempts,
      overlayShows: 0,
      detectionEvents: detectionEvents,
      timingVerified: timingVerified,
      blockedPackages: blockedPackages,
      endedAtWallMs: state == FocusSessionState.ended ? 1_700_000_600_000 : null,
      reflection: reflection,
      day: 20261016,
      source: 'app',
    );
  }

  group('enforcementFor — the rule that nothing is claimed without evidence', () {
    test('timer-only session is timerOnly and never "blocking"', () {
      final e = FocusEngine.enforcementFor(
        blockingRequested: false,
        serviceAlive: true,
        permissionLostMidSession: false,
        overlayGranted: true,
        usageAccessGranted: true,
        detectionEvents: 12,
        overlayShows: 0,
      );
      expect(e, FocusEnforcement.timerOnly);
      expect(e.intendsToBlock, isFalse);
      expect(e.isConfirmed, isFalse);
    });

    test('service alive with both grants but zero detections is armed, not verified', () {
      final e = FocusEngine.enforcementFor(
        blockingRequested: true,
        serviceAlive: true,
        permissionLostMidSession: false,
        overlayGranted: true,
        usageAccessGranted: true,
        detectionEvents: 0,
        overlayShows: 0,
      );
      expect(e, FocusEnforcement.armed);
      // The important assertion: armed is *not* a claim that blocking worked.
      expect(e.isConfirmed, isFalse);
      expect(e.needsAttention, isTrue);
    });

    test('a foreground event without a launched panel remains armed', () {
      final e = FocusEngine.enforcementFor(
        blockingRequested: true,
        serviceAlive: true,
        permissionLostMidSession: false,
        overlayGranted: true,
        usageAccessGranted: true,
        detectionEvents: 1,
        overlayShows: 0,
      );
      expect(e, FocusEnforcement.armed);
      expect(e.isConfirmed, isFalse);
    });

    test('a detected selected app with a launched coverage panel upgrades to verified', () {
      final e = FocusEngine.enforcementFor(
        blockingRequested: true,
        serviceAlive: true,
        permissionLostMidSession: false,
        overlayGranted: true,
        usageAccessGranted: true,
        detectionEvents: 1,
        overlayShows: 1,
      );
      expect(e, FocusEnforcement.verified);
      expect(e.isConfirmed, isTrue);
      expect(e.tone, 'full');
    });

    test('missing usage access or overlay is unavailable, whatever else is true', () {
      for (final grants in const [
        (usage: false, overlay: true),
        (usage: true, overlay: false),
        (usage: false, overlay: false),
      ]) {
        final e = FocusEngine.enforcementFor(
          blockingRequested: true,
          serviceAlive: true,
          permissionLostMidSession: false,
          overlayGranted: grants.overlay,
          usageAccessGranted: grants.usage,
          detectionEvents: 40,
          overlayShows: 0,
        );
        expect(e, FocusEnforcement.unavailable, reason: 'grants=$grants');
        expect(e.isConfirmed, isFalse);
      }
    });

    test('a permission lost mid-session outranks a healthy service', () {
      final e = FocusEngine.enforcementFor(
        blockingRequested: true,
        serviceAlive: true,
        permissionLostMidSession: true,
        overlayGranted: true,
        usageAccessGranted: true,
        detectionEvents: 40,
        overlayShows: 0,
      );
      expect(e, FocusEnforcement.lost);
      expect(e.isConfirmed, isFalse);
      expect(e.needsAttention, isTrue);
    });

    test('a dead service with detections from before is lost, not verified', () {
      final e = FocusEngine.enforcementFor(
        blockingRequested: true,
        serviceAlive: false,
        permissionLostMidSession: false,
        overlayGranted: true,
        usageAccessGranted: true,
        detectionEvents: 9,
        overlayShows: 0,
      );
      expect(e, FocusEnforcement.lost);
      expect(e.isConfirmed, isFalse);
    });
  });

  group('outcomeFor — what a session may be called afterwards', () {
    test('timer expiry with enforcement held the whole way is a clean completion', () {
      final outcome = FocusEngine.outcomeFor(
        mode: FocusMode.deep,
        enforcement: FocusEnforcement.verified,
        reason: FocusEndReason.timer,
        focusMs: 25 * minutes,
        plannedMs: 25 * minutes,
        timingVerified: true,
      );
      expect(outcome, FocusOutcome.completed);
      expect(outcome.isClean, isTrue);
    });

    test('a blocking session that ended armed is completed-degraded, not clean', () {
      final outcome = FocusEngine.outcomeFor(
        mode: FocusMode.blocking,
        enforcement: FocusEnforcement.armed,
        reason: FocusEndReason.timer,
        focusMs: 25 * minutes,
        plannedMs: 25 * minutes,
        timingVerified: true,
      );
      expect(outcome, FocusOutcome.completedDegraded);
      expect(outcome.isClean, isFalse);
    });

    test('losing enforcement mid-session cannot produce a clean completion', () {
      for (final reason in const [
        FocusEndReason.serviceLost,
        FocusEndReason.deviceRestarted,
        FocusEndReason.permissionRevoked,
        FocusEndReason.appUpdated,
      ]) {
        final outcome = FocusEngine.outcomeFor(
          mode: FocusMode.deep,
          enforcement: FocusEnforcement.lost,
          reason: reason,
          focusMs: 25 * minutes,
          plannedMs: 25 * minutes,
          timingVerified: true,
        );
        expect(outcome, FocusOutcome.interrupted, reason: reason.name);
        expect(outcome.isClean, isFalse);
      }
    });

    test('ending early is a cancellation, and the time already served stays in history', () {
      final outcome = FocusEngine.outcomeFor(
        mode: FocusMode.standard,
        enforcement: FocusEnforcement.timerOnly,
        reason: FocusEndReason.cancelled,
        focusMs: 6 * minutes,
        plannedMs: 25 * minutes,
        timingVerified: true,
      );
      expect(outcome, FocusOutcome.cancelled);
      expect(outcome.isClean, isFalse);
      // A cancelled session is not *served* time: it must not inflate the clean figures
      // or the "minutes focused" the stats screen prints.
      expect(outcome.servedTime, isFalse);
    });

    test('a standard session that reaches the end is clean without any service', () {
      final outcome = FocusEngine.outcomeFor(
        mode: FocusMode.standard,
        enforcement: FocusEnforcement.timerOnly,
        reason: FocusEndReason.timer,
        focusMs: 25 * minutes,
        plannedMs: 25 * minutes,
        timingVerified: true,
      );
      expect(outcome, FocusOutcome.completed);
    });

    test('a session timed off the wall clock that had to block is degraded, not clean', () {
      final outcome = FocusEngine.outcomeFor(
        mode: FocusMode.blocking,
        enforcement: FocusEnforcement.verified,
        reason: FocusEndReason.timer,
        focusMs: 25 * minutes,
        plannedMs: 25 * minutes,
        timingVerified: false,
      );
      expect(outcome, FocusOutcome.completedDegraded);
    });
  });

  group('recover — clocks that moved underneath the session', () {
    test('a running session accrues time from the monotonic clock', () {
      final r = FocusEngine.recover(
        session: session(segmentStartedAtRealtimeMs: 1000, plannedMinutes: 25),
        nowRealtimeMs: 1000 + 5 * minutes,
        nowWallMs: 1_700_000_300_000,
        monotonicAvailable: true,
      );
      expect(r.elapsedMs, 5 * minutes);
      expect(r.remainingMs, 20 * minutes);
      expect(r.timedOutWhileAway, isFalse);
      expect(r.staleByMs, 0);
    });

    test('a reboot is detected as a negative delta and never yields negative time', () {
      final r = FocusEngine.recover(
        session: session(segmentStartedAtRealtimeMs: 500_000_000, focusMs: 3 * minutes),
        // elapsedRealtime resets to a small number after a reboot.
        nowRealtimeMs: 4_000,
        nowWallMs: 1_700_009_000_000,
        monotonicAvailable: true,
      );
      expect(r.rebooted, isTrue);
      expect(r.elapsedMs, 3 * minutes, reason: 'only the banked focus time survives');
      expect(r.remainingMs, 22 * minutes);
    });

    test('an hour away past the end is reported as timed out while away', () {
      final r = FocusEngine.recover(
        session: session(segmentStartedAtRealtimeMs: 1000, plannedMinutes: 25),
        nowRealtimeMs: 1000 + 60 * minutes,
        nowWallMs: 1_700_003_600_000,
        monotonicAvailable: true,
      );
      expect(r.timedOutWhileAway, isTrue);
      expect(r.elapsedMs, 25 * minutes, reason: 'clamped to the planned length');
      expect(r.remainingMs, 0);
    });

    test('a paused session accrues no focus time at all', () {
      final r = FocusEngine.recover(
        session: session(
          state: FocusSessionState.paused,
          segmentStartedAtRealtimeMs: null,
          focusMs: 4 * minutes,
          pausedMs: 2 * minutes,
        ),
        nowRealtimeMs: 1000 + 90 * minutes,
        nowWallMs: 1_700_005_400_000,
        monotonicAvailable: true,
      );
      expect(r.elapsedMs, 4 * minutes);
      expect(r.remainingMs, 21 * minutes);
    });

    test('no monotonic clock is a degraded session, and it says so', () {
      final r = FocusEngine.recover(
        session: session(segmentStartedAtRealtimeMs: null, plannedMinutes: 25),
        nowRealtimeMs: 0,
        nowWallMs: 1_700_000_300_000,
        monotonicAvailable: false,
      );
      expect(r.monotonicTrusted, isFalse);
    });
  });

  group('block lists — protected packages are refused, not dropped', () {
    test('the dialler and the launcher can never be covered', () {
      for (final pkg in FocusEngine.alwaysProtected) {
        expect(FocusEngine.isProtected(pkg), isTrue, reason: pkg);
      }
      expect(FocusEngine.isProtected('com.android.dialer', deviceProtected: const {'com.android.dialer'}), isTrue);
      expect(FocusEngine.isProtected('com.instagram.android'), isFalse);
    });

    test('sanitizeBlockList returns the allowed and the refused, never silently', () {
      final result = FocusEngine.sanitizeBlockList(
        const ['com.instagram.android', 'com.android.systemui', 'com.example.reader'],
        deviceProtected: const {'com.example.reader'},
      );
      expect(result.allowed, contains('com.instagram.android'));
      expect(result.refused, contains('com.android.systemui'));
      expect(result.refused, contains('com.example.reader'));
      // Nothing is invented into the block list, and nothing refused is quietly kept.
      expect(result.allowed.length, 1);
      expect(result.allowed.toSet().intersection(result.refused.toSet()), isEmpty);
    });

    test('duplicates and blanks are collapsed', () {
      final result = FocusEngine.sanitizeBlockList(const ['com.a', 'com.a', '  ', 'com.b']);
      expect(result.allowed, ['com.a', 'com.b']);
    });
  });

  group('pause budget and minutes', () {
    test('each mode has the pause budget it documents', () {
      expect(FocusEngine.pauseBudgetFor(FocusMode.standard), isNull);
      expect(FocusEngine.pauseBudgetFor(FocusMode.blocking)!.inMinutes, 5);
      expect(FocusEngine.pauseBudgetFor(FocusMode.deep)!.inMinutes, 3);
    });

    test('pausing past the budget is flagged, and standard has no budget to break', () {
      expect(FocusEngine.pausedBeyondBudget(FocusMode.deep, 4 * minutes), isTrue);
      expect(FocusEngine.pausedBeyondBudget(FocusMode.deep, 2 * minutes), isFalse);
      expect(FocusEngine.pausedBeyondBudget(FocusMode.standard, 90 * minutes), isFalse);
    });

    test('only standard keeps covering apps while paused', () {
      expect(FocusEngine.pauseSuspendsEnforcement(FocusMode.standard), isFalse);
      expect(FocusEngine.pauseSuspendsEnforcement(FocusMode.blocking), isTrue);
      expect(FocusEngine.pauseSuspendsEnforcement(FocusMode.deep), isTrue);
    });

    test('minutes are clamped to what the UI can present', () {
      expect(FocusEngine.clampMinutes(0), FocusEngine.minCustomMinutes);
      expect(FocusEngine.clampMinutes(9_999), FocusEngine.maxCustomMinutes);
      expect(FocusEngine.clampMinutes(45), 45);
    });
  });

  group('stats — no figure without a sample', () {
    test('an empty history has no shares and no typical start', () {
      final stats = FocusEngine.statsFor(const [], todayKey: 20261016);
      expect(stats.endedSessions, 0);
      expect(stats.cleanShare, isNull);
      expect(stats.servedShare, isNull);
      expect(stats.typicalStartMinute, isNull);
      expect(stats.hasAny, isFalse);
    });

    test('two sessions is not a rate; three is the threshold', () {
      final two = FocusEngine.statsFor([
        session(outcome: FocusOutcome.completed, state: FocusSessionState.ended, focusMs: 25 * minutes),
        session(outcome: FocusOutcome.cancelled, state: FocusSessionState.ended, focusMs: 4 * minutes),
      ], todayKey: 20261016);
      expect(two.endedSessions, 2);
      expect(two.cleanShare, isNull, reason: 'below minSessionsForShare');

      final three = FocusEngine.statsFor([
        session(outcome: FocusOutcome.completed, state: FocusSessionState.ended, focusMs: 25 * minutes),
        session(outcome: FocusOutcome.cancelled, state: FocusSessionState.ended, focusMs: 4 * minutes),
        session(outcome: FocusOutcome.completedDegraded, state: FocusSessionState.ended, focusMs: 25 * minutes),
      ], todayKey: 20261016);
      expect(three.endedSessions, 3);
      expect(three.cleanShare, isNotNull);
      expect(three.cleanShare!.round(), 33);
    });

    test('the clean streak stops at the first session that was not clean', () {
      // Distinct start times: the streak is counted most-recent-first, so the order has
      // to be a fact of the data, not a coincidence of `sort`.
      final stats = FocusEngine.statsFor([
        session(
          outcome: FocusOutcome.completed,
          state: FocusSessionState.ended,
          focusMs: 25 * minutes,
          startedAtWallMs: 1_700_000_400_000,
        ),
        session(
          outcome: FocusOutcome.completed,
          state: FocusSessionState.ended,
          focusMs: 45 * minutes,
          startedAtWallMs: 1_700_000_300_000,
        ),
        session(
          outcome: FocusOutcome.cancelled,
          state: FocusSessionState.ended,
          focusMs: 2 * minutes,
          startedAtWallMs: 1_700_000_200_000,
        ),
        session(
          outcome: FocusOutcome.completed,
          state: FocusSessionState.ended,
          focusMs: 25 * minutes,
          startedAtWallMs: 1_700_000_100_000,
        ),
      ], todayKey: 20261016);
      expect(stats.cleanStreak, 2, reason: 'newest two were clean, then a cancellation');
    });

    test('only served time counts: an interrupted stretch is not focus minutes', () {
      final stats = FocusEngine.statsFor([
        session(outcome: FocusOutcome.completed, state: FocusSessionState.ended, focusMs: 25 * minutes),
        session(outcome: FocusOutcome.completedDegraded, state: FocusSessionState.ended, focusMs: 25 * minutes),
        session(outcome: FocusOutcome.cancelled, state: FocusSessionState.ended, focusMs: 6 * minutes),
        session(outcome: FocusOutcome.interrupted, state: FocusSessionState.ended, focusMs: 9 * minutes),
      ], todayKey: 20261016);
      // 25 + 25. The cancelled and the interrupted stretches are in the history — the
      // user can read every session in full — but they are not added to the totals, or
      // "minutes focused" would reward the sessions that did not happen.
      expect(stats.minutesTotal, 50);
      expect(stats.endedSessions, 4);
    });
  });

  group('summary — the sentence shown after a session', () {
    test('a clean session says so, and does not overstate the block', () {
      final s = FocusEngine.summaryFor(
        session(
          outcome: FocusOutcome.completed,
          state: FocusSessionState.ended,
          enforcement: FocusEnforcement.verified,
          blockedPackages: const ['com.instagram.android'],
          blockedAttempts: 3,
          focusMs: 25 * minutes,
        ),
      );
      expect(s.minutesFocused, 25);
      expect(s.headline, '25-minute focus session');
      // A clean session has nothing to disclose, so the note is empty — the UI shows
      // the note only when there is one.
      expect(s.cleanlinessNote, isEmpty);
      expect(s.blockedApps, contains('com.instagram.android'));
    });

    test('a degraded session explains the degradation rather than blaming the user', () {
      final s = FocusEngine.summaryFor(
        session(
          outcome: FocusOutcome.completedDegraded,
          state: FocusSessionState.ended,
          enforcement: FocusEnforcement.armed,
          blockedPackages: const ['com.instagram.android'],
          focusMs: 25 * minutes,
        ),
      );
      expect(s.cleanlinessNote, contains('never confirmed'));
      expect(s.cleanlinessNote, contains('degraded session rather than a clean one'));
    });
  });

  group('labels', () {
    test('durations read the way a person would say them', () {
      expect(focusDurationLabel(0), '0 min');
      expect(focusDurationLabel(60 * 1000), '1 min');
      expect(focusDurationLabel(25 * 60 * 1000), '25 min');
      expect(focusDurationLabel(65 * 60 * 1000), '1 h 05');
    });

    test('the countdown is floored, never negative, and capped at a day', () {
      // Floored: a session with 900 ms left reads 0:00, never 0:01 — the countdown may
      // lag a frame, it may never promise time that has already gone.
      expect(focusCountdownLabel(0), '0:00');
      expect(focusCountdownLabel(900), '0:00');
      expect(focusCountdownLabel(18 * 60 * 1000 + 42 * 1000), '18:42');
      expect(focusCountdownLabel(-5_000), '0:00');
      expect(focusCountdownLabel(48 * 60 * 60 * 1000), '1440:00', reason: 'capped at 24 h');
    });
  });
}
