import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/models.dart';
import 'day_key.dart';

/// Formats a raw metric value for display, per metric kind.
String fmtValue(Tracker t, double v) {
  switch (t.kind) {
    case MetricKind.volume:
      return v >= 1000 ? '${_trim(v / 1000)} L' : '${v.round()} ml';
    case MetricKind.money:
      return '₹${_group(v.round())}';
    case MetricKind.hours:
      return '${_trim(v)} h';
    case MetricKind.minutes:
      // Round once, then split. Splitting an unrounded `v ~/ 60` against a rounded
      // `v.round() % 60` disagreed with itself: 59.5 minutes was "0 hours" and
      // "60 % 60 = 0 minutes", so half an hour of screen time rendered as `0m`.
      final total = v.round();
      final h = total ~/ 60, m = total % 60;
      return h > 0 ? '${h}h ${m}m' : '${m}m';
    case MetricKind.weight:
      return '${v.toStringAsFixed(1)} kg';
    case MetricKind.mood:
      return const ['Poor', 'Fair', 'Okay', 'Good', 'Great'][v.round().clamp(1, 5).toInt() - 1];
    case MetricKind.cycle:
      return 'Day ${v.round()}';
    case MetricKind.habits:
      return '${v.round()}';
    default:
      return _group(v.round());
  }
}

/// Compact form used inside the small dashboard rings.
String fmtCompact(Tracker t, double v) {
  switch (t.kind) {
    case MetricKind.volume:
      return (v / 1000).toStringAsFixed(1);
    case MetricKind.money:
      return '₹${(v / 1000).toStringAsFixed(1)}k';
    case MetricKind.minutes:
      final total = v.round();
      final h = total ~/ 60, m = total % 60;
      return m == 0 ? '${h}h' : '${h}h${m.toString().padLeft(2, '0')}';
    case MetricKind.cycle:
      return 'D${v.round()}';
    case MetricKind.weight:
      return v.toStringAsFixed(1);
    case MetricKind.mood:
      return fmtValue(t, v);
    case MetricKind.hours:
      return _trim(v);
    default:
      return _group(v.round());
  }
}

/// Unit line printed under the ring value on dashboard cards.
String fmtGoalShort(Tracker t) {
  switch (t.kind) {
    case MetricKind.volume:
      return 'of ${_trim(t.goal / 1000)} L';
    case MetricKind.money:
      return 'of ₹${(t.goal / 1000).toStringAsFixed(1)}k';
    case MetricKind.minutes:
      return '${t.goal.round() ~/ 60}h limit';
    case MetricKind.cycle:
      return '28-day cycle';
    case MetricKind.weight:
      return '${t.goal.toStringAsFixed(0)} kg goal';
    case MetricKind.mood:
      return 'avg 4+';
    default:
      return 'of ${_group(t.goal.round())}';
  }
}

String fmtGoalLong(Tracker t) {
  switch (t.kind) {
    case MetricKind.volume:
      return '${_trim(t.goal / 1000)} L';
    case MetricKind.money:
      return '₹${_group(t.goal.round())}/day';
    case MetricKind.hours:
      return '${_trim(t.goal)} h';
    case MetricKind.minutes:
      return '${t.goal.round() ~/ 60}h limit';
    case MetricKind.weight:
      return '${t.goal.toStringAsFixed(0)} kg goal';
    case MetricKind.cycle:
      return '28-day cycle';
    case MetricKind.mood:
      return 'avg 4+';
    default:
      return _group(t.goal.round());
  }
}

