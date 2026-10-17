import 'package:flutter_test/flutter_test.dart';
import 'package:track/data/default_trackers.dart';
import 'package:track/models/models.dart';
import 'package:track/util/format.dart';

/// Pure-Dart tests: the formatting and ring maths that every screen depends on.
/// These are the rules that make the UI read like iOS (tabular values, compact
/// ring labels, budget-aware deltas), so they deserve pinning.
void main() {
  final trackers = DefaultTrackers.all();
  Tracker byId(String id) => trackers.firstWhere((t) => t.id == id);

  group('formatting', () {
    test('volume switches to litres past 1000 ml', () {
      expect(fmtValue(byId('water'), 1750), '1.75 L');
      expect(fmtValue(byId('water'), 750), '750 ml');
      expect(fmtCompact(byId('water'), 2500), '2.5');
      expect(fmtGoalShort(byId('water')), 'of 2.5 L');
    });

    test('money is grouped the way the target market reads it', () {
      expect(fmtValue(byId('expenses'), 1240), '₹1,240');
      expect(fmtCompact(byId('expenses'), 1240), '₹1.2k');
      expect(fmtGoalLong(byId('expenses')), '₹1,500/day');
    });

    test('screen time and sleep render as h/m and h', () {
      expect(fmtValue(byId('screen'), 312), '5h 12m');
      expect(fmtCompact(byId('screen'), 240), '4h');
      expect(fmtValue(byId('sleep'), 7.3), '7.3 h');
    });

    test('mood and cycle have their own vocabularies', () {
      expect(fmtValue(byId('mood'), 4), '🙂');
      expect(fmtValue(byId('period'), 14), 'Day 14');
      expect(fmtGoalLong(byId('period')), '28-day cycle');
    });
  });

  group('rings', () {
    test('fill is proportional to the goal', () {
      expect(ringPct(byId('water'), 1250), closeTo(.5, .001));
      expect(ringPct(byId('steps'), 10000), closeTo(1, .001));
    });

    test('budget trackers fill as they approach the limit', () {
      expect(ringPct(byId('screen'), 120), closeTo(.5, .001));
      expect(ringPct(byId('expenses'), 3000), greaterThan(1));
    });

    test('weight ring closes as you approach the goal weight', () {
      expect(ringPct(byId('weight'), 70), 1);
      expect(ringPct(byId('weight'), 73), lessThan(1));
    });
  });

  group('deltas', () {
    test('spending up is bad (orange), spending down is good (green)', () {
      final up = deltaOf(byId('expenses'), const [1000, 1000, 1000, 1000, 1000, 1000, 1000, 1400]);
      final down = deltaOf(byId('expenses'), const [1000, 1000, 1000, 1000, 1000, 1000, 1000, 600]);

      expect(up.direction, 1);
      expect(up.goodness, -1);
      expect(down.direction, -1);
      expect(down.goodness, 1);
    });

    test('more water is good, a dip is neutral (never alarmed)', () {
      final up = deltaOf(byId('water'), const [1000, 1000, 1000, 1000, 1000, 1000, 1000, 2000]);
      final down = deltaOf(byId('water'), const [2000, 2000, 2000, 2000, 2000, 2000, 2000, 1000]);

      expect(up.goodness, 1);
      expect(down.goodness, 0);
      expect(down.text, contains('vs week avg'));
    });

    test('period reads as cycle position, not a delta', () {
      final d = deltaOf(byId('period'), List<double>.filled(8, 14));
      expect(d.text, 'day 14 · next in 14 days');
      expect(d.direction, 0);
    });

    test('a first entry is not compared against a week of gap-filled zeros', () {
      // Seven empty days, then the first weight: the old average diluted by zeros
      // made this read "72.5 kg vs last week" on a brand new install.
      final d = deltaOf(byId('weight'), const [0, 0, 0, 0, 0, 0, 0, 72.5]);
      expect(d.text, isNot(contains('vs last week')));
      expect(d.text, contains('nothing to compare'));
      expect(d.direction, 0);
      expect(d.goodness, 0, reason: 'no comparison is not a win');
    });

    test('unlogged days are left out of the average instead of counted as zero', () {
      // One real 8000-step day behind today's 9000: the truthful comparison is
      // 9000 vs 8000, not 9000 vs 8000/7.
      final d = deltaOf(byId('steps'), const [8000, 0, 0, 0, 0, 0, 0, 9000]);
      expect(d.text, contains('1,000'), reason: 'and the label is grouped, not a raw double');
    });

    test('on a tracker where zero is a real answer, zeros stay in the average', () {
      // Spending nothing is a logged value: six zero-spend days and a 700 day give
      // a real 100/day average.
      final d = deltaOf(byId('expenses'), const [0, 0, 0, 0, 0, 0, 0, 700]);
      expect(d.text, contains('vs week avg'));
      expect(d.direction, 1);
    });
  });

  test('streak counts consecutive days at 70% of goal', () {
    final water = byId('water');
    final allHit = List<double>.filled(10, 2500);
    final brokenTail = [2500, 2500, 2500, 500, 2500, 2500];

    expect(streakOf(water, allHit), 10);
    expect(streakOf(water, brokenTail), 2);
  });

  test('an unlogged day cannot supply a streak, on any tracker', () {
    // Weight's ring is distance-from-goal, which evaluated a bare zero to a
    // completed ring: a fresh install read "90 days" — and the ring looked full.
    expect(ringPct(byId('weight'), 0), 0);
    expect(streakOf(byId('weight'), List<double>.filled(90, 0)), 0);
    expect(streakOf(byId('mood'), List<double>.filled(90, 0)), 0);
    expect(ringPct(byId('water'), 0), 0);
  });

  test('greeting follows the time of day', () {
    expect(greetingFor(DateTime(2026, 10, 15, 8)), 'Good morning');
    expect(greetingFor(DateTime(2026, 10, 15, 14)), 'Good afternoon');
    expect(greetingFor(DateTime(2026, 10, 15, 19)), 'Good evening');
    expect(greetingFor(DateTime(2026, 10, 15, 23)), 'Good night');
  });
}
