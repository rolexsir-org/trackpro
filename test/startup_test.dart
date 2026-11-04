import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:track/data/commitment_repository.dart';
import 'package:track/data/db/database.dart';
import 'package:track/data/default_trackers.dart';
import 'package:track/data/entry_repository.dart';
import 'package:track/screens/home_shell.dart';
import 'package:track/screens/startup_gate.dart';
import 'package:track/state/app_startup.dart';
import 'package:track/state/app_state.dart';

/// Start-up regression tests: the ones the blank screen should have failed.
///
/// The defect they pin is architectural, so it is worth naming exactly. `main()` used to
/// await the notifications plugin, the database, the projection, the settings, the legacy
/// habit import, Focus Lock recovery and the reminder sync, and only then call `runApp`.
/// Nothing was rendered before the last of those finished, which means:
///
///  * an exception anywhere in the chain left the launcher's splash colour on screen for
///    ever, with no widget tree to show an error in and no way to try again;
///  * a platform call that never answered did the same, silently;
///  * and a load that "succeeded" without opening the database was indistinguishable from
///    one that worked, because nothing recorded whether it had.
///
/// `test/` is a text-and-logic suite here (see docs/TEST_RESULTS.md for what this host can
/// and cannot run), so every expectation below is about observable state: the phase, the
/// recorded issue, and which widget the gate builds. They fail on the old code by
/// construction — there was no phase to assert on and no gate to render.
///
///   flutter test test/startup_test.dart
void main() {
  TrackDatabase openDatabase() => TrackDatabase.forTesting(NativeDatabase.memory());

  AppState build(TrackDatabase db) => AppState(repo: EntryRepository(db), commitmentRepo: CommitmentRepository(db));

  Widget harness(AppState state, AppStartup startup) => ChangeNotifierProvider<AppState>.value(
    value: state,
    child: MaterialApp(home: StartupGate(startup: startup)),
  );

  group('the start-up sequence cannot present an app that did not load', () {
    test('an essential failure is recorded and the app is not marked ready', () async {
      final db = openDatabase();
      addTearDown(db.close);
      final state = build(db);
      var attempts = 0;
      final startup = AppStartup(
        state: state,
        essential: () async {
          attempts++;
          if (attempts == 1) throw StateError('unable to open database file');
          await state.load();
        },
      );

      await startup.start();

      expect(startup.phase, StartupPhase.failed, reason: 'a throw in the essential stage is fatal');
      expect(startup.failure?.detail, contains('unable to open database file'));
      expect(state.isLoaded, isFalse, reason: 'the interface is not built on an unopened database');
      expect(
        state.startupIssues.join(' '),
        contains('unable to open database file'),
        reason: 'the failure is recorded, not swallowed',
      );

      await startup.retry();

      expect(startup.phase, StartupPhase.ready, reason: 'a recoverable failure must be recoverable');
      expect(state.isLoaded, isTrue);
      expect(attempts, 2);
    });

    test('a stage that completes without loading the database is a failure, not a success', () async {
      final db = openDatabase();
      addTearDown(db.close);
      final state = build(db);
      final startup = AppStartup(state: state, essential: () async {});

      await startup.start();

      expect(startup.phase, StartupPhase.failed);
      expect(startup.failure?.detail, contains('did not load'));
      expect(state.isLoaded, isFalse);
    });

    test('a wedged essential stage times out into a retryable failure', () async {
      final db = openDatabase();
      addTearDown(db.close);
      final state = build(db);
      final wedged = Completer<void>();
      final startup = AppStartup(
        state: state,
        essential: () => wedged.future,
        essentialTimeout: const Duration(milliseconds: 25),
      );

      await startup.start();

      expect(startup.phase, StartupPhase.failed);
      expect(startup.failure?.detail, contains('did not finish within'));

      // Completing it afterwards must change nothing: the phase is decided.
      wedged.complete();
      await Future<void>.delayed(Duration.zero);
      expect(startup.phase, StartupPhase.failed);
    });

    test('starting twice runs the sequence once', () async {
      final db = openDatabase();
      addTearDown(db.close);
      final state = build(db);
      var calls = 0;
      final startup = AppStartup(
        state: state,
        essential: () async {
          calls++;
          await state.load();
        },
      );

      await Future.wait(<Future<void>>[startup.start(), startup.start()]);
      await startup.start();

      expect(calls, 1, reason: 'a second bootstrap would race the first');
      expect(startup.phase, StartupPhase.ready);
    });

    test('a background integration that fails costs the feature, not the launch', () async {
      final db = openDatabase();
      addTearDown(db.close);
      final state = build(db);
      final startup = AppStartup(
        state: state,
        essential: () async {
          await state.load();
        },
        background: () async {
          throw StateError('the billing store is not installed');
        },
      );

      await startup.start();
      await Future<void>.delayed(Duration.zero);

      expect(startup.phase, StartupPhase.ready);
      expect(state.startupIssues.join(' '), contains('the billing store is not installed'));
    });
  });

  group('loading the state', () {
    test('a fresh install has the catalogue and no invented history', () async {
      final db = openDatabase();
      addTearDown(db.close);
      final state = build(db);

      await state.load();

      expect(state.isLoaded, isTrue);
      expect(state.trackers.length, DefaultTrackers.all().length);
      expect(await state.repo.entryCount(), 0);
    });

    test('a second load joins the first instead of bootstrapping again', () async {
      final db = openDatabase();
      addTearDown(db.close);
      final state = build(db);

      await Future.wait(<Future<void>>[state.load(), state.load()]);
      await state.load();

      expect(state.isLoaded, isTrue);
      expect(
        state.trackers.length,
        DefaultTrackers.all().length,
        reason: 'the catalogue is written once, not once per load',
      );
    });

    test('an existing install keeps its records across a restart', () async {
      final db = openDatabase();
      addTearDown(db.close);

      final before = build(db);
      await before.load();
      await before.repo.setDaily('water', 750);

      // A second AppState over the same database is what a cold start looks like.
      final after = build(db);
      await after.load();

      expect(after.isLoaded, isTrue);
      expect(after.today('water'), 750);
      expect(await after.repo.entryCount(), greaterThan(0));
    });

    test('a database that cannot be read fails the load instead of half-loading', () async {
      final db = openDatabase();
      final state = build(db);
      await db.close();

      await expectLater(state.load(), throwsA(anything));

      expect(state.isLoaded, isFalse);
      expect(state.startupIssues, isEmpty, reason: 'the optional stages were never reached');
    });
  });

  group('the start-up gate renders a deliberate state from the first frame', () {
    testWidgets('the first frame is the start-up screen, never the dashboard', (tester) async {
      final db = openDatabase();
      final state = build(db);
      final wedged = Completer<void>();
      final startup = AppStartup(
        state: state,
        essential: () => wedged.future,
        essentialTimeout: const Duration(seconds: 1),
      );

      await tester.pumpWidget(harness(state, startup));
      await tester.pump();

      expect(find.text('Opening your data…'), findsOneWidget);
      expect(find.byType(HomeShell), findsNothing);

      wedged.complete();
      await tester.pump();
      await tester.pump();

      // The essential stage finished without loading anything, so it is a failure.
      expect(find.text('Try again'), findsOneWidget);
      expect(find.byType(HomeShell), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(db.close);
    });

    testWidgets('a failed start-up explains itself and recovers on retry', (tester) async {
      final db = openDatabase();
      final state = build(db);
      // The database itself is fine; the first attempt is made to fail on purpose. The
      // retry therefore resolves without I/O, which keeps this test about the gate.
      await tester.runAsync(state.load);
      var attempts = 0;
      final startup = AppStartup(
        state: state,
        essential: () async {
          attempts++;
          if (attempts == 1) throw StateError('unable to open database file');
          await state.load();
        },
      );

      await startup.start();
      await tester.pumpWidget(harness(state, startup));
      await tester.pump();

      expect(find.text('Your data could not be opened'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      expect(find.byType(HomeShell), findsNothing);

      await tester.tap(find.text('Try again'));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(attempts, 2, reason: 'the button is wired to the retry');
      expect(startup.phase, StartupPhase.ready);
      expect(find.byType(HomeShell), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(db.close);
    });

    testWidgets('once loaded, the real interface and first-launch onboarding render', (tester) async {
      // A phone-shaped surface: the first-launch onboarding is a full-screen layout, and
      // the default 800×600 test window is not the shape it is designed for.
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final db = openDatabase();
      final state = build(db);
      final startup = AppStartup(
        state: state,
        essential: () async {
          await state.load();
        },
      );

      await tester.runAsync(startup.start);
      await tester.pumpWidget(harness(state, startup));
      await tester.pump();

      expect(startup.phase, StartupPhase.ready);
      expect(find.byType(HomeShell), findsOneWidget);
      // The first thing a new install shows is the onboarding, not an empty dashboard.
      expect(find.text('Start with one thing.'), findsOneWidget);
      expect(state.onboarded, isFalse);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(db.close);
    });
  });
}
