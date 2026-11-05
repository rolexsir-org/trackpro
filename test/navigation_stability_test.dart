import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:track/data/commitment_repository.dart';
import 'package:track/data/db/database.dart';
import 'package:track/data/default_trackers.dart';
import 'package:track/data/entry_repository.dart';
import 'package:track/data/insights_engine.dart';
import 'package:track/screens/insights_screen.dart';
import 'package:track/state/app_state.dart';
import 'package:track/util/format.dart';

/// Regression tests for the "opens, then goes blank after a few options" path.
///
/// These pin the concrete defects found in the navigation / onboarding / Insights
/// surfaces, not a hypothetical device run:
///
///  * an out-of-range tab index must not reach `IndexedStack`;
///  * onboarding must persist before it dismisses, and must not dismiss on a
///    failed write;
///  * an empty projection must not make Insights read `.last` of an empty list;
///  * a fresh install must not score blank days as consistency.
///
/// Run with: flutter test test/navigation_stability_test.dart
void main() {
  late TrackDatabase db;
  late EntryRepository repo;
  late AppState state;

  setUp(() async {
    db = TrackDatabase.forTesting(NativeDatabase.memory());
    repo = EntryRepository(db);
    state = AppState(repo: repo, commitmentRepo: CommitmentRepository(db));
    await state.load();
  });

  tearDown(() async => db.close());

  group('tab navigation cannot ask for a destination that does not exist', () {
    test('out-of-range indices are recorded and ignored', () {
      state.setTab(99);
      expect(state.tabIndex, 0);
      state.setTab(-1);
      expect(state.tabIndex, 0);
      expect(state.startupIssues.join(' '), contains('Navigation'));
    });

    test('valid indices still move', () {
      state.setTab(AppState.tabCount - 1);
      expect(state.tabIndex, AppState.tabCount - 1);
    });
  });

  group('onboarding completes atomically', () {
    test('the flag is persisted and the landing tab is applied together', () async {
      await state.completeOnboarding(landingTab: 3);

      expect(state.onboarded, isTrue);
      expect(state.tabIndex, 3);
      expect(await repo.dao.getSetting('onboarded'), '1');
    });

    test('a failed write leaves the overlay up instead of silently replaying later', () async {
      await db.close();

      await state.completeOnboarding(landingTab: 1);

      expect(state.onboarded, isFalse, reason: 'the overlay must not dismiss over an unsaved flag');
      expect(state.tabIndex, 0, reason: 'no jump to a destination the user has not reached');
      expect(state.writeFailure, isNotNull);
      expect(state.startupIssues.join(' '), contains('Onboarding'));
    });
  });

  group('the add-more catalogue creates real trackers', () {
    test('adding an entry makes it visible; removing hides it and keeps history', () {
      // Make room under the free ceiling without triggering a visibility write.
      state.byId('water').hidden = true;

      state.toggleAdded('reading');

      final added = state.trackerOrNull('reading');
      expect(added, isNotNull);
      expect(added!.hidden, isFalse);
      expect(state.visibleTrackers.any((t) => t.id == 'reading'), isTrue);
      expect(state.added, contains('reading'));

      state.toggleAdded('reading');

      expect(state.trackerOrNull('reading')!.hidden, isTrue);
      expect(state.added, isNot(contains('reading')));
    });
  });

  group('an empty projection degrades instead of throwing', () {
    test('loggedFlags is empty and loadedDays falls back to the design window', () {
      state.history.clear();

      expect(state.loggedFlags(7), isEmpty);
      expect(state.loadedDays, state.days);
    });

    test('the insights engine survives an empty catalogue', () {
      final insights = InsightsEngine.compute(history: const {}, trackers: const [], advanced: false);

      expect(insights, isNotEmpty);
      expect(insights.first.sampleDays, 0);
    });

    test('a fresh install scores zero consistency, not a budget-tracker free hit', () {
      final trackers = DefaultTrackers.all();
      final history = {for (final t in trackers) t.id: List<double>.filled(7, 0)};

      expect(activityScore(trackers, history, 6), 0);
    });
  });

  testWidgets('Insights renders an empty projection without a blank/error tab', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    // The crash was `loggedFlags(7).last` on an empty list. Clearing the
    // projection reproduces the shape without needing a corrupt database.
    state.history.clear();

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: const MaterialApp(home: Scaffold(body: InsightsScreen())),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('No days loaded yet.'), findsOneWidget);
  });
}
