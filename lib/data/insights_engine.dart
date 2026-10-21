import 'dart:math' as math;

import '../models/models.dart';
import '../util/day_key.dart';
import 'cycle_stats.dart';

/// A computed statement about the user's own data.
///
/// Nothing here is authored copy: every insight carries the sample size it was
/// derived from, and is suppressed entirely when the data cannot support it. An
/// insight that cannot be justified by rows in the database is not shown.
class Insight {
  const Insight({
    required this.emoji,
    required this.title,
    required this.body,
    required this.sampleDays,
    this.advanced = false,
    this.kind = InsightKind.summary,
  });

  final String emoji;
  final String title;
  final String body;

  /// How many days of real data back this statement.
  final int sampleDays;

  /// True when this insight required Pro-depth analysis.
  final bool advanced;

  final InsightKind kind;
}

enum InsightKind { summary, average, correlation, trend, rhythm, cycle, habit }

/// Turns the stored series into statements, or into nothing.
///
/// Design rules, in order of importance:
/// 1. **No data, no insight.** Below [minLoggedDaysForPatterns] the engine returns
///    only a progress statement ("3 of 14 days"), never a conclusion.
/// 2. **Correlation is stated as association**, with the coefficient and the
///    sample size shown, and a standing note that it is not causation.
/// 3. **Every number is recomputed over the days that were actually logged.**
///    A blank day is not a zero; treating it as one is how a tracker ends up
///    telling a user they slept 4 hours on a night they simply forgot to log.
class InsightsEngine {
  const InsightsEngine._();

  /// Days of logged data before *any* pattern is claimed.
  static const int minLoggedDaysForPatterns = 14;

  /// Minimum overlapping logged days before a correlation is reported.
  static const int minPairsForCorrelation = 10;

  /// |r| below this is noise dressed as a finding.
  static const double minAbsCorrelation = 0.35;

  /// Minimum logged days before a linear trend is drawn.
  static const int minPointsForTrend = 8;

  static List<Insight> compute({
    required Map<String, List<double>> history,
    required List<Tracker> trackers,
    required bool advanced,
    CycleStats? cycle,
  }) {
    final out = <Insight>[];

    final loggedByTracker = <String, List<bool>>{
      for (final t in trackers) t.id: [for (final v in history[t.id] ?? const <double>[]) v > 0],
    };

    final totalLoggedDays = _distinctLoggedDays(loggedByTracker);
    final window = history.values.isEmpty ? 0 : history.values.first.length;

    out.add(_progressInsight(totalLoggedDays, window));

    // Not enough real history to say anything about behaviour. Stop here rather
    // than padding the screen with plausible-sounding filler.
    if (totalLoggedDays < minLoggedDaysForPatterns) return out;

    out.addAll(_averages(history, trackers, loggedByTracker));
    out.add(_consistency(loggedByTracker, trackers, window));

    if (advanced) {
      out.addAll(_correlations(history, loggedByTracker));
      out.addAll(_weekdayRhythms(history, trackers, loggedByTracker));
      final trend = _weightTrend(history['weight'] ?? const <double>[], loggedByTracker['weight'] ?? const <bool>[]);
      if (trend != null) out.add(trend);
    }

    if (cycle != null && cycle.hasPrediction) {
      out.add(
        Insight(
          emoji: '🌸',
          title: 'Cycle pattern',
          body: cycle.summary,
          sampleDays: cycle.cycleCount * cycle.averageLength.round(),
          kind: InsightKind.cycle,
          advanced: false,
        ),
      );
    }

    return out;
  }

  // ------------------------------------------------------------------ helpers
  static int _distinctLoggedDays(Map<String, List<bool>> byTracker) {
    final length = byTracker.values.isEmpty ? 0 : byTracker.values.first.length;
    var n = 0;
    for (var i = 0; i < length; i++) {
      for (final flags in byTracker.values) {
        if (i < flags.length && flags[i]) {
          n++;
          break;
        }
      }
    }
    return n;
  }

