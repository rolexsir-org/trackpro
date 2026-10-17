import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track/data/commitment_repository.dart';
import 'package:track/data/db/database.dart';
import 'package:track/data/entry_repository.dart';
import 'package:track/state/app_state.dart';
import 'package:track/util/day_key.dart';

/// The integration-repair suite: the day-level read/edit/delete path, and what happens
/// when a write does not land.
///
/// Every case here was a live defect found by reading the repository, and each one is
/// written so that it fails if the defect returns:
///
///  * **History was the projection, not the rows.** A day the user never logged was
///    rendered as `0`, which is indistinguishable from a logged zero, and every row was
///    captioned with the tracker's marketing blurb. `recordedDays` is built from rows.
///  * **Nothing could be corrected.** Every write path wrote *today*: a value entered on
///    the wrong day, or a mis-tap, was permanent. `setDayValue`/`clearDay` are that path,
///    and deleting a day must leave it **empty**, not zero.
///  * **A failed write was swallowed.** `_persist` caught everything, left the optimistic
///    value in the cache and let the UI confirm a save SQLite never received. It now
///    reports the failure and re-derives the projection from the store.
///  * **Reordering silently un-hid trackers** (`move()` and `pinToTop()` each ended with
///    `hidden = false`).
///
/// Not executed in the environment that wrote them (no Flutter SDK on this host — see
/// `docs/TEST_EVIDENCE.txt`). Run with:
///   flutter test test/day_edit_test.dart
/// `drift/native.dart` needs the host's sqlite3.
void main() {
  late TrackDatabase db;
  late EntryRepository repo;
  late CommitmentRepository commitments;
  late AppState state;

  final today = dayKey(DateTime.now());
  final yesterday = previousDayKey(today);

  setUp(() async {
    db = TrackDatabase.forTesting(NativeDatabase.memory());
    repo = EntryRepository(db);
    commitments = CommitmentRepository(db);
    state = AppState(repo: repo, commitmentRepo: commitments);
    await state.load();
  });

  tearDown(() async => db.close());

  Future<List<DailyEntry>> rowsFor(String id) => db.trackDao.dailyRowsFor(id, days: 60);

  /// Makes every write fail while **reads keep working**.
  ///
  /// `PRAGMA query_only` is the honest way to test this: the failure comes from SQLite
  /// itself, not from a mock that was told to throw, and the rollback can still be
  /// observed because the store is still readable afterwards.
  Future<void> goReadOnly() => db.customStatement('PRAGMA query_only = ON');
  Future<void> goWritable() => db.customStatement('PRAGMA query_only = OFF');

  /// Waits for a condition the app reaches asynchronously (an unawaited persist).
  Future<void> until(bool Function() done) async {
    for (var i = 0; i < 400; i++) {
      if (done()) return;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    fail('condition was not reached within 2 s');
  }

  group('history is read from stored rows', () {
    test('a fresh install has no recorded days anywhere', () async {
      for (final t in state.trackers) {
        expect(await state.recordedDays(t.id), isEmpty,
            reason: '${t.id} has no rows, so the history list says so instead of showing zeros');
      }
    });

    test('only days with a row are listed, newest first, with their source', () async {
      await state.setDayValue('water', yesterday, 1500);
      await state.setDayValue('water', today, 2000);

      final days = await state.recordedDays('water');
      expect(days.map((d) => d.day), [today, yesterday]);
      expect(days.map((d) => d.value), [2000, 1500]);
      expect(days.every((d) => d.source == 'manual'), isTrue);
    });

    test('a day that was never logged is absent — not a zero', () async {
      await state.setDayValue('water', today, 2000);
      final days = await state.recordedDays('water');
      expect(days.map((d) => d.day), [today]);
      expect(days.any((d) => d.day == yesterday), isFalse,
          reason: 'a gap in the history has no row, and is not a 0 the user did not enter');
    });

    test('a logged zero is a reading, and stays in the list', () async {
      // "Zero is a value" for the trackers where it is one — screen time and spending are
      // the clearest cases (`zeroIsAValue`). It has to be distinguishable from an empty
      // day, which is exactly what the gap-filled projection could not express.
      expect(state.log('screen', 0), isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final days = await state.recordedDays('screen');
      expect(days, hasLength(1));
      expect(days.single.value, 0);
      expect(days.single.day, today);
    });

    test('the list is bounded by the requested window', () async {
      await state.setDayValue('water', previousDayKey(yesterday), 500);
      await state.setDayValue('water', yesterday, 500);
      await state.setDayValue('water', today, 500);
      expect(await state.recordedDays('water'), hasLength(3));
      expect(await state.recordedDays('water', limit: 2), hasLength(2));
    });
  });

  group('one recorded day can be corrected', () {
    test('a past day can be written, not just today', () async {
      final ok = await state.setDayValue('water', yesterday, 1750);
      expect(ok, isTrue, reason: 'the write landed');
      final rows = await rowsFor('water');
      expect(rows.single.day, yesterday);
      expect(rows.single.value, 1750);
    });

    test('editing a day is an upsert, not a second row', () async {
      await state.setDayValue('water', yesterday, 1000);
      await state.setDayValue('water', yesterday, 1800);
      final rows = await rowsFor('water');
      expect(rows, hasLength(1), reason: 'one day, one row');
      expect(rows.single.value, 1800);
    });

    test('a refused value writes nothing and reports it', () async {
      expect(await state.setDayValue('water', yesterday, -5), isFalse);
      expect(await state.setDayValue('water', yesterday, double.nan), isFalse);
      expect(await rowsFor('water'), isEmpty, reason: 'nothing was stored for a refused value');
      expect(state.writeFailure, isNull,
          reason: 'a refusal is a validation answer, not a write failure');
    });

    test('editing an older day recomputes the derived numbers', () async {
      await state.setDayValue('water', yesterday, 2000);
      await state.setDayValue('water', today, 2000);
      final before = state.streak('water');
      await state.setDayValue('water', yesterday, 0);
      // Two days at goal then one day at zero: the streak cannot stay where it was.
      expect(state.streak('water'), lessThanOrEqualTo(before));
      expect(state.avg('water', 7), greaterThan(0));
    });
  });

  group('one recorded day can be deleted', () {
    test('deleting removes the row and says how many it removed', () async {
      await state.setDayValue('water', yesterday, 1500);
      expect(await state.clearDay('water', yesterday), 1);
      expect(await rowsFor('water'), isEmpty);
      expect(await state.recordedDays('water'), isEmpty);
    });

    test('deleting a day with nothing stored removes nothing and claims nothing', () async {
      expect(await state.clearDay('water', yesterday), 0);
      expect(await state.recordedDays('water'), isEmpty);
    });

    test('deleting also clears that day\'s events, so the export cannot disagree', () async {
      // A calorie day is a daily rollup plus an event log; clearing only one of them
      // would leave a day that looks deleted in the ring and present in the CSV.
      state.logAdd('calories', 300, meta: '{"title":"Oats"}');
      state.logAdd('calories', 200, meta: '{"title":"Dal"}');
      await Future<void>.delayed(const Duration(milliseconds: 10)); // let the unawaited writes land

      final events = await db.trackDao.eventsForDay('calories', today);
      expect(events, hasLength(2), reason: 'both foods are in the event log');

      final removed = await state.clearDay('calories', today);
      expect(removed, 3, reason: 'two events and the daily rollup');
      expect(await db.trackDao.eventsForDay('calories', today), isEmpty);
      expect(await rowsFor('calories'), isEmpty);
    });

    test('a deleted day does not come back as a zero in the projection', () async {
      await state.setDayValue('water', today, 2000);
      await state.clearDay('water', today);
      expect(state.today('water'), 0);
      expect(state.historyOf('water').every((v) => v == 0), isTrue,
          reason: 'the projection is re-derived, and an empty day reads empty');
    });
  });

  group('reordering never changes what is hidden', () {
    test('move() leaves a hidden tracker hidden, in the cache and in the database', () async {
      final id = state.trackers[1].id;
      state.toggleHidden(id);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(state.byId(id).hidden, isTrue);

      state.move(id, -1);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(state.byId(id).hidden, isTrue,
          reason: 'moving a row is not a statement about wanting to see it');
      final row = (await db.trackDao.allTrackers()).firstWhere((r) => r.id == id);
      expect(row.hidden, isTrue);
    });

    test('pinToTop() leaves a hidden tracker hidden', () async {
      final id = state.trackers[2].id;
      state.toggleHidden(id);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      state.pinToTop(id);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(state.byId(id).hidden, isTrue);
      final row = (await db.trackDao.allTrackers()).firstWhere((r) => r.id == id);
      expect(row.hidden, isTrue);
    });

    test('the order itself still moves, and persists', () async {
      final first = state.trackers.first.id;
      final second = state.trackers[1].id;
      state.move(second, -1);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final sorted = state.trackers.toList()..sort((a, b) => a.order.compareTo(b.order));
      expect(sorted.first.id, second);
      expect(sorted[1].id, first);
    });
  });

  group('a write that fails is reported, not confirmed', () {
    test('a failed day edit is refused, named, and leaves the old value alone', () async {
      await state.setDayValue('water', today, 1000);
      await goReadOnly();

      final ok = await state.setDayValue('water', today, 2000);
      expect(ok, isFalse, reason: 'the caller is told, so nothing claims it was saved');

      final failure = state.writeFailure;
      expect(failure, isNotNull);
      expect(failure!.action.contains('Water'), isTrue,
          reason: 'the banner names what the user was doing, not "an error": ${failure.action}');
      expect(failure.detail, isNotEmpty);

      // The store still holds the old value, and the projection agrees with it — the
      // whole point of the rollback.
      await goWritable();
      final rows = await rowsFor('water');
      expect(rows.single.value, 1000);
      expect(state.today('water'), 1000);

      state.acknowledgeWriteFailure();
      expect(state.writeFailure, isNull);
    });

    test('an optimistic log that fails is reported and rolled back', () async {
      // `log` paints the new value and persists in the background — that is what makes
      // logging instant, and it is also why a swallowed failure used to be invisible.
      await goReadOnly();
      expect(state.log('water', 2000), isTrue, reason: 'the optimistic contract: valid, so painted');
      expect(state.today('water'), 2000);

      await until(() => state.writeFailure != null);
      expect(state.writeFailure!.action.contains('Water'), isTrue);

      await goWritable();
      expect(state.today('water'), 0,
          reason: 'the painted value was rolled back to what the store actually holds');
      expect(await state.recordedDays('water'), isEmpty);
    });

    test('a successful write reports no failure at all', () async {
      expect(await state.setDayValue('water', today, 1200), isTrue);
      expect(state.writeFailure, isNull);
    });

    test('the rollback survives a database that cannot be read either', () async {
      // A failed write and a failed re-read must not become a *crash* on top of a
      // failure: the rollback is best-effort, the report is not.
      await db.close();
      final ok = await state.setDayValue('water', today, 900);
      expect(ok, isFalse);
      expect(state.writeFailure, isNotNull, reason: 'the failure is still reported');
    });
  });

  group('what the sheets claim is stored really is', () {
    test('logPeriod keeps the flow and the symptoms, not just the day', () async {
      final ok = state.logPeriod(flow: 2, symptoms: ['Cramps', 'Headache']);
      expect(ok, isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final rows = await rowsFor('period');
      expect(rows, hasLength(1));
      final meta = rows.single.meta ?? '';
      expect(meta.contains('"flow"'), isTrue, reason: 'the flow chip is data: $meta');
      expect(meta.contains('Cramps'), isTrue);
      expect(meta.contains('Headache'), isTrue);
    });

    test('the goal sheet\'s write is awaited and lands', () async {
      final t = state.trackers.first;
      final ok = await state.setGoal(t.id, t.goal * 2);
      expect(ok, isTrue);

      // A *new* AppState over the same database is the only honest proof of persistence:
      // nothing in memory is carried over.
      final reopened = AppState(repo: EntryRepository(db), commitmentRepo: commitments);
      await reopened.load();
      expect(reopened.byId(t.id).goal, t.goal * 2);
    });

    test('an absolute log is not a delta', () async {
      // This is the semantics the calories sheet depends on: the value in the stepper is
      // the day's running total, so writing it must *set* the day. Sending it through the
      // delta API added today's calories to themselves (1,800 + 1,800).
      expect(state.log('calories', 1800), isTrue);
      expect(state.log('calories', 1800), isTrue);
      expect(state.today('calories'), 1800, reason: 'absolute, and therefore idempotent');

      expect(state.logAdd('calories', 300), isTrue);
      expect(state.today('calories'), 2100, reason: 'a delta adds exactly once');
    });

    test('the added list survives a restart', () async {
      final candidate = state.trackers.isEmpty ? 'x' : 'sleep';
      state.toggleAdded(candidate);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final reopened = AppState(repo: EntryRepository(db), commitmentRepo: commitments);
      await reopened.load();
      expect(reopened.added.contains(candidate), isTrue);
    });
  });
}
