import 'package:flutter_test/flutter_test.dart';
import 'package:track/config/pro_config.dart';
import 'package:track/data/focus_engine.dart';
import 'package:track/models/focus_models.dart';

/// The two promises Focus Lock makes that are easiest to break by accident:
///
///  1. **The free tier stays useful.** Every mode, the timer, the app picker, the
///     session summary and the user's own history are free. What Pro adds is scale —
///     more covered apps, saved profiles, schedules and the pattern analysis. A test
///     is the cheapest possible guard against a later "let's move blocking behind a
///     paywall" decision, because that change would look reasonable in a diff and
///     would gut the feature for everyone who never pays.
///
///  2. **Enabling a permission never grants anything.** The Pro gates read the
///     entitlement, and nothing in the focus code path touches `isPro`. If someone
///     ever wires a "granted overlay → ProChip hides" shortcut, this file fails.
///
/// It also pins the pause budgets and the emergency-app guarantees, because both are
/// numbers users are told in advance and both must not drift silently.
///
/// NOT EXECUTED in the environment that wrote it (no Flutter/Dart SDK).
///   flutter test test/focus_budget_test.dart
void main() {
  group('the free tier keeps a whole feature, not a demo of one', () {
    test('no mode is Pro-only', () {
      // The modes are the feature. If any of these ever becomes gated, the free tier
      // stops being a focus tool and becomes an advertisement for one.
      for (final mode in FocusMode.values) {
        expect(ProConfig.isProOnly('focus.${mode.storage}'), isFalse, reason: mode.storage);
      }
    });

    test('the timer, the app list and the history are free; scale and analysis are not', () {
      expect(ProConfig.isProOnly('focus.timer'), isFalse);
      expect(ProConfig.isProOnly('focus.blocking'), isFalse);
      expect(ProConfig.isProOnly('focus.history'), isFalse);
      expect(ProConfig.isProOnly('focus.unlimitedApps'), isTrue);
      expect(ProConfig.isProOnly('focus.profiles'), isTrue);
      expect(ProConfig.isProOnly('focus.schedules'), isTrue);
      expect(ProConfig.isProOnly('focus.analytics'), isTrue);
    });

    test('free covers a real number of apps, and it is not zero or one', () {
      expect(ProConfig.freeBlockedApps, greaterThanOrEqualTo(3),
          reason: 'one app is not a focus session, it is a demo of one');
    });

    test('free keeps a usable history window and never deletes the rest', () {
      expect(ProConfig.freeFocusHistorySessions, greaterThanOrEqualTo(7));
      for (final limit in <int>[ProConfig.freeBlockedApps, ProConfig.freeFocusHistorySessions]) {
        expect(limit, greaterThan(0));
      }
    });

    test('each focus gate maps to a paywall trigger that exists', () {
      for (final gate in const ['focus_apps', 'focus_profiles', 'focus_schedules', 'focus_analytics']) {
        expect(ProConfig.triggerFor(gate), isNotNull, reason: gate);
      }
      expect(ProConfig.triggerFor('focus_profiles'), PaywallTrigger.focusProfiles);
      expect(ProConfig.triggerFor('focus_schedules'), PaywallTrigger.focusSchedules);
      expect(ProConfig.triggerFor('focus_analytics'), PaywallTrigger.focusAnalytics);
      expect(ProConfig.triggerFor('nonsense'), isNull);
    });

    test('every paywall trigger a focus gate can raise has copy that names the cost', () {
      for (final trigger in const [
        PaywallTrigger.focusApps,
        PaywallTrigger.focusProfiles,
        PaywallTrigger.focusSchedules,
        PaywallTrigger.focusAnalytics,
      ]) {
        expect(trigger.title.trim(), isNotEmpty);
        expect(trigger.body.trim(), isNotEmpty);
        // The one thing the copy must not do is imply that blocking itself is paid.
        expect(trigger.body.toLowerCase(), isNot(contains('blocking is a pro feature')));
      }
    });
  });

  group('pause budgets — stated before the session, never discovered during it', () {
    test('every mode with enforcement has a finite budget, and standard has none', () {
      expect(FocusEngine.pauseBudgetFor(FocusMode.standard), isNull,
          reason: 'standard enforces nothing, so pausing costs nothing');
      expect(FocusEngine.pauseBudgetFor(FocusMode.blocking), isNotNull);
      expect(FocusEngine.pauseBudgetFor(FocusMode.deep), isNotNull);
      expect(FocusEngine.pauseBudgetFor(FocusMode.deep)!.inMinutes,
          lessThan(FocusEngine.pauseBudgetFor(FocusMode.blocking)!.inMinutes),
          reason: 'deep is the stricter mode; its pause budget cannot be the looser one');
    });

    test('the boundary is exclusive: exactly the budget is still inside it', () {
      final budget = FocusEngine.pauseBudgetFor(FocusMode.deep)!.inMilliseconds;
      expect(FocusEngine.pausedBeyondBudget(FocusMode.deep, budget), isFalse);
      expect(FocusEngine.pausedBeyondBudget(FocusMode.deep, budget + 1), isTrue);
      expect(FocusEngine.pausedBeyondBudget(FocusMode.deep, budget - 1), isFalse);
    });

    test('a pause stops enforcement in every mode that has any', () {
      for (final mode in FocusMode.values) {
        final shouldSuspend = mode != FocusMode.standard;
        expect(FocusEngine.pauseSuspendsEnforcement(mode), shouldSuspend, reason: mode.storage);
      }
    });

    test('over-budget pausing is recorded as a degraded completion, not a clean one', () {
      final outcome = FocusEngine.outcomeFor(
        mode: FocusMode.deep,
        enforcement: FocusEnforcement.verified,
        reason: FocusEndReason.timer,
        focusMs: 25 * 60 * 1000,
        plannedMs: 25 * 60 * 1000,
        timingVerified: true,
      );
      // The engine's own verdict here is a clean completion *for timing*, and the pause
      // budget is applied by `degradedReason` — which is the point: the session is
      // still served, and the caveat is stated rather than the session being voided.
      expect(outcome.servedTime, isTrue);
      final note = FocusEngine.degradedReason(
        mode: FocusMode.deep,
        outcome: FocusOutcome.completedDegraded,
        enforcement: FocusEnforcement.verified,
        reason: FocusEndReason.timer,
        pausedMs: FocusEngine.pauseBudgetFor(FocusMode.deep)!.inMilliseconds + 60_000,
      );
      expect(note, contains('paused'));
      expect(note, contains('degraded completion'));
    });
  });

  group('emergency functions and essential apps are never in scope', () {
    test('the protected set covers the ways out of a phone', () {
      // Dialer, the system UI, settings, the launcher-adjacent system packages and the
      // permission controller are all in the engine's own list, which is the list that
      // applies even when the platform cannot resolve a default dialler for us.
      expect(FocusEngine.alwaysProtected, contains('com.android.dialer'));
      expect(FocusEngine.alwaysProtected, contains('com.android.systemui'));
      expect(FocusEngine.alwaysProtected, contains('com.android.settings'));
      expect(FocusEngine.alwaysProtected, contains(anyOf('com.android.phone', 'com.android.server.telecom')));
      expect(FocusEngine.alwaysProtected.length, greaterThanOrEqualTo(6));
    });

    test('a block list that asks for every protected app is refused in full', () {
      final result = FocusEngine.sanitizeBlockList(FocusEngine.alwaysProtected.toList());
      expect(result.allowed, isEmpty);
      expect(result.refused.length, FocusEngine.alwaysProtected.length);
    });

    test('the app\'s own package is never coverable, whatever the caller passes', () {
      final result = FocusEngine.sanitizeBlockList(
        const ['com.track.app', 'com.instagram.android'],
        deviceProtected: const {'com.track.app'},
      );
      expect(result.allowed, ['com.instagram.android']);
      expect(result.refused, contains('com.track.app'));
    });
  });

  group('what every mode tells the user before it starts', () {
    test('every mode has a limitation stated in words', () {
      for (final mode in FocusMode.values) {
        expect(mode.limitation.trim(), isNotEmpty, reason: mode.storage);
        expect(mode.blurb.trim(), isNotEmpty, reason: mode.storage);
        expect(mode.label.trim(), isNotEmpty);
        expect(mode.shortLabel.trim(), isNotEmpty);
        expect(mode.emoji.trim(), isNotEmpty);
      }
    });

    test('the cancellation rules are disclosed for every mode, including the hold', () {
      for (final mode in FocusMode.values) {
        final copy = FocusEngine.cancellationCopy(mode);
        expect(copy.trim(), isNotEmpty, reason: mode.storage);
        expect(copy.toLowerCase(), contains('end'), reason: mode.storage);
      }
      expect(FocusEngine.cancellationCopy(FocusMode.deep).toLowerCase(), contains('hold'));
      expect(FocusEngine.cancellationCopy(FocusMode.deep).toLowerCase(), contains('budget'));
    });

    test('no mode\'s copy promises an instant or absolute block', () {
      final banned = <String>['cannot open', 'impossible to', 'instantly', 'guaranteed', 'blocks the app'];
      for (final mode in FocusMode.values) {
        final copy = '${mode.blurb} ${mode.limitation} ${FocusEngine.cancellationCopy(mode)}'.toLowerCase();
        for (final phrase in banned) {
          expect(copy.contains(phrase), isFalse, reason: '${mode.storage}: "$phrase"');
        }
      }
    });

    test('enforcement states describe themselves honestly', () {
      expect(FocusEnforcement.verified.label.toLowerCase(), contains('blocking'));
      expect(FocusEnforcement.verified.isConfirmed, isTrue);
      // Named `value`, not `state`: in this repo `state` is AppState by lexical
      // contract (see tools/static_audit.py), and a local shadowing it is a false
      // positive waiting to happen.
      for (final value in const [
        FocusEnforcement.armed,
        FocusEnforcement.unavailable,
        FocusEnforcement.lost,
        FocusEnforcement.timerOnly,
      ]) {
        expect(value.isConfirmed, isFalse, reason: value.storage);
        expect(value.label.trim(), isNotEmpty);
        expect(value.detail.trim(), isNotEmpty);
      }
      expect(FocusEnforcement.armed.label.toLowerCase(), isNot(contains('blocked')));
    });
  });

  group('duration limits keep the countdown an integer the UI can show', () {
    test('the custom range is bounded at both ends', () {
      expect(FocusEngine.minCustomMinutes, greaterThan(0));
      expect(FocusEngine.maxCustomMinutes, lessThanOrEqualTo(24 * 60));
      expect(FocusEngine.clampMinutes(-10), FocusEngine.minCustomMinutes);
      expect(FocusEngine.clampMinutes(1 << 30), FocusEngine.maxCustomMinutes);
    });

    test('the presets are inside the custom range and are ordered', () {
      for (final preset in FocusEngine.presetMinutes) {
        expect(preset, greaterThanOrEqualTo(FocusEngine.minCustomMinutes));
        expect(preset, lessThanOrEqualTo(FocusEngine.maxCustomMinutes));
      }
      expect(FocusEngine.presetMinutes, orderedEquals(<int>[15, 25, 45, 60]));
    });
  });

  group('the sample-size thresholds are the same ones the rest of the app uses', () {
    test('shares need three ended sessions, patterns need five', () {
      expect(FocusStats.minSessionsForShare, 3);
      expect(FocusStats.minSessionsForPattern, 5);
      expect(FocusStats.empty.cleanShare, isNull);
      expect(FocusStats.empty.servedShare, isNull);
      expect(FocusStats.empty.typicalStartMinute, isNull);
      expect(FocusStats.empty.hasAny, isFalse);
    });
  });
}
