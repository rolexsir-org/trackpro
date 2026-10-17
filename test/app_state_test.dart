import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track/data/commitment_repository.dart';
import 'package:track/data/db/database.dart';
import 'package:track/data/entry_repository.dart';
import 'package:track/state/app_state.dart';
import 'package:track/util/day_key.dart';

/// The read layer, tested through the real `AppState` over a real in-memory
/// database — no widget tree, no platform channels.
///
/// Two things are guarded here, both of which were live defects:
///
///  1. **Short or absent series must not throw.** `today`/`week`/`avg`/`best`
///     force-unwrapped `history[id]` and indexed past the end of the list. A
///     tracker the projection did not carry, or a series shorter than the window,
///     took the screen down; the fix clamps instead, and these tests pin that.
///  2. **The export includes the routines.** Measurements and Momentum live in
///     different tables, so "take your data with you" is assembled in `AppState`
///     and could silently drop half of it.
///
/// Not executed in the environment that wrote them (no Flutter SDK). Run with:
///   flutter test test/app_state_test.dart
/// `drift/native.dart` needs the host's sqlite3 on Linux.
void main() {
  late TrackDatabase db;
  late EntryRepository repo;
  late CommitmentRepository commitments;
  late AppState state;

  final fixedNow = DateTime(2026, 3, 11, 10, 0);

  setUp(() async {
    db = TrackDatabase.forTesting(NativeDatabase.memory());
    repo = EntryRepository(db);
    commitments = CommitmentRepository(db, now: () => fixedNow);
    state = AppState(repo: repo, commitmentRepo: commitments);
    await state.load();
  });

  tearDown(() async => db.close());

  group('a fresh install reads zero, not a placeholder', () {
    test('there is a catalogue but no logged day anywhere', () async {
      expect(state.trackers, isNotEmpty, reason: 'the defaults ship with the app');
      expect(state.entryCount, 0);
      expect(state.trackedDays, 0);
      expect(state.trackingSince, isNull, reason: 'nothing has been logged, so there is no since-date');
      expect(state.hasAnyData, isFalse);
    });

    test('every tracker reads zero today and a full, zero-filled week', () async {
      for (final t in state.trackers) {
        expect(state.today(t.id), 0, reason: '${t.id} has no invented value');
        expect(state.week(t.id).length, 7, reason: '${t.id} is gap-filled to the window');
        expect(state.week(t.id).every((v) => v == 0), isTrue);
        expect(state.avg(t.id, 7), 0);
        expect(state.streak(t.id), 0, reason: 'a fresh install has no streak');
      }
    });
  });

  group('an id the projection does not carry degrades instead of throwing', () {
    test('the value accessors return zero and an empty series', () {
      expect(state.today('not-a-tracker'), 0);
      expect(state.week('not-a-tracker'), isEmpty);
      expect(state.avg('not-a-tracker', 7), 0);
      expect(state.best('not-a-tracker'), 0);
      expect(state.historyOf('not-a-tracker'), isEmpty);
    });

    test('a series shorter than the requested window is clamped, not indexed past', () async {
      // A tracker added by hand has a short series in the cache; `series` is what
      // every chart goes through, and it must never return more than it holds.
      await repo.bootstrap();
      final short = state.series('steps', 7);
      expect(short.length, 7);
      expect(state.series('steps', 10000).length, lessThanOrEqualTo(EntryRepository.cacheDays),
          reason: 'asking for more days than the cache holds cannot invent points');
      expect(state.series('steps', 0), isEmpty, reason: 'zero days is zero points');
    });

    test('writing to a tracker that has no series in memory still lands on today', () {
      expect(state.log('steps', 5000), isTrue);
      expect(state.today('steps'), 5000, reason: 'the write goes to the last slot, not out of range');
      expect(state.log('not-a-tracker', 1), isFalse,
          reason: 'validation refuses an id the app does not know, rather than inventing a series');
    });
  });

  group('the export carries both halves of the user\'s data', () {
    test('the JSON export merges the commitments section', () async {
      await commitments.create(
        id: 'run',
        name: 'Run',
        emoji: '🏃',
        color: 0xFF5B7CFA,
        outcome: 'Get through a 5k',
        minimumAction: 'Shoes on, 5 minutes',
        fullAction: 'Run 5 km',
        weekdays: const {1, 3, 5},
      );
      await commitments.record(commitmentId: 'run', outcome: DayOutcome.full);

      final payload = jsonDecode(await state.exportJson()) as Map<String, dynamic>;
      expect(payload['trackers'], isNotNull, reason: 'the measurements half is still there');
      final exported = payload['commitments']! as Map<String, dynamic>;
      expect(exported['format'], 'track.commitments.v1');
      expect((exported['routines']! as List<dynamic>).length, 1);
      expect(
        ((exported['routines']! as List<dynamic>).first as Map<String, dynamic>)['days'],
        hasLength(1),
      );
      expect((exported['totals']! as Map<String, dynamic>)['recorded_days'], 1);
    });

    test('the routine CSV has a header even when nothing was ever recorded', () {
      expect(state.exportCommitmentsCsv(), 'date,routine,outcome,value,note');
    });
  });

  group('day keys are local calendar days', () {
    test('todayKey matches the injected clock, not the host clock', () {
      expect(commitments.todayKey, dayKey(fixedNow));
    });
  });
  group('delete all data is a real wipe, not a partial one', () {
    test('entries, routines and their records all go, and the counts are returned', () async {
      state.log('water', 750);
      await commitments.create(
        id: 'gym',
        name: 'Gym',
        emoji: '🏃',
        color: 0xFF5B7CFA,
        outcome: 'Stronger each week',
        minimumAction: 'Ten minutes, any movement',
        fullAction: '45 minutes, full session',
        weekdays: const {1, 2, 3, 4, 5},
      );
      await commitments.record(commitmentId: 'gym', outcome: DayOutcome.full);
      await commitments.startPause('gym', reason: 'travelling');
      expect(state.hasAnyData, isTrue);
      expect(state.commitments, hasLength(1), reason: 'the routine is live before the wipe');

      final removed = await state.reset();

      expect(removed['daily_entries'], greaterThan(0), reason: 'the count is the one SQLite reported');
      expect(removed['routines'], 1, reason: 'a routine is the user\'s content, so it goes');
      expect(removed['routine_days'], 1);
      expect(removed['routine_pauses'], 1);
      expect(state.entryCount, 0);
      expect(state.hasAnyData, isFalse);
      expect(state.commitments, isEmpty);
      expect(state.momentum, isEmpty, reason: 'the projection is not left drawing deleted routines');
    });

    test('what survives is the shipped catalogue and the user\'s own settings', () async {
      await state.completeOnboarding();
      state.log('water', 750);
      await state.reset();

      expect(state.trackers, isNotEmpty, reason: 'deleting your entries does not delete your trackers');
      expect(state.onboarded, isTrue, reason: 'a wipe is not a reinstall — the intro does not replay');
      expect(await repo.dao.getSetting('added'), isNotNull);
    });
  });

}