  static Insight _progressInsight(int logged, int window) {
    if (logged == 0) {
      return const Insight(
        emoji: '🌱',
        title: 'Nothing logged yet',
        body:
            'Your first entry starts the history. Patterns need about two weeks of real days '
            'before they mean anything — this app will not invent them in the meantime.',
        sampleDays: 0,
        kind: InsightKind.summary,
      );
    }
    final remaining = math.max(0, minLoggedDaysForPatterns - logged);
    return Insight(
      emoji: '📅',
      title: '$logged of the last $window days logged',
      body: remaining == 0
          ? 'Enough history for real patterns. Everything below is computed from your days only.'
          : '$remaining more logged days and the pattern detection switches on. Until then, no guesses.',
      sampleDays: logged,
      kind: InsightKind.summary,
    );
  }

  static List<Insight> _averages(
    Map<String, List<double>> history,
    List<Tracker> trackers,
    Map<String, List<bool>> logged,
  ) {
    final out = <Insight>[];
    for (final t in trackers) {
      final values = history[t.id] ?? const <double>[];
      final flags = logged[t.id] ?? const <bool>[];
      if (values.isEmpty || flags.isEmpty) continue;
      final loggedValues = <double>[];
      for (var i = 0; i < values.length; i++) {
        if (i < flags.length && flags[i]) loggedValues.add(values[i]);
      }
      if (loggedValues.length < 3) continue;

      final avg = loggedValues.reduce((a, b) => a + b) / loggedValues.length;
      final pct = t.goal <= 0 ? 0 : (avg / t.goal * 100).round();
      out.add(
        Insight(
          emoji: t.emoji,
          title: '${t.name} averages ${_fmt(t, avg)} over ${loggedValues.length} logged days',
          body: pct == 0
              ? 'Goal is not set yet, so this is your own baseline rather than a score.'
              : 'That is $pct% of your ${_fmt(t, t.goal)} goal, counting only days you logged.',
          sampleDays: loggedValues.length,
          kind: InsightKind.average,
        ),
      );
    }
    return out;
  }

  static Insight _consistency(Map<String, List<bool>> logged, List<Tracker> trackers, int window) {
    var best = trackers.first;
    var bestCount = -1;
    for (final t in trackers) {
      final c = (logged[t.id] ?? const <bool>[]).where((f) => f).length;
      if (c > bestCount) {
        bestCount = c;
        best = t;
      }
    }
    final pct = window == 0 ? 0 : (bestCount / window * 100).round();
    return Insight(
      emoji: '🎯',
      title: '${best.name} is your most consistent tracker',
      body: '$bestCount of $window days logged ($pct%). Consistency is what makes the rest of the data readable.',
      sampleDays: bestCount,
      kind: InsightKind.rhythm,
    );
  }

  /// Pearson correlation over days where **both** series were logged.
  ///
  /// Returns null unless the overlap clears both the sample-size and the effect
  /// thresholds, so a spurious r=0.6 over four days never reaches the screen.
  static (double r, int n)? correlate(List<double> a, List<double> b, List<bool> aLogged, List<bool> bLogged) {
    final xs = <double>[];
    final ys = <double>[];
    for (var i = 0; i < a.length && i < b.length; i++) {
      final aHas = i < aLogged.length && aLogged[i];
      final bHas = i < bLogged.length && bLogged[i];
      if (!aHas || !bHas) continue;
      xs.add(a[i]);
      ys.add(b[i]);
    }
    final n = xs.length;
    if (n < minPairsForCorrelation) return null;

    final mx = xs.reduce((p, q) => p + q) / n;
    final my = ys.reduce((p, q) => p + q) / n;
    var sxy = 0.0, sxx = 0.0, syy = 0.0;
    for (var i = 0; i < n; i++) {
      final dx = xs[i] - mx;
      final dy = ys[i] - my;
      sxy += dx * dy;
      sxx += dx * dx;
      syy += dy * dy;
    }
    if (sxx <= 0 || syy <= 0) return null; // a flat series has no relationship
    final r = sxy / math.sqrt(sxx * syy);
    if (r.abs() < minAbsCorrelation) return null;
    return (r, n);
  }

