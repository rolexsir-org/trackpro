import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track/data/db/database.dart';
import 'package:track/data/entry_repository.dart';
import 'package:track/data/value_validation.dart';

/// Storage-layer tests, driven through the real repository against a real
/// in-memory SQLite database.
///
/// This file replaces a suite that asserted the *demo-seeding* behaviour the app
/// no longer has ("first launch seeds 28 days of history", "reset wipes and
/// reseeds"). Those assertions were true of the old implementation and are the
/// bug this work removes, so they are inverted here rather than deleted: a fresh
/// install must have **no fabricated rows**, and a reset must not recreate them.
///
/// Not executed in the environment that wrote them (no Flutter SDK). Run with:
///   flutter test test/repository_test.dart
///
/// `drift/native.dart` opens the host's sqlite3. On macOS/Windows that is
/// bundled; on Linux `apt-get install libsqlite3-0`.
void main() {
  late TrackDatabase db;
  late EntryRepository repo;

  setUp(() async {
    db = TrackDatabase.forTesting(NativeDatabase.memory());
    repo = EntryRepository(db);
  });

  tearDown(() async => db.close());

  group('a fresh install contains definitions and nothing else', () {
    test('bootstrap creates trackers without inventing history', () async {
      final report = await repo.bootstrap();

      expect(report.createdTrackers, isTrue, reason: 'the catalogue is written once');
      expect(report.entryCount, 0, reason: 'a brand new user has logged nothing');
      expect(report.isFreshInstall, isTrue);
      expect(report.integrityOk, isTrue);
    });

    test('every tracker series is empty, not pre-filled', () async {
      await repo.bootstrap();
      final trackers = await repo.dao.allTrackers();
      expect(trackers, isNotEmpty, reason: 'sensible defaults ship with the app');

      for (final t in trackers) {
        final series = await repo.dao.series(t.id, days: 28);
        expect(series.length, 28, reason: '${t.id} is gap-filled to the window');
        expect(series.every((v) => v == 0), isTrue,
            reason: '${t.id} must not carry invented history');
      }
    });

    test('a second bootstrap is a no-op', () async {
      await repo.bootstrap();
      final second = await repo.bootstrap();
      expect(second.createdTrackers, isFalse);
      expect(second.entryCount, 0);
    });

    test('has no demo-sourced rows and no counted days', () async {
      await repo.bootstrap();
      expect(await repo.demoRowCount(), 0);
      expect(await repo.entryCount(), 0);
      expect(await repo.trackedDays(), 0);
      expect(await repo.sourceCounts(), isEmpty);
      expect(await repo.firstLoggedDate(), isNull,
          reason: '"tracking since" must be unknown, not today');
    });

    test('exports carry the format header only', () async {
      await repo.bootstrap();
      final csv = await repo.exportCsv();
      final lines = csv.trim().split('\n');
      expect(lines.first.split(',').first, 'date');
      expect(lines.length, 1, reason: 'no days to export yet');

      final json = await repo.exportJson();
      expect(json, contains('"events": []'), reason: 'the event log is genuinely empty');
    });
  });

  group('bootstrap is the only start-up path, and it creates no history', () {
    test('real data survives a re-bootstrap untouched', () async {
      await repo.bootstrap();
      await repo.setDaily('water', 1500);

      final report = await repo.bootstrap();

      expect(report.createdTrackers, isFalse, reason: 'the catalogue already exists');
      expect(report.entryCount, greaterThan(0));
      expect((await repo.dao.series('water', days: 1)).last, 1500,
          reason: 'the user value is untouched');
      expect(await repo.demoRowCount(), 0);
    });

    test('a demo-sourced fixture stays removable and never counts as user data', () async {
      await repo.bootstrap();
      // Fixtures can only enter a database by being written to it directly, from a
      // test. This is what an upgraded install from an old dev build looks like.
      await repo.dao.replaceSeries('water', {dayKey(DateTime.now()): 250}, source: 'demo');

      expect(await repo.demoRowCount(), 1);

      final removed = await repo.deleteDemoRows();
      expect(removed, 1);
      expect(await repo.demoRowCount(), 0);
      expect((await repo.dao.series('water', days: 1)).last, 0,
          reason: 'removing sample data leaves a genuine empty state');
    });
  });

  group('writes', () {
    setUp(() async => repo.bootstrap());

    test('a logged day is stored once and updated in place', () async {
      expect(await repo.setDaily('sleep', 7.5), isTrue);
      expect(await repo.setDaily('sleep', 8.25), isTrue);

      expect((await repo.dao.series('sleep', days: 1)).last, 8.25);
      final rows = (await repo.dao.exportDaily()).where((r) => r.trackerId == 'sleep');
      expect(rows.length, 1, reason: 'the unique key (tracker, day, source) held');
      expect(rows.first.source, 'manual');
    });

    test('an event and its rollup are written together', () async {
      await repo.setDaily('water', 250);
      expect(await repo.addEvent('water', 250, 500, meta: '{"serving":"cup"}'), isTrue);

      expect((await repo.dao.series('water', days: 1)).last, 500);
      final events = await repo.dao.recentEvents('water');
      expect(events.length, greaterThanOrEqualTo(1));
      expect(events.first.value, 250, reason: 'the event stores the delta, not the total');
      expect(events.first.meta, contains('cup'));
      expect(events.first.day, dayKey(DateTime.now()));
    });

    test('survives a reload: what the user typed is what comes back', () async {
      await repo.setDaily('expenses', 1240,
          meta: '{"category":"Groceries","title":"Vegetables"}');
      await repo.hydrate();

      expect((await repo.dao.series('expenses', days: 1)).last, 1240);
      final totals = await repo.categoryTotals(days: 1);
      expect(totals.single.name, 'Groceries');
      expect(totals.single.amount, 1240);
      expect((await repo.recentTransactions(limit: 1)).single.title, 'Vegetables');
    });
  });

  group('impossible values are refused at the storage boundary', () {
    setUp(() async => repo.bootstrap());

    test('negative, non-finite and out-of-bounds writes write nothing', () async {
      expect(await repo.setDaily('water', -250), isFalse);
      expect(await repo.setDaily('sleep', double.nan), isFalse);
      expect(await repo.setDaily('steps', double.infinity), isFalse);
      expect(await repo.setDaily('mood', 99), isFalse);

      expect(await repo.entryCount(), 0, reason: 'a rejected write is not a write');
      expect((await repo.dao.series('water', days: 1)).last, 0);
    });

    test('a plausible-but-huge value is clamped, not silently kept', () async {
      // 10 L of water is a typo for "a lot", not a reason to lose the entry.
      final stored = await repo.setDaily('water', 10000);
      expect(stored, isTrue);
      expect((await repo.dao.series('water', days: 1)).last,
          ValueValidation.boundsFor('water').$2);
    });

    test('a broken wearable reading never reaches the database', () async {
      final written = await repo.mergeHealthSeries('steps', {
        dayKey(DateTime.now()): double.nan,
        dayKey(DateTime.now().subtract(const Duration(days: 1))): -500,
      });
      expect(written, 0);
      expect(await repo.entryCount(), 0);
    });

    test('the validation table itself is sane', () {
      expect(ValueValidation.sanitize('mood', 3), 3);
      expect(ValueValidation.sanitize('mood', 6), 5);
      expect(ValueValidation.sanitize('water', -1), isNull);
      expect(ValueValidation.sanitize('unknown_tracker', 5), 5);
      expect(ValueValidation.wasClamped('steps', 999999), isTrue);
      expect(ValueValidation.wasClamped('steps', 8000), isFalse);
    });
  });

  group('source precedence', () {
    setUp(() async => repo.bootstrap());

    test('a health reading never overwrites a manual entry', () async {
      final today = dayKey(DateTime.now());
      final yesterday = dayKey(DateTime.now().subtract(const Duration(days: 1)));

      await repo.setDaily('steps', 12345, source: 'manual');
      final written = await repo.mergeHealthSeries('steps', {today: 9999, yesterday: 8000});

      expect(written, 1, reason: 'only the untouched day is written');
      expect((await repo.dao.series('steps', days: 1)).last, 12345, reason: 'manual wins');
      expect((await repo.dao.series('steps', days: 2)).first, 8000);
    });

    test('a manual entry can overwrite a health entry', () async {
      final today = dayKey(DateTime.now());
      await repo.mergeHealthSeries('steps', {today: 8000});
      await repo.setDaily('steps', 9000, source: 'manual');
      expect((await repo.dao.series('steps', days: 1)).last, 9000);
    });

    test('a re-run of the same sync does not double-count', () async {
      final today = dayKey(DateTime.now());
      await repo.mergeHealthSeries('steps', {today: 8000});
      await repo.mergeHealthSeries('steps', {today: 8000});
      expect((await repo.dao.series('steps', days: 1)).last, 8000);
      expect(await repo.entryCount(), 1);
    });

    test('provenance is queryable, so a wrong number can be traced', () async {
      final today = dayKey(DateTime.now());
      await repo.setDaily('mood', 4, source: 'manual');
      await repo.mergeHealthSeries('steps', {today: 8000});
      await repo.dao.replaceSeries('water', {today: 1750}, source: 'demo');

      final counts = {for (final c in await repo.sourceCounts()) c.source: c.count};
      expect(counts['manual'], 1);
      expect(counts['health'], 1);
      expect(counts['demo'], 1);
    });
  });

  group('deletion does exactly what it says', () {
    setUp(() async => repo.bootstrap());

    test('deleteAllUserData removes entries and keeps the definitions', () async {
      await repo.setDaily('water', 2000);
      await repo.setDaily('mood', 4);
      await repo.dao.replaceSeries('water', {dayKey(DateTime.now()) - 1: 999}, source: 'demo');

      final removed = await repo.deleteAllUserData();
      expect(removed.values.fold<int>(0, (a, b) => a + b), greaterThan(0));

      expect(await repo.entryCount(), 0);
      expect(await repo.demoRowCount(), 0);
      expect((await repo.dao.allTrackers()).length, greaterThanOrEqualTo(3),
          reason: 'the app is still usable: the trackers are still there');
      expect((await repo.dao.series('water', days: 1)).last, 0,
          reason: 'a delete must not resurrect synthetic history');
    });

    test('deleteDemoRows removes only demo rows', () async {
      final today = dayKey(DateTime.now());
      await repo.dao.replaceSeries('water', {today: 1750}, source: 'demo');
      await repo.setDaily('mood', 4);

      expect(await repo.deleteDemoRows(), 1);
      expect((await repo.dao.series('mood', days: 1)).last, 4);
      expect((await repo.dao.series('water', days: 1)).last, 0);
    });
  });

  group('integrity', () {
    setUp(() async => repo.bootstrap());

    test('the database passes its own integrity check after a normal session', () async {
      await repo.setDaily('water', 1500);
      await repo.addEvent('expenses', 250, 250, meta: '{"category":"Food","title":"Lunch"}');
      await repo.mergeHealthSeries('steps', {dayKey(DateTime.now()): 5000});

      expect(await repo.dao.integrityCheck(), 'ok');
      expect(await repo.dao.foreignKeyViolationCount(), 0);
      expect(await repo.isHealthy(), isTrue);
    });

    test('the projection and SQL agree about the same day', () async {
      await repo.setDaily('water', 1750);
      expect(repo.cache['water']!.last, (await repo.dao.series('water', days: 1)).last,
          reason: 'the in-memory chart and the database must never disagree');
    });

    test('day keys are local-calendar keys, not UTC instants', () async {
      // The whole app keys days as y*10000+m*100+d in local time. A UTC-derived
      // key would put a 23:30 IST entry on the previous day.
      final late = DateTime(2026, 3, 1, 23, 30);
      expect(dayKey(late), 20260301);
      final early = DateTime(2026, 3, 1, 0, 15);
      expect(dayKey(early), 20260301);
      expect(dayKey(DateTime(2026, 12, 31)), 20261231);
    });

    test('a DST transition does not shift a day key', () async {
      // India has no DST, but the app ships worldwide: 02:30 on a spring-forward
      // night must still be that calendar day.
      final dstNight = DateTime(2026, 3, 29, 2, 30);
      expect(dayKey(dstNight), 20260329);
      final nextDay = DateTime(2026, 3, 29).add(const Duration(days: 1));
      expect(dayKey(nextDay), 20260330);
    });
  });
}
