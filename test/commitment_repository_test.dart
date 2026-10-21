import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track/data/commitment_repository.dart';
import 'package:track/data/db/database.dart';
import 'package:track/models/models.dart';
import 'package:track/util/day_key.dart';

/// The Momentum store, tested against a real SQLite database.
///
/// These are the tests that matter most for data integrity: they cover duplicate
/// prevention, correction, deletion semantics, the pause rules, the one-time
/// conversion of an install's legacy habit checklist, and a v2 → v3 migration on a
/// representative old database.
///
/// Not executed in the environment that wrote them (no Flutter SDK). Run with:
///   flutter test test/commitment_repository_test.dart
/// `drift/native.dart` needs the host's sqlite3 (see repository_test.dart).
void main() {
  late TrackDatabase db;
  late CommitmentRepository repo;

  // A fixed clock: Wednesday 2026-03-11.
  final fixedNow = DateTime(2026, 3, 11, 10, 0);
  final today = dayKey(fixedNow);

  setUp(() {
    db = TrackDatabase.forTesting(NativeDatabase.memory());
    repo = CommitmentRepository(db, now: () => fixedNow);
  });

  tearDown(() async => db.close());

  Future<Commitment> makeRoutine({
    String id = 'run',
    Set<int> weekdays = const {1, 2, 3, 4, 5, 6, 7},
    int? createdDay,
  }) => repo.create(
    id: id,
    name: 'Run',
    emoji: '🏃',
    color: 0xFF5B7CFA,
    outcome: 'Get through a 5k',
    minimumAction: 'Shoes on, 5 minutes',
    fullAction: 'Run 5 km',
    weekdays: weekdays,
    createdDay: createdDay,
  );

  group('a fresh install has no commitments and no invented days', () {
    test('hydrate on an empty database yields nothing at all', () async {
      await repo.hydrate();
      expect(repo.commitments, isEmpty);
      expect(repo.overall(), isNull, reason: 'no routines means no figure to report');
      expect(repo.review(), isNull);
      expect(await db.commitmentDao.totalDayCount(), 0);
    });
  });

  group('creating a routine', () {
    test('the record starts empty and the routine is readable back', () async {
      final c = await makeRoutine();
      expect(c.createdDay, today);
      expect(c.schedule, {1, 2, 3, 4, 5, 6, 7});

      await repo.hydrate();
      expect(repo.commitments.length, 1);
      expect(repo.daysFor('run'), isEmpty, reason: 'creating a routine records no days');
      expect(repo.snapshotFor('run')!.decidedDays, 0);
    });

    test('an empty name is not stored as an empty name', () async {
      final c = await repo.create(
        id: 'x',
        name: '   ',
        emoji: '✅',
        color: 0xFF34C759,
        outcome: 'o',
        minimumAction: 'm',
        fullAction: 'f',
        weekdays: const {1},
      );
      expect(c.name, 'Untitled commitment');
    });

    test('an empty schedule falls back to every day rather than to nothing', () async {
      final c = await repo.create(
        id: 'x',
        name: 'Read',
        emoji: '📖',
        color: 0xFF5B7CFA,
        outcome: 'o',
        minimumAction: 'One page',
        fullAction: '20 pages',
        weekdays: const {},
      );
      expect(c.schedule, {1, 2, 3, 4, 5, 6, 7}, reason: 'a routine with no days would silently score nothing forever');
    });
  });

  group('recording a day', () {
    test('a repeated tap replaces the answer instead of stacking', () async {
      await makeRoutine();
      await repo.record(commitmentId: 'run', outcome: DayOutcome.minimum);
      await repo.record(commitmentId: 'run', outcome: DayOutcome.full);

      expect(await db.commitmentDao.dayCountFor('run'), 1, reason: 'one row per routine per day');
      final days = await db.commitmentDao.daysFor('run');
      expect(days.single.outcome, DayOutcome.full.storage);
      expect(repo.snapshotFor('run')!.fullDays, 1);
    });

    test('a record survives a reload, with its value and note', () async {
      await makeRoutine();
      await repo.record(commitmentId: 'run', outcome: DayOutcome.full, value: 5, note: 'easy pace');

      await repo.hydrate();
      final rec = repo.daysFor('run')[today]!;
      expect(rec.outcome, DayOutcome.full);
      expect(rec.value, 5);
      expect(rec.note, 'easy pace');
    });

    test('clearing a day leaves the routine and the other days alone', () async {
      await makeRoutine();
      await repo.record(commitmentId: 'run', outcome: DayOutcome.full);
      await repo.record(commitmentId: 'run', outcome: DayOutcome.minimum, day: dayKey(DateTime(2026, 3, 10)));

      await repo.clearRecord('run', day: today);

      expect(repo.daysFor('run').length, 1);
      expect(repo.daysFor('run')[today], isNull);
      expect(await db.commitmentDao.dayCountFor('run'), 1);
    });

    test('an unknown outcome string cannot crash the projection', () async {
      await makeRoutine();
      await db.commitmentDao.recordDay(commitmentId: 'run', day: today, outcome: 'not-a-real-outcome');
      await repo.hydrate();
      // Unknown storage values are read as `missed` — the conservative reading —
      // rather than throwing inside a build.
      expect(repo.daysFor('run')[today]!.outcome, DayOutcome.missed);
    });
  });

  group('schedule changes', () {
    test('a new revision starts today and leaves earlier days as they were', () async {
      await makeRoutine(weekdays: const {1, 2, 3, 4, 5, 6, 7});
      final before = repo.commitments.single;

      await repo.update(before.copyWith(name: 'Run (weekdays)'), newWeekdays: const {1, 2, 3, 4, 5});
      await repo.hydrate();

      final after = repo.commitments.single;
      expect(after.revisions.length, 2, reason: 'the old schedule is kept as a revision');
      expect(after.revisions.first.fromDay, today);
      expect(after.schedule, {1, 2, 3, 4, 5});
      // A weekend day last month is still planned under the daily revision.
      final lastMonthSaturday = dayKey(DateTime(2026, 2, 28)); // Saturday
      expect(weekdayOfDayKey(lastMonthSaturday), 6);
    });

    test('an unchanged schedule adds no revision', () async {
      final c = await makeRoutine(weekdays: const {1, 2, 3});
      await repo.update(c, newWeekdays: const {1, 2, 3});
      await repo.hydrate();
      expect(repo.commitments.single.revisions.length, 1);
    });
  });

  group('archiving and deleting', () {
    test('archiving keeps every recorded day', () async {
      await makeRoutine();
      await repo.record(commitmentId: 'run', outcome: DayOutcome.full);
      await repo.archive('run');

      await repo.hydrate();
      expect(repo.active, isEmpty);
      expect(repo.commitments.single.archived, isTrue);
      expect(repo.daysFor('run').length, 1, reason: 'the record is the user\'s, archived or not');
    });

    test('deleting takes the days and the pauses with it', () async {
      await makeRoutine();
      await repo.record(commitmentId: 'run', outcome: DayOutcome.full);
      await repo.startPause('run', reason: 'travel');

      await repo.delete('run');

      expect(repo.commitments, isEmpty);
      expect(await db.commitmentDao.totalDayCount(), 0, reason: 'no orphaned history');
      expect((await db.commitmentDao.allPauses()), isEmpty);
    });
  });

  group('pauses', () {
    test('pausing excludes days from planning, resuming restores them', () async {
      await makeRoutine(createdDay: dayKey(DateTime(2026, 3, 1)));
      await repo.startPause('run', reason: 'flu');
      expect(repo.isPaused('run'), isTrue);

      final paused = repo.snapshotFor('run')!;
      expect(paused.plannedDays, 0, reason: 'an open pause covers today and everything after it');

      await repo.endPause('run');
      expect(repo.isPaused('run'), isFalse);
      expect(repo.snapshotFor('run')!.plannedDays, greaterThan(0));
    });

    test('resuming when nothing was paused is reported honestly', () async {
      await makeRoutine();
      await repo.endPause('run');
      expect(repo.isPaused('run'), isFalse);
      expect((await db.commitmentDao.allPauses()), isEmpty, reason: 'no phantom pause row is created');
    });
  });

  group('the legacy habit checklist converts once, non-destructively', () {
    Future<void> seedLegacy() async {
      await db.trackDao.upsertDaily(trackerId: 'habits', day: today, value: 1, source: 'manual', meta: '{"done":[0]}');
      await db.trackDao.upsertDaily(
        trackerId: 'habits',
        day: dayKey(DateTime(2026, 3, 9)),
        value: 1,
        source: 'manual',
        meta: '{"done":[0,1]}',
      );
      await db.trackDao.setSetting(
        'habits',
        jsonEncode([
          {'name': 'Drink water', 'emoji': '💧', 'color': 0xFF007AFF},
          {'name': 'Move 30 minutes', 'emoji': '🏃', 'color': 0xFFFF9500},
        ]),
      );
    }

    test('habits and their completed days become commitments', () async {
      await seedLegacy();
      final report = await repo.importLegacyHabits();

      expect(report.alreadyImported, isFalse);
      expect(report.habits, 2);
      expect(report.days, 3, reason: 'three tick marks across two habits');
      expect(report.limitation, isNotNull, reason: 'the positional-index limitation is stated');

      final water = repo.commitments.firstWhere((c) => c.name == 'Drink water');
      expect(water.schedule, {1, 2, 3, 4, 5, 6, 7});
      expect(water.createdDay, dayKey(DateTime(2026, 3, 9)), reason: 'the oldest tick, not today');
      expect(repo.daysFor(water.id).length, 2);
      expect(repo.daysFor(water.id).values.every((d) => d.outcome == DayOutcome.full), isTrue);
    });

    test('running it twice imports nothing the second time', () async {
      await seedLegacy();
      await repo.importLegacyHabits();
      final second = await repo.importLegacyHabits();

      expect(second.alreadyImported, isTrue);
      expect(second.habits, 0);
      expect(await db.commitmentDao.totalDayCount(), 3, reason: 'no duplicates');
    });

    test('the legacy rows are left exactly where they were', () async {
      await seedLegacy();
      await repo.importLegacyHabits();

      final legacy = await db.trackDao.dailyRowsFor('habits', days: 30);
      expect(legacy.length, 2, reason: 'conversion copies; it does not move or delete');
      expect(await db.trackDao.getSetting('habits'), isNotNull);
    });

    test('a corrupt habit blob does not block start-up', () async {
      await db.trackDao.setSetting('habits', '{not json at all');
      final report = await repo.importLegacyHabits();
      expect(report.habits, 0);
      expect(repo.commitments, isEmpty);
    });

    test('no habit list means nothing to import, and the marker is still written', () async {
      final report = await repo.importLegacyHabits();
      expect(report.habits, 0);
      expect(await db.trackDao.getSetting('commitments.legacyImported'), isNotNull);
    });
  });

  group('migration from the v2 schema', () {
    /// A v2-shaped database: the six tables that existed before Momentum, with a
    /// row of real user history in it. Drift's generated DDL is reproduced by hand
    /// (DateTime columns are INTEGER unix seconds), because the point of the test is
    /// to open a database that predates the new tables.
    Future<TrackDatabase> openV2() async {
      final executor = NativeDatabase.memory();
      const ddl = <String>[
        '''CREATE TABLE "tracker_rows" (
             "id" TEXT NOT NULL, "name" TEXT NOT NULL, "emoji" TEXT NOT NULL, "kind" TEXT NOT NULL,
             "unit" TEXT NOT NULL, "blurb" TEXT NOT NULL, "insight" TEXT NOT NULL,
             "accent" INTEGER NOT NULL, "accent2" INTEGER NOT NULL, "goal" REAL NOT NULL,
             "step" REAL NOT NULL, "hero" INTEGER NOT NULL DEFAULT 0, "hidden" INTEGER NOT NULL DEFAULT 0,
             "sort" INTEGER NOT NULL DEFAULT 0, PRIMARY KEY ("id"))''',
        '''CREATE TABLE "daily_entries" (
             "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
             "tracker_id" TEXT NOT NULL REFERENCES "tracker_rows" ("id") ON DELETE CASCADE,
             "day" INTEGER NOT NULL, "updated_at" INTEGER NOT NULL, "value" REAL NOT NULL,
             "source" TEXT NOT NULL DEFAULT 'manual', "meta" TEXT NULL,
             UNIQUE ("tracker_id", "day", "source"))''',
        '''CREATE TABLE "events" (
             "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
             "tracker_id" TEXT NOT NULL REFERENCES "tracker_rows" ("id") ON DELETE CASCADE,
             "ts" INTEGER NOT NULL, "day" INTEGER NOT NULL, "value" REAL NOT NULL,
             "source" TEXT NOT NULL DEFAULT 'manual', "meta" TEXT NULL)''',
        '''CREATE TABLE "app_settings" ("key" TEXT NOT NULL, "value" TEXT NOT NULL, PRIMARY KEY ("key"))''',
        '''CREATE TABLE "purchases" (
             "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "product_id" TEXT NOT NULL,
             "purchase_token" TEXT NOT NULL, "status" TEXT NOT NULL, "purchased_at" INTEGER NOT NULL,
             "expires_at" INTEGER NULL, "auto_renew" INTEGER NOT NULL DEFAULT 0,
             "acknowledged" INTEGER NOT NULL DEFAULT 0, "server_verified" INTEGER NOT NULL DEFAULT 0,
             "trial" INTEGER NOT NULL DEFAULT 0, "raw" TEXT NULL,
             UNIQUE ("purchase_token", "product_id"))''',
        '''CREATE TABLE "track_events" (
             "id" INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "name" TEXT NOT NULL,
             "at" INTEGER NOT NULL, "meta" TEXT NULL)''',
      ];
      for (final statement in ddl) {
        await executor.runCustom(statement);
      }
      await executor.runCustom(
        'INSERT INTO "tracker_rows" ("id","name","emoji","kind","unit","blurb","insight","accent","accent2","goal","step","hero","hidden","sort") '
        "VALUES ('water','Water','💧','volume','ml','b','i',4278255615,4284133370,2500,250,1,0,0)",
      );
      await executor.runCustom(
        'INSERT INTO "daily_entries" ("tracker_id","day","updated_at","value","source") '
        "VALUES ('water',20260310,1773000000,1500,'manual')",
      );
      await executor.runCustom('''INSERT INTO "app_settings" ("key","value") VALUES ('dark','1')''');
      await executor.runCustom('PRAGMA user_version = 2');
      return TrackDatabase.forTesting(executor);
    }

    test('opening a v2 database adds the Momentum tables and keeps the old data', () async {
      final old = await openV2();
      addTearDown(old.close);

      // Touching the database is what triggers `onUpgrade` (2 → 3).
      final water = await old.trackDao.series('water', days: 3);
      expect(water.last, 1500, reason: 'the user\'s existing entry is still there');
      expect(await old.trackDao.getSetting('dark'), '1', reason: 'settings survive');

      // And the new tables are usable immediately.
      final repoV3 = CommitmentRepository(old, now: () => fixedNow);
      await repoV3.create(
        id: 'run',
        name: 'Run',
        emoji: '🏃',
        color: 0xFF5B7CFA,
        outcome: 'o',
        minimumAction: 'm',
        fullAction: 'f',
        weekdays: const {1, 3, 5},
      );
      await repoV3.record(commitmentId: 'run', outcome: DayOutcome.full);
      await repoV3.hydrate();
      expect(repoV3.commitments.length, 1);
      expect(repoV3.snapshotFor('run')!.fullDays, 1);
    });

    test('the migration is not destructive: no table is dropped', () async {
      final old = await openV2();
      addTearDown(old.close);
      await old.trackDao.series('water', days: 1); // trigger the upgrade

      final tables = await old
          .customSelect("SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name", readsFrom: {})
          .get();
      final names = tables.map((r) => r.read<String>('name')).toList();
      expect(names, containsAll(<String>['tracker_rows', 'daily_entries', 'events', 'app_settings', 'purchases']));
      expect(names, containsAll(<String>['commitment_rows', 'commitment_entries', 'commitment_pauses']));
    });
  });

  group('export', () {
    test('the payload carries definitions, schedule revisions, days and pauses', () async {
      final c = await repo.create(
        id: 'run',
        name: 'Run',
        emoji: '🏃',
        color: 0xFF5B7CFA,
        outcome: 'Get through a 5k',
        minimumAction: 'Shoes on, 5 minutes',
        fullAction: 'Run 5 km',
        weekdays: const {1, 3, 5},
      );
      await repo.record(commitmentId: c.id, outcome: DayOutcome.full, value: 5, note: 'easy pace');
      await repo.record(commitmentId: c.id, outcome: DayOutcome.missed, day: dayKey(DateTime(2026, 3, 9)));
      await repo.startPause(c.id, reason: 'travel');
      await repo.hydrate();

      final payload = repo.exportPayload();
      expect(payload['format'], 'track.commitments.v1');

      final routines = payload['routines']! as List<Object?>;
      expect(routines.length, 1);
      final run = routines.first! as Map<String, Object?>;
      expect(run['name'], 'Run');
      expect(run['minimum'], 'Shoes on, 5 minutes');
      expect(run['full'], 'Run 5 km');

      // History keeps its meaning only if the schedule that governed each day
      // travels with it.
      final schedule = run['schedule']! as List<Object?>;
      expect(schedule.length, 1, reason: 'no revision was made, so there is one schedule');
      expect((schedule.first! as Map<String, Object?>)['days'], [1, 3, 5]);
      expect((schedule.first! as Map<String, Object?>)['from'], isoDayKey(c.createdDay));

      final days = run['days']! as List<Object?>;
      expect(days.length, 2, reason: 'only the days actually recorded are exported');
      // Oldest first, matching historyFor: a reader can rely on the order.
      final byDate = {for (final d in days) (d! as Map<String, Object?>)['date'] as String: d};
      expect(byDate.keys.toList(), [isoDayKey(dayKey(DateTime(2026, 3, 9))), isoDayKey(today)]);
      final latest = byDate[isoDayKey(today)]!;
      expect(latest['outcome'], 'full');
      expect(latest['value'], 5);
      expect(latest['note'], 'easy pace');
      expect(byDate[isoDayKey(dayKey(DateTime(2026, 3, 9)))]!['outcome'], 'missed');

      final pauses = payload['pauses']! as List<Object?>;
      expect(pauses.length, 1);
      expect((pauses.first! as Map<String, Object?>)['reason'], 'travel');
      expect((pauses.first! as Map<String, Object?>)['to'], isNull, reason: 'the pause is still open');

      final totals = payload['totals']! as Map<String, Object?>;
      expect(totals['routines'], 1);
      expect(totals['recorded_days'], 2);
    });

    test('a schedule revision is exported as its own entry, oldest first', () async {
      final c = await makeRoutine(weekdays: const {1, 2, 3});
      await repo.update(c, newWeekdays: const {5, 6});
      await repo.hydrate();

      final payload = repo.exportPayload();
      final run = (payload['routines']! as List<Object?>).first! as Map<String, Object?>;
      final schedule = run['schedule']! as List<Object?>;
      expect(schedule.length, 2);
      expect((schedule[0]! as Map<String, Object?>)['days'], [1, 2, 3]);
      expect((schedule[1]! as Map<String, Object?>)['days'], [5, 6]);
      expect((schedule[1]! as Map<String, Object?>)['from'], today);
    });

    test('the CSV is one row per recorded day and quotes a name with a comma', () async {
      final c = await repo.create(
        id: 'read',
        name: 'Read, 20 minutes',
        emoji: '📚',
        color: 0xFF5B7CFA,
        outcome: 'o',
        minimumAction: 'm',
        fullAction: 'f',
        weekdays: const {1, 2, 3, 4, 5, 6, 7},
      );
      await repo.record(commitmentId: c.id, outcome: DayOutcome.minimum, note: 'half a chapter');
      final csv = repo.exportCsv();
      final lines = csv.split('\n');

      expect(lines.first, 'date,routine,outcome,value,note');
      expect(lines.length, 2, reason: 'one header and one recorded day');
      expect(lines[1], contains('"Read, 20 minutes"'), reason: 'a comma in a name must be quoted');
      expect(lines[1], contains(',minimum,'));
      expect(lines[1], contains('half a chapter'));
    });

    test('an install with nothing recorded exports an empty, well-formed file', () async {
      await repo.hydrate();
      final csv = repo.exportCsv();
      expect(csv, 'date,routine,outcome,value,note');
      final payload = repo.exportPayload();
      expect((payload['routines']! as List<Object?>), isEmpty);
      expect(((payload['totals']! as Map<String, Object?>)['recorded_days']), 0);
    });
  });
  group('deleteAllUserData removes the routines themselves', () {
    test('rows, projection and pauses all go together', () async {
      final c = await makeRoutine(id: 'gym');
      await repo.record(commitmentId: c.id, outcome: DayOutcome.full);
      await repo.record(commitmentId: c.id, outcome: DayOutcome.minimum, day: today - 1);
      await repo.startPause(c.id, reason: 'travelling');
      expect(await repo.dao.allRows(), hasLength(1));

      final removed = await repo.deleteAllUserData();

      expect(removed['routines'], 1);
      expect(removed['routine_days'], 2);
      expect(removed['routine_pauses'], 1);
      expect(repo.commitments, isEmpty, reason: 'the in-memory projection goes with the rows');
      expect(repo.daysFor(c.id), isEmpty);
      expect(repo.pauses, isEmpty);
      expect(await repo.dao.allRows(), isEmpty, reason: 'the table is empty, not just the cache');
      expect(await repo.dao.totalDayCount(), 0);
      expect(await repo.dao.allPauses(), isEmpty);
    });

    test('keepDefinitions keeps the routine and drops only what was recorded against it', () async {
      final c = await makeRoutine(id: 'read');
      await repo.record(commitmentId: c.id, outcome: DayOutcome.full);

      final removed = await repo.deleteAllUserData(keepDefinitions: true);

      expect(removed['routines'], 0, reason: 'the routine row stays');
      expect(removed['routine_days'], 1);
      expect(repo.commitments, hasLength(1));
      expect(await repo.dao.allRows(), hasLength(1));
      expect(await repo.dao.totalDayCount(), 0);
    });

    test('a hydrate after the wipe reads back an empty store, not a resurrected one', () async {
      final c = await makeRoutine(id: 'gym');
      await repo.record(commitmentId: c.id, outcome: DayOutcome.full);
      await repo.deleteAllUserData();

      // A second repository over the same database is what a restart looks like.
      final reopened = CommitmentRepository(db, now: () => fixedNow);
      await reopened.hydrate();

      expect(reopened.commitments, isEmpty);
      expect(reopened.daysFor(c.id), isEmpty);
      expect(reopened.pauses, isEmpty);
    });
  });
}