  static List<Insight> _correlations(Map<String, List<double>> history, Map<String, List<bool>> logged) {
    // Pairs the product promises to look at, phrased as questions, not claims.
    const pairs = <List<String>>[
      ['sleep', 'mood'],
      ['steps', 'mood'],
      ['water', 'mood'],
      ['screen', 'sleep'],
      ['expenses', 'mood'],
      ['sleep', 'steps'],
    ];
    final out = <Insight>[];
    for (final pair in pairs) {
      final a = history[pair[0]];
      final b = history[pair[1]];
      if (a == null || b == null) continue;
      final result = correlate(a, b, logged[pair[0]] ?? const <bool>[], logged[pair[1]] ?? const <bool>[]);
      if (result == null) continue;
      final (r, n) = result;
      final positive = r > 0;
      out.add(
        Insight(
          emoji: positive ? '↗️' : '↘️',
          title: '${_label(pair[0])} and ${_label(pair[1])} move together ${positive ? 'upward' : 'downward'}',
          body:
              'Across the $n days where you logged both, days with more ${_label(pair[0]).toLowerCase()} tended to have '
              '${positive ? 'higher' : 'lower'} ${_label(pair[1]).toLowerCase()} (r = ${r.toStringAsFixed(2)}). '
              'That is an association in your own data, not proof of cause.',
          sampleDays: n,
          advanced: true,
          kind: InsightKind.correlation,
        ),
      );
    }
    return out;
  }

  static List<Insight> _weekdayRhythms(
    Map<String, List<double>> history,
    List<Tracker> trackers,
    Map<String, List<bool>> logged,
  ) {
    final out = <Insight>[];
    final length = history.values.isEmpty ? 0 : history.values.first.length;
    if (length < 21) return out; // three weeks before weekdays mean anything

    for (final t in trackers) {
      final values = history[t.id] ?? const <double>[];
      final flags = logged[t.id] ?? const <bool>[];
      final sums = List<double>.filled(7, 0);
      final counts = List<int>.filled(7, 0);
      for (var i = 0; i < values.length; i++) {
        if (i >= flags.length || !flags[i]) continue;
        final dow = _weekdayOfSlot(i, length);
        sums[dow] += values[i];
        counts[dow]++;
      }
      // Every weekday needs at least three real observations.
      if (counts.any((c) => c < 3)) continue;
      final avgs = [for (var d = 0; d < 7; d++) sums[d] / counts[d]];
      final maxD = avgs.indexOf(avgs.reduce(math.max));
      final minD = avgs.indexOf(avgs.reduce(math.min));
      if (maxD == minD) continue;
      final spread = (avgs[maxD] - avgs[minD]) / (avgs[minD] == 0 ? 1 : avgs[minD]);
      if (spread < .15) continue; // under 15% is noise, not a rhythm
      out.add(
        Insight(
          emoji: t.emoji,
          title: '${t.name} peaks on ${_weekdayName(maxD)}s',
          body:
              'Your ${_weekdayName(maxD)} average is ${_fmt(t, avgs[maxD])} versus ${_fmt(t, avgs[minD])} '
              'on ${_weekdayName(minD)}s, across ${counts[maxD]} ${_weekdayName(maxD)}s and ${counts[minD]} '
              '${_weekdayName(minD)}s you logged.',
          sampleDays: counts.fold(0, (p, c) => p + c),
          advanced: true,
          kind: InsightKind.rhythm,
        ),
      );
      if (out.length >= 2) break; // two weekday findings is plenty
    }
    return out;
  }

