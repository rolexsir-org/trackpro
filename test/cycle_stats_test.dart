import 'package:flutter_test/flutter_test.dart';
import 'package:track/data/cycle_stats.dart';

/// Cycle statistics: the rules about **when a period prediction is allowed to exist**.
///
/// `lib/data/cycle_stats.dart` derives everything from logged flow days and nothing else.
/// Two of its behaviours were live defects, and both are the same mistake in opposite
/// directions — the file said "not enough data" when there was enough, and it predicted a
/// period starting *today* when there was not. A health prediction is a claim about a
/// person's body, so the tests here pin the gate (`hasPrediction`) rather than the layout:
/// every widget that shows a date is allowed to trust it.
///
/// Series indices in this file are literal day offsets, oldest first, so a gap of 40 in the
/// input is a gap of 40 in the output. That is the whole contract `fromSeries` has.
///
/// Not executed in the environment that wrote them (no Flutter SDK). Run with:
///   flutter test test/cycle_stats_test.dart
void main() {
  /// A series of [length] days with a flow run of [runLength] starting at [start].
  List<double> flows(int length, List<(int, {int runLength})> runs) {
    final s = List<double>.filled(length, 0);
    for (final (start, runLength: runLength) in runs) {
      for (var i = 0; i < runLength; i++) {
        s[start + i] = 3; // intensity 3 of 1..5: a mid-range logged day
      }
    }
    return s;
  }

  group('no data says so, in words the user can act on', () {
    test('an empty series produces no starts, no prediction and no dates', () {
      final stats = CycleStats.fromSeries(const []);
      expect(stats.hasAnyData, isFalse);
      expect(stats.cycleCount, 0);
      expect(stats.hasPrediction, isFalse);
      expect(stats.nextWindow, isNull);
      expect(stats.fertileWindow, isNull);
      expect(stats.summary, contains('No period logged yet'));
    });

    test('one logged day is not "not enough data" in the dismissive sense', () {
      // The copy matters here: a user who logged their first period had logged
      // something. The old line told them to log more, which was both false and the
      // kind of message that ends a habit on day one.
      final stats = CycleStats.fromSeries(flows(30, [(10, runLength: 4)]));
      expect(stats.hasAnyData, isTrue);
      expect(stats.cycleCount, 1);
      expect(stats.hasPrediction, isFalse, reason: 'one start cannot make a cycle length');
      expect(stats.summary, contains('Prediction appears after the next cycle starts'));
      expect(stats.nextWindow, isNull);
    });
  });

  group('two starts are the minimum, and the gap has to be usable', () {
    test('a plausible gap becomes a range, never a single promised date', () {
      final stats = CycleStats.fromSeries(flows(100, [(10, runLength: 5), (50, runLength: 4)]));
      expect(stats.cycleCount, 2);
      // 40 days between starts, inside the 15..60 window the file accepts.
      expect(stats.averageLength, 40);
      expect(stats.shortestLength, 40);
      expect(stats.longestLength, 40);
      expect(stats.hasPrediction, isTrue);
      expect(stats.nextWindow, (90, 90), reason: 'last start (50) + the user\'s own shortest..longest');
      expect(stats.fertileWindow, (71, 76), reason: 'the 5-day window ending 14 days before the next start');
      expect(stats.summary, contains('average 40 days'));
    });

    test('an implausible gap yields no prediction, and says which it is', () {
      // Two starts 300 days apart are two data points of nothing: the 15..60 filter
      // rejects the gap, `shortestLength` stays 0 — and `hasPrediction` used to be
      // `starts.length >= 2`, which then predicted a period starting on the last logged
      // day. That is the defect this test exists to keep: an invented cycle.
      final stats = CycleStats.fromSeries(flows(320, [(10, runLength: 3), (310, runLength: 3)]));
      expect(stats.cycleCount, 2, reason: 'the data is there; only the prediction is not owed');
      expect(stats.shortestLength, 0);
      expect(stats.hasPrediction, isFalse);
      expect(stats.nextWindow, isNull);
      expect(stats.fertileWindow, isNull);
      expect(stats.summary, contains('outside a usable range'));
      expect(stats.summary, isNot(contains('No period logged yet')));
    });

    test('a 14-day gap is too short to be a cycle and is refused the same way', () {
      final stats = CycleStats.fromSeries(flows(60, [(10, runLength: 3), (24, runLength: 3)]));
      expect(stats.hasPrediction, isFalse,
          reason: '15 days is the floor the file sets, for bleeding/spotting confusion');
      expect(stats.summary, contains('outside a usable range'));
    });
  });

  group('a run of flow days is one period', () {
    test('consecutive days do not count as separate starts', () {
      final stats = CycleStats.fromSeries(flows(100, [(10, runLength: 6), (50, runLength: 1)]));
      expect(stats.cycleCount, 2, reason: 'six logged days are one period, not six');
      expect(stats.averageLength, 40);
      expect(stats.periodLengthAvg, 3.5, reason: 'the mean of the two runs (6 and 1)');
    });

    test('a run longer than 14 days does not set the period length', () {
      // `completedRuns` filters to `> 0 && <= 14`: a 20-day "flow" record is a data
      // problem, not a 20-day period, and averaging it would report the user as
      // unusually long-flowing on the strength of a mistap.
      final stats = CycleStats.fromSeries(flows(100, [(10, runLength: 20), (60, runLength: 4)]));
      expect(stats.periodLengthAvg, 4, reason: 'only the plausible run counts');
      expect(stats.cycleCount, 2, reason: 'but the start still counts as a start');
    });
  });

  group('irregularity is measured, not smoothed', () {
    test('variability is the spread of this user\'s own gaps', () {
      final stats = CycleStats.fromSeries(flows(200, [
        (10, runLength: 4),
        (38, runLength: 4), // 28
        (80, runLength: 4), // 42
      ]));
      expect(stats.shortestLength, 28);
      expect(stats.longestLength, 42);
      expect(stats.variability, 14);
      expect(stats.isIrregular, isTrue);
      expect(stats.summary, contains('vary by 14 days'));
      expect(stats.summary, isNot(contains('28 days')),
          reason: 'the population average must never be presented as this person\'s cycle');
    });

    test('a 0-8 day spread is regular for them', () {
      final stats = CycleStats.fromSeries(flows(200, [
        (10, runLength: 4),
        (38, runLength: 4), // 28
        (68, runLength: 4), // 30
      ]));
      expect(stats.variability, 2);
      expect(stats.isIrregular, isFalse);
      expect(stats.hasPrediction, isTrue);
      expect(stats.nextWindow, (96, 98), reason: 'shortest..longest from the last start');
    });
  });

  test('the current cycle day counts from the last logged start', () {
    final stats = CycleStats.fromSeries(flows(100, [(50, runLength: 4)]));
    expect(stats.currentCycleDay, 50, reason: '100 days of series, last start at index 50');
    // The 1-based day-within-cycle the detail screen shows: a woman who logged a start
    // yesterday is on day 2, not day 1, and not day 0.
    expect(stats.lastStart, 50);
  });
}