/// Ring fill 0..1. Budget-style trackers (spend, screen time) fill as they go.
double ringPct(Tracker t, double v) {
  // The series is gap-filled with zeros, so a value of zero means "nothing was
  // logged", not "a logged zero". For every track scored as value ÷ goal that is
  // already 0 %, but weight is scored as distance from a goal, where a bare zero
  // evaluated to 1.0 — a *completed* ring for a day nobody weighed themselves, on
  // whatever surface drew the ring. Nothing logged is nothing.
  if (v <= 0) return 0;
  switch (t.id) {
    case 'weight':
      return (1 - (v - t.goal) / 6).clamp(0.0, 1.0).toDouble();
    case 'period':
      return (v / 28).clamp(0.0, 1.0).toDouble();
    case 'mood':
      return (v / 5).clamp(0.0, 1.0).toDouble();
    default:
      return (v / t.goal).clamp(0.0, 1.14).toDouble();
  }
}

class Delta {
  const Delta(this.text, this.direction, this.goodness);

  final String text;
  final int direction; // 1 up, -1 down, 0 flat
  final int goodness; // 1 good (green), -1 bad (orange), 0 neutral (grey)
}

/// True on trackers where a logged zero is a real answer — "spent nothing",
/// "no screen time", "did none of the habits", "not on my period". Every other
/// tracker's zero comes from gap-filling a missing day, so it is not a value: it
/// must never be averaged in, and it must never be read as a completed ring.
bool zeroIsAValue(Tracker t) => t.id == 'expenses' || t.id == 'screen' || t.id == 'habits' || t.id == 'period';

/// Today vs the 7-day average, with tracker-aware "is this good?" logic.
///
/// The average is taken over **days that were actually logged**. Gap-filling puts a
/// zero in every unfilled day, and averaging those in turned one logged day into a
/// week-long average diluted by zeros: on a fresh install the "vs week avg" line
/// compared today against a week of nothing and called it a rise. When no previous
/// day was logged, there is nothing to compare — and that is what the label says.
Delta deltaOf(Tracker t, List<double> hist) {
  // No series (a tracker the projection does not carry) is not a flat delta of
  // zero — it is nothing to compare yet.
  if (hist.isEmpty) return const Delta('No entries yet', 0, 0);
  final today = hist.last;
  final prev = hist.sublist(0, hist.length - 1);
  final logged = zeroIsAValue(t)
      ? prev
      : [
          for (final v in prev)
            if (v > 0) v,
        ];
  final window = logged.length >= 7 ? logged.sublist(logged.length - 7) : logged;
  if (window.isEmpty) return const Delta('First entry — nothing to compare yet', 0, 0);
  final avg = window.reduce((a, b) => a + b) / window.length;
  final diff = today - avg;
  if (t.id == 'period') return Delta('day ${today.round()} · next in ${28 - today.round()} days', 0, 0);

  final money = t.kind == MetricKind.money, mins = t.kind == MetricKind.minutes;
  final unit = mins
      ? 'm'
      : t.kind == MetricKind.volume
      ? 'ml'
      : t.kind == MetricKind.hours
      ? 'h'
      : '';
  // `_magnitude`, not `int.parse`: the previous version ran `int.parse` over a
  // one-decimal string ("500.0"), which throws, so every water, steps, sleep,
  // calories or weight card that had a comparison crashed before it could draw.
  // (No test had ever been executed on that path — see docs/TEST_RESULTS.md.)
  final text = money
      ? '₹${_group(diff.abs().round())} vs week avg'
      : '${_magnitude(diff)}${unit.isEmpty ? '' : ' $unit'} vs week avg';
  if (diff.abs() < .04) return Delta(text, 0, 0);

  final inverse = t.id == 'expenses' || t.id == 'screen';
  final good = inverse || t.id == 'weight' ? (diff < 0 ? 1 : -1) : (diff > 0 ? 1 : 0);
  if (t.id == 'weight') {
    return Delta('${diff.abs().toStringAsFixed(1)} kg vs last week', diff > 0 ? 1 : -1, good);
  }
  return Delta(text, diff > 0 ? 1 : -1, good);
}

/// Consecutive days at/over 70% of goal — the retention mechanic.
int streakOf(Tracker t, List<double> hist) {
  var n = 0;
  for (var i = hist.length - 1; i >= 0; i--) {
    if (ringPct(t, hist[i]) >= .7) {
      n++;
    } else {
      break;
    }
  }
  return n;
}

