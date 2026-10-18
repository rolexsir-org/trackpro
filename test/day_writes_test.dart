import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track/data/commitment_repository.dart';
import 'package:track/data/db/database.dart';
import 'package:track/data/entry_repository.dart';
import 'package:track/state/app_state.dart';
import 'package:track/util/day_key.dart';

/// Day-level writes, against a real in-memory SQLite database.
///
/// Three defects meet in this file, and they are all the same shape: **a mutation that
/// reported success without changing what was on disk** (or, in one case, the reverse —
/// refusing a change that should have applied).
///
///  1. `clearDay` deleted only `source = 'manual'` rollups. A day whose steps, sleep or
///     weight came from Health Connect had no manual row, so "clear this day" reported
///     that nothing was stored, left the row in the database, and the number reappeared on
///     the next hydrate — with the user's delete having taught them that deletes do not work.
///  2. The hero card's swipe-left is `onStep(-step)`, and `logAdd` validated the *delta*
///     with the value validator, which refuses every negative. The removal gesture was a
///     no-op with a warning haptic, on every default install.
///  3. `addExpense` skipped validation entirely — a `NaN`, a negative, or a 10-digit typo
///     went straight into the rollup that every average and ring is computed from.
///
/// `logAdd`/`addExpense` persist through `_persist`, which is deliberately fire-and-forget
/// (a tap must not wait on SQLite), so every assertion that reads the database drains the
/// queue first with `drain()`. If a run here goes flaky, look at that delay before the
/// write's own error handling: the cache assertions are synchronous and were true throughout.
///
/// Reads go through `repo.dao` rather than `db.select(db.events)` on purpose: the DAO is the
/// audited surface (`tools/test_api_audit.py` resolves test members against `lib/`, and the
/// generated `_$TrackDatabase` accessors are its blind spot), so a rename in the DAO breaks
/// this file loudly instead of silently.
///
/// Not executed in the environment that wrote them (no Flutter SDK). Run with:
///   flutter test test/day_writes_test.dart
/// `drift/native.dart` needs the host's sqlite3 on Linux.
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

  Future<void> drain() => Future<void>.delayed(const Duration(milliseconds: 80));

  group('clearing a day means every source that wrote it', () {
    test('a day whose only row came from Health Connect is still clearable', async () {
      final today = todayKey();
      // A synced steps day: a rollup and its event row, both `health`, no manual row.
      await repo.dao.upsertDaily(trackerId: 'steps', day: today, value: 6200, source: 'health');
      await repo.dao.insertEvent(trackerId: 'steps', value: 6200, source: 'health');
      expect(await repo.dao.dailyRowsFor('steps', days: 1), isNotEmpty,
          reason: 'the row exists before the delete, or this test proves nothing');

      final removed = await repo.clearDay('steps', today);
      expect(removed, greaterThan(0), reason: 'the count is what the sheet reports back');
      expect(await repo.dao.dailyRowsFor('steps', days: 1), isEmpty,
          reason: 'the rollup must be gone from SQLite, not only from the cache');
      final rows = await repo.dao.eventsForDay('steps', today);
      expect(rows, isEmpty,
          reason: 'and the event feed must not keep describing a day that was deleted');
    });

    test('a day with both a manual and a synced row loses both, in one pass', async () {
      final today = todayKey();
      await repo.dao.upsertDaily(trackerId: 'weight', day: today, value: 81.2, source: 'manual');
      await repo.dao.upsertDaily(trackerId: 'weight', day: today, value: 80.9, source: 'health');
      expect(await repo.dao.dailyRowsFor('weight', days: 1), hasLength(1),
          reason: 'one rollup row per (tracker, day) — the second write replaced the first');

      final removed = await repo.clearDay('weight', today);
      expect(removed, greaterThan(0));
      expect(await repo.dao.dailyRowsFor('weight', days: 1), isEmpty);
    });

    test('clearing a day that holds nothing is a no-op, not an error', async () {
      expect(await repo.clearDay('water', dayKeyFromToday(9)), 0,
          reason: 'the sheet distinguishes "nothing to delete" from "delete failed"');
    });
  });

  group('stepping a day down is a real operation', () {
    test('one serving added, then removed, leaves today at zero — and both rows land', () async {
      expect(state.logAdd('water', 250), isTrue);
      expect(state.today('water'), 250);
      // The defect: `ValueValidation.sanitize` is a *value* validator, so it refused
      // every negative and the hero card's swipe-left did nothing at all.
      expect(state.logAdd('water', -250), isTrue, reason: 'removing what was just logged is a correction');
      expect(state.today('water'), 0);
      await drain();
      final events = await repo.dao.eventsForDay('water', todayKey());
      expect(events, hasLength(2), reason: 'both the add and the removal are in the feed');
      expect(events.map((e) => e.value).toSet(), {250.0, -250.0},
          reason: 'the removal is stored as the change that happened, not as a positive value');
    });

    test('a removal below zero is refused, and the day keeps its value', () async {
      expect(state.logAdd('water', 250), isTrue);
      expect(state.logAdd('water', -1000), isFalse,
          reason: 'two cups cannot become minus three cups; refusing is the honest answer');
      expect(state.today('water'), 250);
      await drain();
      final events = await repo.dao.eventsForDay('water', todayKey());
      expect(events, hasLength(1), reason: 'a refused write must not appear in the feed at all');
    });

    test('a change that would be clamped to where the day already is reports nothing happened', () async {
      // 20 L is `boundsFor('water')`'s ceiling. Once today is at it, "+1 more" cannot be
      // applied as asked. Confirming it would be a lie about a write that did not land.
      expect(state.logAdd('water', 20000), isTrue);
      expect(state.today('water'), 20000);
      expect(state.logAdd('water', 250), isFalse, reason: 'already at the ceiling');
      expect(state.logAdd('water', 0), isFalse, reason: 'a zero delta changes nothing');
    });

    test('an unknown tracker id is refused instead of throwing', () async {
      expect(state.logAdd('not-a-tracker', 250), isFalse);
      expect(state.logAdd('not-a-tracker', -250), isFalse);
      expect(state.today('not-a-tracker'), 0);
    });

    test('a non-finite delta cannot poison the rollup', () async {
      expect(state.logAdd('water', double.nan), isFalse);
      expect(state.logAdd('water', double.infinity), isFalse);
      expect(state.today('water'), 0);
      await drain();
      expect(await repo.dao.eventsForDay('water', todayKey()), isEmpty);
    });
  });

  group('an expense is validated on the way in', () {
    test('a valid amount adds to today and returns true', () async {
      expect(state.addExpense(120, 'Groceries'), isTrue);
      expect(state.today('expenses'), 120);
      expect(state.addExpense(30, 'Groceries'), isTrue);
      expect(state.today('expenses'), 150, reason: 'expenses accumulate through the day');
    });

    test('a negative, a zero and a NaN are all refused', () async {
      expect(state.addExpense(-5, 'Groceries'), isFalse);
      expect(state.addExpense(0, 'Groceries'), isFalse);
      expect(state.addExpense(double.nan, 'Groceries'), isFalse);
      expect(state.today('expenses'), 0);
      await drain();
      expect(await repo.dao.eventsForDay('expenses', todayKey()), isEmpty,
          reason: 'the sheet reports "nothing was saved" from exactly this return value');
    });

    test('an unrecognised category lands in the bucket the chart colours', () async {
      expect(state.addExpense(500, 'Flat rent'), isTrue,
          reason: 'the *amount* is what is validated; an unknown category is bucketed, not refused');
      await drain();
      final rows = await repo.dao.eventsForDay('expenses', todayKey());
      expect(rows, hasLength(1));
      final meta = jsonDecode(rows.single.meta!) as Map<String, dynamic>;
      expect(meta['category'], 'Other',
          reason: 'an unexpected spelling must not create an unlabelled slice');
      final totals = await repo.categoryTotals(days: 7);
      expect(totals.map((t) => t.category), contains('Other'));
      expect(totals.map((t) => t.category), isNot(contains('Flat rent')));
    });
  });

  group('the day window a query sees is the window the UI labels', () {
    test('dayKeysEndingToday covers exactly N keys and ends today', () {
      for (final n in [1, 7, 28, 60]) {
        final keys = TrackDao.dayKeysEndingToday(n);
        expect(keys, hasLength(n));
        expect(keys.last, todayKey());
        expect(keys.first, dayKeyFromToday(n - 1));
        expect(daysBetweenKeys(keys.first, keys.last), n - 1);
        // The aggregate queries take only the left edge; if the two ever disagree, the
        // chart and the tile built from it describe different windows.
        expect(TrackDao.dayKeyWindowStart(n), keys.first);
      }
    });

    test('a window of 1 is today alone, and a non-positive window is empty', () {
      expect(TrackDao.dayKeysEndingToday(1), [todayKey()]);
      expect(TrackDao.dayKeysEndingToday(0), isEmpty);
      expect(TrackDao.dayKeysEndingToday(-3), isEmpty);
      expect(TrackDao.dayKeyWindowStart(1), todayKey());
    });

    test('a value logged yesterday is in a 7-day window and out of a 1-day one', () async {
      final yesterday = dayKeyFromToday(1);
      await repo.dao.upsertDaily(trackerId: 'water', day: yesterday, value: 1000, source: 'manual');
      expect(await repo.dao.dailyRowsFor('water', days: 7), hasLength(1));
      expect(await repo.dao.dailyRowsFor('water', days: 1), isEmpty,
          reason: 'the boundary is the day key, not an elapsed-hours comparison');
      expect(await repo.dao.series('water', days: 7), [0, 0, 0, 0, 0, 1000, 0],
          reason: 'gap-filled, oldest first, today last');
    });
  });
}
