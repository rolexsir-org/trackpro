import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track/data/default_trackers.dart';
import 'package:track/data/db/database.dart';
import 'package:track/data/entry_repository.dart';

/// The demo-data policy, written as tests — and as a source audit.
///
/// The defect this exists to prevent: an earlier build shipped
/// `bootstrap(seedDemoIfEmpty: true)`, which wrote 28 days of synthetic history
/// into every fresh production database. Users saw a full dashboard of data they
/// had never entered, charts that meant nothing, and a "streak" that was not
/// theirs. It was also indistinguishable from real data in exports.
///
/// The policy is now structural rather than procedural, and each clause below
/// tests a different part of the structure:
///
///   1. **The production start-up path cannot seed.** `EntryRepository.bootstrap()`
///      takes no seeder, and `BootstrapReport` no longer has a `seededDemo` field,
///      so there is nothing to inject and nothing to forget.
///   2. **No file in `lib/` writes synthetic rows or imports fixtures.** Asserted by
///      scanning the shipped sources.
///   3. **Fixtures live under `test/` and only there.** `lib/` cannot import them,
///      so the compiler — not a reviewer — keeps them out of a release binary.
///   4. **If synthetic rows ever exist (an install upgraded from a dev build),
///      they are labelled, visible and removable** without touching user data.
///   5. **Production defaults contain no invented statistics.**
///
/// Not executed in the environment that wrote this (no Flutter SDK). Run with:
///   flutter test test/demo_policy_test.dart
void main() {
  late TrackDatabase db;
  late EntryRepository repo;

  setUp(() async {
    db = TrackDatabase.forTesting(NativeDatabase.memory());
    repo = EntryRepository(db);
  });

  tearDown(() async => db.close());

  group('clause 1 — the production start-up path cannot seed', () {
    test('bootstrap() takes no seeder and reports no seeding', () async {
      final report = await repo.bootstrap();

      expect(report.createdTrackers, isTrue, reason: 'the catalogue is written once');
      expect(report.entryCount, 0, reason: 'a brand new user has logged nothing');
      expect(report.trackerCount, greaterThan(0), reason: 'definitions do ship');
      expect(report.isFreshInstall, isTrue);
      expect(report.integrityOk, isTrue);
    });

    test('a fresh database holds no rows from any source', () async {
      await repo.bootstrap();

      expect(await repo.entryCount(), 0);
      expect(await repo.trackedDays(), 0);
      expect(await repo.demoRowCount(), 0);
      expect(await repo.sourceCounts(), isEmpty, reason: 'not one row exists, from any provenance');
      expect(await repo.firstLoggedDate(), isNull, reason: '"tracking since" must be unknown, not today');
    });

    test('every series is empty and gap-filled, never pre-populated', () async {
      await repo.bootstrap();
      for (final t in await repo.dao.allTrackers()) {
        final series = await repo.dao.series(t.id, days: 28);
        expect(series.length, 28, reason: '${t.id} is gap-filled to the window');
        expect(series.every((v) => v == 0), isTrue, reason: '${t.id} must not carry invented history');
      }
    });
  });

  group('clause 2 — no shipped source writes synthetic rows', () {
    /// Every `.dart` file that ships in the app binary.
    List<File> libSources() {
      final root = Directory('lib');
      expect(root.existsSync(), isTrue, reason: 'these tests must run from the package root (flutter test does)');
      return root.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart')).toList();
    }

    test('lib/ never names a demo seeder or writes a demo-sourced row', () {
      // The one legitimate mention is the provenance doc-comment in database.dart,
      // which explains what the legacy label means. A *code* hit is a defect.
      final offenders = <String>[];
      for (final file in libSources()) {
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          final code = line.contains('//') ? line.substring(0, line.indexOf('//')) : line;
          if (code.contains("'demo'") || code.contains('"demo"')) {
            offenders.add('${file.path}:${i + 1}: writes a demo-sourced row');
          }
          for (final needle in ['DemoSeed', 'seedDemo', 'demoSeed', 'wipeAndReseed', 'DemoFixtures']) {
            if (code.contains(needle)) {
              offenders.add('${file.path}:${i + 1}: references $needle');
            }
          }
        }
      }
      expect(offenders, isEmpty, reason: 'synthetic-data machinery must not exist in lib/:\n${offenders.join('\n')}');
    });

    test('lib/ does not import test fixtures, and fixtures are not in lib/', () {
      final offenders = <String>[];
      for (final file in libSources()) {
        final source = file.readAsStringSync();
        if (source.contains('test/fixtures') || source.contains('package:track/../test/')) {
          offenders.add(file.path);
        }
      }
      expect(offenders, isEmpty);
      expect(
        File('test/fixtures/demo_fixtures.dart').existsSync(),
        isTrue,
        reason: 'the fixture must exist where tests can reach it',
      );
    });

    test('there is no demo-seed switch left to misconfigure', () {
      final env = File('lib/config/app_environment.dart').readAsStringSync();
      expect(env.contains('TRACK_DEMO_SEED'), isFalse, reason: 'a build-time seeding switch is the bug, not the fix');
      expect(env.contains('demoSeedEnabled'), isFalse);
    });
  });

  group('clause 3 — fixtures are reachable only from tests', () {
    test('the fixture file declares itself test-only', () {
      final fixture = File('test/fixtures/demo_fixtures.dart').readAsStringSync();
      expect(fixture, contains('tests and development previews only'));
      expect(
        fixture,
        isNot(contains('package:track/../lib/data/demo_seed.dart')),
        reason: 'the deleted seeder must not be referenced by anything',
      );
    });
  });

  group('clause 4 — synthetic rows are labelled, visible and removable', () {
    test('a demo row is reported as "not yours" and can be deleted alone', () async {
      await repo.bootstrap();
      // The only way left to produce a demo row: a test writing one directly.
      await repo.dao.replaceSeries('water', {dayKey(DateTime.now()): 1750}, source: 'demo');
      await repo.setDaily('mood', 4, source: 'manual');

      expect(await repo.demoRowCount(), 1);

      final counts = {for (final c in await repo.sourceCounts()) c.source: c};
      expect(counts['demo']!.count, 1);
      expect(counts['demo']!.label, 'Sample data (not yours)', reason: 'Diagnostics must say it in plain words');
      expect(counts['manual']!.count, 1);

      final removed = await repo.deleteDemoRows();
      expect(removed, 1);
      expect(await repo.demoRowCount(), 0);
      expect((await repo.dao.series('mood', days: 1)).last, 4, reason: 'removing sample data must not remove the user');
    });

    test('a full delete does not recreate anything', () async {
      await repo.bootstrap();
      await repo.setDaily('water', 2000, source: 'demo');

      await repo.deleteAllUserData();

      expect(await repo.entryCount(), 0);
      expect(await repo.demoRowCount(), 0, reason: 'no synthetic history is written back');
      expect(await repo.sourceCounts(), isEmpty);
    });
  });

  group('clause 5 — production defaults contain no invented statistics', () {
    test('tracker definitions carry no statistic-shaped copy', () {
      final numericClaim = RegExp(r'\d+\s*%|\d+\s*(min|minutes|kg|L|cups|hours)\b');
      for (final tracker in DefaultTrackers.all()) {
        expect(
          numericClaim.hasMatch(tracker.insight),
          isFalse,
          reason: 'the "${tracker.id}" insight claims a statistic: "${tracker.insight}"',
        );
        expect(
          numericClaim.hasMatch(tracker.blurb),
          isFalse,
          reason: 'the "${tracker.id}" blurb claims a statistic: "${tracker.blurb}"',
        );
      }
      for (final extra in DefaultTrackers.addable) {
        expect(
          numericClaim.hasMatch(extra.blurb),
          isFalse,
          reason: 'the "${extra.id}" catalogue blurb claims a statistic',
        );
      }
    });

    test('the default catalogue is a usable free tier, not a teaser', () {
      final all = DefaultTrackers.all();
      expect(
        all.length,
        greaterThanOrEqualTo(6),
        reason: 'a new user must have something real to track without paying',
      );
      expect(all.map((t) => t.id), containsAll(['water', 'mood', 'expenses', 'sleep']));
      expect(
        all.map((t) => t.id),
        contains('habits'),
        reason: 'the habit loop is the retention engine and must be free',
      );
    });

    test('starter habits are known only by name, with no invented streaks', () {
      final habits = DefaultTrackers.starterHabits();
      expect(habits, isNotEmpty);
      for (final habit in habits) {
        expect(habit.name.trim(), isNotEmpty);
        expect(habit.streak, 0, reason: 'a brand new habit has no streak');
        expect(habit.done, isFalse);
      }
    });
  });
}