/// Composite 0..1 score per day, powers the consistency chart on Insights.
double activityScore(List<Tracker> trackers, Map<String, List<double>> data, int i) {
  var hits = 0.0;
  for (final t in trackers) {
    // A tracker with no cached series, or one shorter than this slot, contributes
    // no hit — rather than throwing out of the middle of a chart build.
    final series = data[t.id];
    final v = (series != null && i < series.length) ? series[i] : 0;
    if (t.id == 'expenses' || t.id == 'screen') {
      hits += v <= t.goal ? 1 : .35;
    } else if (t.id == 'period' || t.id == 'weight') {
      // A cycle-day marker and a weigh-in are facts about a day, not a fraction of a
      // target, so the only question is whether anything was recorded. Both used to
      // add a whole point **unconditionally**, which meant an install that merely
      // *owns* these two trackers scored every blank day at 2/N: the "daily
      // activity" chart could never reach zero, and a day where the user logged
      // nothing at all looked partly productive.
      hits += v > 0 ? 1 : 0;
    } else {
      hits += ringPct(t, v).clamp(0.0, 1.0).toDouble();
    }
  }
  return trackers.isEmpty ? 0 : hits / trackers.length;
}

/// A magnitude for a comparison label: grouped whole numbers for the big ones
/// ("1,200"), one decimal for the small ones a digit of resolution matters to
/// ("0.5 h", "2.5 kg").
String _magnitude(double v) {
  final a = v.abs();
  return a < 100 ? a.toStringAsFixed(1) : _group(a.round());
}

String _trim(double v) {
  final s = v.toStringAsFixed(2);
  return s.replaceAll(RegExp(r'\.?0+$'), '');
}

String _group(int v) {
  final s = v.abs().toString();
  if (s.length <= 3) return v.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return (v < 0 ? '-' : '') + buf.toString();
}

String weekdayShort(DateTime d) => const ['S', 'M', 'T', 'W', 'T', 'F', 'S'][d.weekday % 7];

String shortDate(DateTime d) =>
    '${d.day} ${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][d.month - 1]}';

String longDate(DateTime d) {
  const wd = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  const mo = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${wd[d.weekday - 1]}, ${d.day} ${mo[d.month - 1]}';
}

String greetingFor(DateTime now) {
  final h = now.hour;
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  if (h < 22) return 'Good evening';
  return 'Good night';
}

/// Soft, low-saturation variants used for tinted chips/rings.
Color tint(Color c, double amount) =>
    Color.lerp(c, Colors.white, amount.clamp(0.0, 1.0).toDouble())!.withValues(alpha: .9);

Color alpha(Color c, double a) => c.withValues(alpha: a.clamp(0.0, 1.0).toDouble());

double lerp(double a, double b, double t) => a + (b - a) * t;

double jitter(math.Random r, double base, double spread) => base + (r.nextDouble() * 2 - 1) * spread;

/// "just now" / "5m ago" / "3h ago" / "yesterday" / "7 Mar" — for "last synced"
/// labels, where an exact timestamp is noise and silence is ambiguous.
///
/// [now] is injectable so the rules are testable without a fake clock. Elapsed
/// time below a day is measured on the clock; the day boundary itself is
/// calendar-based (`day_key.dart`'s rule), so "yesterday" survives a DST shift.
String fmtRelativeTime(DateTime then, {DateTime? now}) {
  final ref = now ?? DateTime.now();
  if (!then.isAfter(ref)) {
    final seconds = ref.difference(then).inSeconds;
    if (seconds < 60) return 'just now';
    final minutes = seconds ~/ 60;
    if (minutes < 60) return '${minutes}m ago';
    final hours = minutes ~/ 60;
    if (hours < 24 && dayKey(then) == dayKey(ref)) return '${hours}h ago';
  }
  final days = shiftDayKey(dayKey(ref), -1);
  if (dayKey(then) == days) return 'yesterday';
  return shortDate(then);
}