  /// Least-squares slope over the days a weight was actually recorded, reported
  /// in kg/week. Refuses to draw a trend from sporadic weigh-ins.
  static Insight? _weightTrend(List<double> values, List<bool> logged) {
    final xs = <double>[];
    final ys = <double>[];
    for (var i = 0; i < values.length; i++) {
      if (i < logged.length && logged[i]) {
        xs.add(i.toDouble());
        ys.add(values[i]);
      }
    }
    if (xs.length < minPointsForTrend) return null;
    final n = xs.length;
    final mx = xs.reduce((a, b) => a + b) / n;
    final my = ys.reduce((a, b) => a + b) / n;
    var sxy = 0.0, sxx = 0.0;
    for (var i = 0; i < n; i++) {
      sxy += (xs[i] - mx) * (ys[i] - my);
      sxx += (xs[i] - mx) * (xs[i] - mx);
    }
    if (sxx <= 0) return null;
    final slopePerDay = sxy / sxx;
    final perWeek = slopePerDay * 7;
    if (perWeek.abs() < .05) {
      return Insight(
        emoji: '⚖️',
        title: 'Weight is holding steady',
        body:
            'Across the $n days you weighed in, the trend is flat (${perWeek.toStringAsFixed(2)} kg/week). '
            'Weight fluctuates daily, so a flat line over weeks is a real result.',
        sampleDays: n,
        advanced: true,
        kind: InsightKind.trend,
      );
    }
    return Insight(
      emoji: '⚖️',
      title: 'Weight trend ${perWeek < 0 ? 'down' : 'up'} ${perWeek.abs().toStringAsFixed(2)} kg per week',
      body: 'Fitted across the $n days you actually weighed in — not an estimate for the days you skipped.',
      sampleDays: n,
      advanced: true,
      kind: InsightKind.trend,
    );
  }

  static String _fmt(Tracker t, double v) => switch (t.kind) {
    MetricKind.volume => '${(v / 1000).toStringAsFixed(1)} L',
    MetricKind.money => '₹${v.round()}',
    MetricKind.hours => '${v.toStringAsFixed(1)} h',
    MetricKind.weight => '${v.toStringAsFixed(1)} kg',
    MetricKind.mood => v.toStringAsFixed(1),
    MetricKind.minutes => '${v.round()} min',
    _ => '${v.round()}',
  };

  static String _label(String id) => switch (id) {
    'sleep' => 'Sleep',
    'mood' => 'Mood',
    'water' => 'Water',
    'steps' => 'Steps',
    'screen' => 'Screen time',
    'expenses' => 'Spending',
    _ => id,
  };

  static String _weekdayName(int dow) =>
      const ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'][dow];

  /// Slot index → weekday. `i == length - 1` is today, so the mapping stays
  /// correct regardless of what day the app happens to run on.
  static int _weekdayOfSlot(int i, int length) => weekdayOfDayKey(dayKeyFromToday(length - 1 - i)) % 7;
}

/// Milestones are a function of real accumulated data — never a fixed list with
/// a "7 days left" label that nobody checked.
class Milestones {
  const Milestones._();

  static List<Milestone> compute({
    required int trackedDays,
    required int bestStreak,
    required int entryCount,
    required int cycleCount,
    required bool hasHealthData,
  }) {
    Milestone m(String emoji, String title, int have, int need) =>
        Milestone(emoji, title, have >= need ? 'Unlocked' : '${need - have} days to go', have >= need);

    return <Milestone>[
      m('🔥', '7-day streak', bestStreak, 7),
      m('🏅', '30-day streak', bestStreak, 30),
      m('📅', 'Two weeks tracked', trackedDays, 14),
      Milestone(
        '📓',
        '100 entries logged',
        entryCount >= 100 ? 'Unlocked' : '${100 - entryCount} entries to go',
        entryCount >= 100,
      ),
      Milestone('😴', 'Health Connect linked', hasHealthData ? 'Unlocked' : 'Connect in Settings', hasHealthData),
      Milestone('🌸', 'Two cycles logged', cycleCount >= 2 ? 'Unlocked' : 'Log 2 cycles', cycleCount >= 2),
    ];
  }
}
