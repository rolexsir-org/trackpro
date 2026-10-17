import 'dart:math' as math;

/// Menstrual-cycle statistics derived **only** from logged flow days.
///
/// Rules this file exists to enforce:
/// - No cycle is inferred from nothing. Fewer than two logged starts means
///   "not enough data", not a prediction.
/// - Every prediction is a **range**, never a date, and it is labelled as an
///   estimate derived from the user's own logged history.
/// - Regularity is reported as the actual variation in the user's data
///   (min–max), because "your cycle is 28 days" is a population average, not a
///   measurement of this person.
///
/// Pure functions over a day-indexed series, so they are unit-testable without a
/// database, a widget tree or a device.
class CycleStats {
  const CycleStats({
    required this.starts,
    required this.averageLength,
    required this.shortestLength,
    required this.longestLength,
    required this.lastStart,
    required this.currentCycleDay,
    required this.periodLengthAvg,
  });

  /// Day-index offsets (0-based, oldest first) where a new period began.
  final List<int> starts;
  final double averageLength;
  final int shortestLength;
  final int longestLength;

  /// Index of the most recent period start, or null when there is none.
  final int? lastStart;

  /// 1-based day within the current cycle, or null when no start is known.
  final int? currentCycleDay;

  /// Average number of consecutive flow days per cycle.
  final double periodLengthAvg;

  /// True when there is enough history for a prediction to mean anything.
  bool get hasPrediction => starts.length >= 2;

  /// True when the user has logged at least one period.
  bool get hasAnyData => starts.isNotEmpty;

  int get cycleCount => starts.length;

  /// Spread of the user's own cycles. 0–1 days is regular *for them*.
  int get variability => starts.length < 2 ? 0 : longestLength - shortestLength;

  /// Uneven cycles are worth saying out loud rather than predicting through.
  bool get isIrregular => variability >= 9;

  /// Predicted start of the next period as a day-index range (inclusive).
  /// Null when [hasPrediction] is false.
  (int, int)? get nextWindow {
    if (!hasPrediction || lastStart == null) return null;
    final lo = lastStart! + shortestLength;
    final hi = lastStart! + longestLength;
    return (lo, hi);
  }

  /// Predicted ovulation window (L phase ≈ 14 days before the next period), only
  /// when the data supports it. Deliberately a window, and clearly labelled as
  /// an estimate in the UI.
  (int, int)? get fertileWindow {
    final w = nextWindow;
    if (w == null) return null;
    return (w.$1 - 19, w.$1 - 14); // 5-day window ending 14 days before next start
  }

  /// Builds stats from a per-day series where `> 0` marks a flow day and the
  /// value is the logged intensity (1–5).
  ///
  /// [todayIndex] is the index of the newest day in [series], normally
  /// `series.length - 1`.
  static CycleStats fromSeries(List<double> series) {
    final starts = <int>[];
    var runStart = -1;
    var runLength = 0;
    final runLengths = <int>[];

    for (var i = 0; i < series.length; i++) {
      final flowing = series[i] > 0;
      if (flowing && runStart < 0) {
        runStart = i;
        runLength = 1;
      } else if (flowing) {
        runLength++;
      } else if (runStart >= 0) {
        starts.add(runStart);
        runLengths.add(runLength);
        runStart = -1;
        runLength = 0;
      }
    }
    if (runStart >= 0) {
      // An ongoing run counts as a start, but its length is unknown yet.
      starts.add(runStart);
      runLengths.add(runLength);
    }

    if (starts.isEmpty) {
      return const CycleStats(
        starts: [],
        averageLength: 0,
        shortestLength: 0,
        longestLength: 0,
        lastStart: null,
        currentCycleDay: null,
        periodLengthAvg: 0,
      );
    }

    final gaps = <int>[];
    for (var i = 1; i < starts.length; i++) {
      gaps.add(starts[i] - starts[i - 1]);
    }

    // Only gaps inside a plausible physiological range count, so a stray double
    // log or a forgotten month does not distort the average.
    final usable = gaps.where((g) => g >= 15 && g <= 60).toList();
    final avg = usable.isEmpty ? 0.0 : usable.reduce((a, b) => a + b) / usable.length;
    final lastStart = starts.last;
    final completedRuns = runLengths.where((r) => r > 0 && r <= 14).toList();
    final periodAvg = completedRuns.isEmpty
        ? 0.0
        : completedRuns.reduce((a, b) => a + b) / completedRuns.length;

    return CycleStats(
      starts: starts,
      averageLength: avg,
      shortestLength: usable.isEmpty ? 0 : usable.reduce(math.min),
      longestLength: usable.isEmpty ? 0 : usable.reduce(math.max),
      lastStart: lastStart,
      currentCycleDay: series.length - lastStart,
      periodLengthAvg: periodAvg,
    );
  }

  /// One-line summary for the UI. Honest about what is missing.
  String get summary {
    if (!hasAnyData) return 'No period logged yet — log your first day to start the pattern.';
    if (!hasPrediction) {
      return 'First day logged. Prediction appears after the next cycle starts.';
    }
    if (isIrregular) {
      return 'Your logged cycles vary by $variability days — a prediction here would be a guess.';
    }
    return 'Your logged cycles average ${averageLength.round()} days '
        '(${shortestLength}–${longestLength} in your data).';
  }
}
