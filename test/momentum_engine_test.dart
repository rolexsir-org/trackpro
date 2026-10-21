import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track/data/momentum.dart';
import 'package:track/models/models.dart';
import 'package:track/util/day_key.dart';

/// Momentum rules, tested as arithmetic.
///
/// The engine is pure — it takes commitments, recorded days, pauses and a "today"
/// key — so these tests fix a date and assert exact figures. That matters more here
/// than anywhere else in the app: every one of these numbers is shown to a user as
/// a statement about their own follow-through, so each rule below is the contract
/// between the screen and the record.
///
/// Not executed in the environment that wrote them (no Flutter SDK). Run with:
///   flutter test test/momentum_engine_test.dart
void main() {
  // A fixed Wednesday. Every test computes against this, never against the clock.
  final today = dayKey(DateTime(2026, 3, 11));
  int daysAgo(int n) => dayKey(DateTime(2026, 3, 11).subtract(Duration(days: n)));

  Commitment commitment({Set<int> schedule = const {1, 2, 3, 4, 5, 6, 7}, int? created, String id = 'run'}) =>
      Commitment(
        id: id,
        name: 'Run',
        emoji: '🏃',
        color: const Color(0xFF5B7CFA),
        outcome: 'Run a 5k without stopping',
        minimumAction: 'Shoes on, walk 5 minutes',
        fullAction: 'Run 5 km',
        revisions: [ScheduleRevision(created ?? daysAgo(60), schedule)],
        createdDay: created ?? daysAgo(60),
      );

  Map<int, CommitmentDay> records(Map<int, DayOutcome> byDay, {String id = 'run'}) => {
    for (final e in byDay.entries) e.key: CommitmentDay(commitmentId: id, day: e.key, outcome: e.value),
  };

  group('credit — a minimum is not a completion', () {
    test('one full day is 1.0 of credit and reports as a full day', () {
      final snap = MomentumEngine.compute(
        c: commitment(),
        recorded: records({today: DayOutcome.full}),
        pauses: const [],
        today: today,
      );
      expect(snap.fullDays, 1);
      expect(snap.minimumDays, 0);
      expect(snap.credit, 1.0);
    });

    test('one minimum day earns partial credit, never a full day', () {
      final snap = MomentumEngine.compute(
        c: commitment(),
        recorded: records({today: DayOutcome.minimum}),
        pauses: const [],
        today: today,
      );
      expect(snap.minimumDays, 1);
      expect(snap.fullDays, 0, reason: 'a minimum is never counted as a full completion');
      expect(snap.credit, MomentumEngine.minimumCredit);
    });

    test('a miss earns nothing', () {
      final snap = MomentumEngine.compute(
        c: commitment(),
        recorded: records({today: DayOutcome.missed}),
        pauses: const [],
        today: today,
      );
      expect(snap.missedDays, 1);
      expect(snap.credit, 0);
    });
  });

  group('the reporting threshold is real', () {
    test('no rate is reported below seven decided days', () {
      final day = daysAgo(6);
      final snap = MomentumEngine.compute(
        c: commitment(),
        recorded: records({for (var i = 6; i >= 0; i--) daysAgo(i): DayOutcome.full}),
        pauses: const [],
        today: today,
      );
      expect(snap.decidedDays, 7, reason: 'seven planned days, all recorded as full');
      expect(snap.rate, isNotNull);
      expect(day, isNotNull);
      expect(snap.rate, closeTo(100.0, .001));
    });

    test('six decided days yields null, not a percentage of six', () {
      final snap = MomentumEngine.compute(
        c: commitment(),
        recorded: records({for (var i = 5; i >= 0; i--) daysAgo(i): DayOutcome.full}),
        pauses: const [],
        today: today,
      );
      expect(snap.decidedDays, 6);
      expect(snap.rate, isNull, reason: 'the screen must show a count, not a score');
    });

    test('the rate is the credit ratio, not the completion ratio', () {
      // 7 decided days: 4 full (4.0) + 3 minimum (1.8) = 5.8 / 7 = 82.857%
      final recorded = <int, DayOutcome>{
        for (var i = 0; i < 4; i++) daysAgo(i): DayOutcome.full,
        for (var i = 4; i < 7; i++) daysAgo(i): DayOutcome.minimum,
      };
      final snap = MomentumEngine.compute(c: commitment(), recorded: records(recorded), pauses: const [], today: today);
      expect(snap.rate, closeTo(5.8 / 7 * 100, .001));
    });
  });

  group('planned, decided and excluded days', () {
    test('a planned day in the past with no record counts as a miss', () {
      final snap = MomentumEngine.compute(c: commitment(), recorded: const {}, pauses: const [], today: today);
      expect(snap.plannedDays, 28, reason: 'the window is 28 days including today');
      expect(snap.decidedDays, 27, reason: 'today is still running, so it is not decided');
      expect(snap.missedDays, 27);
      expect(snap.missedRun, 27, reason: 'every planned day before today is a live gap');
    });

    test('today is not judged until it is over', () {
      final snap = MomentumEngine.compute(
        c: commitment(),
        recorded: records({daysAgo(1): DayOutcome.full}),
        pauses: const [],
        today: today,
      );
      // 26 planned days before yesterday are silent (misses) + 1 full; today is open.
      expect(snap.decidedDays, 27);
      expect(snap.missedDays, 26);
      expect(snap.fullDays, 1);
      expect(snap.todayOpen, isTrue);
    });

    test('rest days and deliberate skips are excluded, not punished', () {
      final snap = MomentumEngine.compute(
        c: commitment(),
        recorded: records({today: DayOutcome.full, daysAgo(1): DayOutcome.rest, daysAgo(2): DayOutcome.skipped}),
        pauses: const [],
        today: today,
      );
      expect(snap.excludedDays, 2);
      expect(snap.missedDays, 25, reason: 'the rest days are not counted as misses');
      expect(snap.decidedDays, 26);
    });

    test('only selected weekdays are planned at all', () {
      // Monday, Wednesday, Friday only.
      final c = commitment(schedule: const {1, 3, 5});
      final snap = MomentumEngine.compute(c: c, recorded: const {}, pauses: const [], today: today);
      // 2026-03-11 is a Wednesday and the window covers four weeks, so 12 planned days.
      expect(snap.plannedDays, 12);
    });

    test('nothing before the commitment existed is judged', () {
      final c = commitment(created: daysAgo(2));
      final snap = MomentumEngine.compute(c: c, recorded: const {}, pauses: const [], today: today);
      expect(snap.plannedDays, 3, reason: 'created two days ago, so three planned days including today');
      expect(snap.decidedDays, 2, reason: 'today is still open');
    });
  });

  group('streaks distinguish full from kept-going', () {
    test('a minimum breaks the full streak but keeps the run alive', () {
      final snap = MomentumEngine.compute(
        c: commitment(),
        recorded: records({
          today: DayOutcome.full,
          daysAgo(1): DayOutcome.full,
          daysAgo(2): DayOutcome.minimum,
          daysAgo(3): DayOutcome.full,
        }),
        pauses: const [],
        today: today,
      );
      expect(snap.fullStreak, 2, reason: 'the minimum on day-2 stops the full streak');
      expect(snap.keepGoingStreak, 3, reason: 'minimum counts for the keep-going streak');
    });

    test('rest days neither extend nor break a streak', () {
      final snap = MomentumEngine.compute(
        c: commitment(),
        recorded: records({today: DayOutcome.full, daysAgo(1): DayOutcome.rest, daysAgo(2): DayOutcome.full}),
        pauses: const [],
        today: today,
      );
      expect(snap.fullStreak, 2);
      expect(snap.keepGoingStreak, 2);
    });

    test('a miss breaks both streaks', () {
      final snap = MomentumEngine.compute(
        c: commitment(),
        recorded: records({today: DayOutcome.full, daysAgo(1): DayOutcome.missed, daysAgo(2): DayOutcome.full}),
        pauses: const [],
        today: today,
      );
      expect(snap.fullStreak, 1);
      expect(snap.keepGoingStreak, 1);
    });
  });

  group('schedule changes do not rewrite history', () {
    test('a revision governs only the days from its own date onward', () {
      final c = Commitment(
        id: 'run',
        name: 'Run',
        emoji: '🏃',
        color: const Color(0xFF5B7CFA),
        outcome: 'o',
        minimumAction: 'm',
        fullAction: 'f',
        // Every day for the first 20 days, then weekdays only from day-10 on.
        revisions: [
          ScheduleRevision(daysAgo(20), const {1, 2, 3, 4, 5, 6, 7}),
          ScheduleRevision(daysAgo(10), const {1, 2, 3, 4, 5}),
        ],
        createdDay: daysAgo(20),
      );

      // Rather than hard-coding weekdays, assert the invariant: every day before the
      // revision is planned, every weekend day after it is not.
      var before = 0;
      for (var i = 20; i > 10; i--) {
        if (MomentumEngine.isPlanned(c, daysAgo(i), const [])) before++;
      }
      expect(before, 10, reason: 'the daily revision still governs its own days');

      var weekendAfter = 0;
      for (var i = 10; i >= 0; i--) {
        final d = daysAgo(i);
        final wd = weekdayOfDayKey(d);
        if (wd <= 5) continue;
        if (MomentumEngine.isPlanned(c, d, const [])) weekendAfter++;
      }
      expect(weekendAfter, 0, reason: 'the weekday-only revision excludes weekends from its start date');
    });
  });

  group('pauses stop the clock', () {
    test('paused days are not planned, not counted and not missed', () {
      final pause = Pause(commitmentId: 'run', fromDay: daysAgo(5), toDay: daysAgo(1));
      final snap = MomentumEngine.compute(c: commitment(), recorded: const {}, pauses: [pause], today: today);
      expect(snap.plannedDays, 23, reason: 'five of the 28 window days are inside the pause');
      expect(snap.decidedDays, 22, reason: 'today is inside neither set: it is still open');
      expect(snap.missedDays, 22);
    });

    test('an open pause has no end', () {
      final pause = Pause(commitmentId: 'run', fromDay: daysAgo(3));
      expect(pause.covers(daysAgo(1)), isTrue);
      expect(pause.covers(today), isTrue);
      expect(pause.covers(daysAgo(4)), isFalse);
    });
  });

  group('recovery plans', () {
    test('three planned misses in a row produce a plan with three steps', () {
      final snap = MomentumEngine.compute(
        c: commitment(),
        recorded: records({daysAgo(3): DayOutcome.missed, daysAgo(4): DayOutcome.full}),
        pauses: const [],
        today: today,
      );
      // days 0,1,2 are silent (misses) → trailing run of 3+
      expect(snap.missedRun, greaterThanOrEqualTo(MomentumEngine.recoveryGap));
      expect(snap.restart, isNotNull);
      expect(snap.restart!.steps.length, 3);
      expect(snap.restart!.reason, contains('planned days in a row'));
      expect(snap.restart!.reason, isNot(contains('you should')), reason: 'no moralising');
    });

    test('two misses do not trigger a plan', () {
      final snap = MomentumEngine.compute(
        c: commitment(),
        recorded: records({daysAgo(1): DayOutcome.missed, daysAgo(2): DayOutcome.missed, daysAgo(3): DayOutcome.full}),
        pauses: const [],
        today: today,
      );
      expect(snap.missedRun, 2);
      expect(snap.restart, isNull, reason: 'two days is a bad patch, not a pattern to recover from');
    });

    test('a logged day today clears the trailing run', () {
      final snap = MomentumEngine.compute(
        c: commitment(),
        recorded: records({
          today: DayOutcome.minimum,
          daysAgo(1): DayOutcome.missed,
          daysAgo(2): DayOutcome.missed,
          daysAgo(3): DayOutcome.missed,
        }),
        pauses: const [],
        today: today,
      );
      expect(snap.missedRun, 0);
      expect(snap.restart, isNull);
    });
  });

  group('patterns need sample, not vibes', () {
    test('a weekday needs three decided days before it can be named', () {
      // Two missed Mondays and nothing else.
      final mondays = [
        dayKey(DateTime(2026, 3, 9)), // Monday
        dayKey(DateTime(2026, 3, 2)), // Monday
      ];
      final c = commitment(schedule: const {1});
      final recorded = records({for (var i = 0; i < mondays.length; i++) mondays[i]: DayOutcome.missed});
      final patterns = MomentumEngine.weekdayPatterns(c: c, recorded: recorded, pauses: const [], today: today);
      expect(patterns, isEmpty, reason: 'two data points cannot support a claim');
    });

    test('three missed Mondays against a strong record is reported with its counts', () {
      final c = commitment(schedule: const {1, 3});
      final recorded = <int, CommitmentDay>{};
      // Every Wednesday in the window: full.
      for (var i = 0; i < 28; i++) {
        final d = daysAgo(i);
        if (weekdayOfDayKey(d) == 3) {
          recorded[d] = CommitmentDay(commitmentId: 'run', day: d, outcome: DayOutcome.full);
        }
      }
      // Three Mondays: missed.
      final missedMondays = <int>[];
      for (var i = 0; i < 28 && missedMondays.length < 3; i++) {
        final d = daysAgo(i);
        if (weekdayOfDayKey(d) == 1) {
          recorded[d] = CommitmentDay(commitmentId: 'run', day: d, outcome: DayOutcome.missed);
          missedMondays.add(d);
        }
      }
      final patterns = MomentumEngine.weekdayPatterns(
        c: c,
        recorded: recorded,
        pauses: const [],
        today: today,
        weeks: 4,
      );
      expect(patterns, isNotEmpty, reason: 'three misses in four Mondays is a real pattern');
      expect(patterns.first.weekday, 1);
      expect(patterns.first.decided, greaterThanOrEqualTo(3));
      expect(patterns.first.missed, greaterThanOrEqualTo(3));
      expect(patterns.first.missRate, greaterThan(.5));
    });

    test('improvement needs two windows of at least seven decided days', () {
      final c = commitment();
      // Last 14 days: mostly full. Previous 14: mostly missed. Both have ≥7 decided.
      final recorded = <int, CommitmentDay>{};
      for (var i = 0; i < 28; i++) {
        final d = daysAgo(i);
        final recent = i < 14;
        recorded[d] = CommitmentDay(
          commitmentId: 'run',
          day: d,
          outcome: recent && i % 7 != 6 ? DayOutcome.full : DayOutcome.missed,
        );
      }
      final imp = MomentumEngine.improvement(c: c, recorded: recorded, pauses: const [], today: today);
      expect(imp, isNotNull);
      expect(imp!.delta, greaterThanOrEqualTo(MomentumEngine.improvementMinPoints));
      expect(imp.recentDays, greaterThanOrEqualTo(MomentumEngine.improvementMinSample));
      expect(imp.previousDays, greaterThanOrEqualTo(MomentumEngine.improvementMinSample));
    });

    test('a tiny improvement is not reported as progress', () {
      final c = commitment();
      final recorded = <int, CommitmentDay>{
        for (var i = 0; i < 28; i++)
          daysAgo(i): CommitmentDay(
            commitmentId: 'run',
            day: daysAgo(i),
            outcome: i < 14 && i % 10 == 0 ? DayOutcome.full : DayOutcome.missed,
          ),
      };
      final imp = MomentumEngine.improvement(c: c, recorded: recorded, pauses: const [], today: today);
      expect(imp, isNull, reason: 'a two-point move is not worth a card');
    });
  });

  group('weekly review', () {
    test('covers Monday to Sunday of the week containing the given day', () {
      final review = MomentumEngine.weeklyReview(
        commitments: [commitment()],
        recorded: const {},
        pauses: const [],
        anyDayInWeek: today, // Wednesday 2026-03-11
      );
      expect(weekdayOfDayKey(review.weekStart), 1, reason: 'the review week starts on a Monday');
      expect(daysBetweenKeys(review.weekStart, review.weekEnd), 6);
      expect(review.commitments.length, 1);
    });

    test('days later in the same week are not counted as misses yet', () {
      final review = MomentumEngine.weeklyReview(
        commitments: [commitment()],
        recorded: const {},
        pauses: const [],
        anyDayInWeek: today,
      );
      // Monday, Tuesday silent (missed); Wednesday is "today" and open; Thu–Sun ahead.
      expect(review.missedDays, 2);
      expect(review.decidedDays, 2);
      expect(review.complete, isFalse);
      expect(review.rate, isNull, reason: 'two decided days cannot produce a rate');
    });

    /// A full week of records ending on the given day, `outs[i]` on day i
    /// (0 = Monday), using each outcome's own credit.
    Map<int, CommitmentDay> weekOf(int anyDay, List<DayOutcome> outs) {
      final recorded = <int, CommitmentDay>{};
      var day = weekStartKey(anyDay);
      for (var i = 0; i < 7; i++) {
        if (outs[i] != DayOutcome.rest && outs[i] != DayOutcome.skipped) {
          recorded[day] = CommitmentDay(commitmentId: 'run', day: day, outcome: outs[i]);
        }
        if (i < 6) day = nextDayKey(day);
      }
      return recorded;
    }

    test('a week below the sample threshold is reported as a count, not a rate', () {
      final lastWeek = daysAgo(7); // Wednesday of the previous week
      // Five full days, two rest days: the plan was met, but five decided days is
      // under minDecidedDaysForRate, so the week gets a count instead of a score.
      final recorded = weekOf(lastWeek, [
        DayOutcome.full,
        DayOutcome.full,
        DayOutcome.full,
        DayOutcome.full,
        DayOutcome.full,
        DayOutcome.rest,
        DayOutcome.rest,
      ]);
      final review = MomentumEngine.weeklyReview(
        commitments: [commitment()],
        recorded: {'run': recorded},
        pauses: const [],
        anyDayInWeek: lastWeek,
      );
      expect(review.decidedDays, 5);
      expect(review.fullDays, 5);
      expect(review.excludedDays, 2);
      expect(review.missedDays, 0);
      expect(
        review.rate,
        isNull,
        reason: 'the weekly rate obeys the same ${MomentumEngine.minDecidedDaysForRate}-day rule as the rolling rate',
      );
      expect(
        review.complete,
        isFalse,
        reason: 'complete is measured against the reference day, and that week still contains it',
      );
    });

    test('a week at the sample threshold reports a rate, with minimums worth 0.6', () {
      final lastWeek = daysAgo(7);
      // Five full days and two minimum-only days: 5 + 2×0.6 = 6.2 credit over 7
      // decided days → 88.57%. Rest days stay out of both sides.
      final recorded = weekOf(lastWeek, [
        DayOutcome.full,
        DayOutcome.full,
        DayOutcome.full,
        DayOutcome.full,
        DayOutcome.full,
        DayOutcome.minimum,
        DayOutcome.minimum,
      ]);
      final review = MomentumEngine.weeklyReview(
        commitments: [commitment()],
        recorded: {'run': recorded},
        pauses: const [],
        anyDayInWeek: lastWeek,
      );
      expect(review.decidedDays, MomentumEngine.minDecidedDaysForRate);
      expect(review.minimumDays, 2);
      expect(review.rate, closeTo(88.57, 0.01));
    });

    test('archived commitments are left out of the review', () {
      final archived = commitment(id: 'old').copyWith(archived: true);
      final review = MomentumEngine.weeklyReview(
        commitments: [commitment(), archived],
        recorded: const {},
        pauses: const [],
        anyDayInWeek: today,
      );
      expect(review.commitments.length, 1);
      expect(review.commitments.first.name, 'Run');
    });
  });

  group('day keys are local calendar days', () {
    test('midnight is the boundary, not UTC', () {
      final lateNight = dayKey(DateTime(2026, 3, 7, 23, 59, 59));
      final nextMorning = dayKey(DateTime(2026, 3, 8, 0, 0, 1));
      expect(daysBetweenKeys(lateNight, nextMorning), 1);
    });

    test('400 consecutive keys are 400 unique consecutive days (DST-safe)', () {
      var day = dayKey(DateTime(2026, 3, 1));
      final seen = <int>{};
      for (var i = 0; i < 400; i++) {
        seen.add(day);
        final next = nextDayKey(day);
        expect(
          daysBetweenKeys(day, next),
          1,
          reason: 'stepping a day must always move exactly one calendar day, even across DST',
        );
        expect(previousDayKey(next), day, reason: 'stepping must round-trip');
        day = next;
      }
      expect(seen.length, 400, reason: 'no day may repeat or be skipped');
    });

    test('weekStartKey always lands on a Monday', () {
      for (var i = 0; i < 21; i++) {
        final d = daysAgo(i);
        expect(weekdayOfDayKey(weekStartKey(d)), 1);
      }
    });
  });
}
