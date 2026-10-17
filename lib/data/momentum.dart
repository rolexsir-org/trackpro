import '../models/models.dart';
import '../util/day_key.dart';

/// Momentum — the consistency engine.
///
/// This file is deliberately **pure**: it takes commitments, recorded days, pauses
/// and a "today" key, and returns numbers. No database, no clock, no
/// `DateTime.now()` inside a calculation, no randomness. That makes every rule
/// below testable, and it means the app cannot produce a figure its own inputs do
/// not support.
///
/// ---------------------------------------------------------------------------
/// VOCABULARY (shown to the user, in these words, on the Momentum screen)
/// ---------------------------------------------------------------------------
/// planned day   A day the commitment's schedule covers: the weekday is selected,
///               the day is on/after the day the commitment was created, and it is
///               not inside a pause. Nothing else is ever "planned".
/// recorded day  A planned day the user marked: full, minimum, rest or skipped.
/// decided day   A planned day that can be judged — every recorded day except
///               rest/skipped (excluded by design), plus every planned day in the
///               past with no record at all: silence on a day you said you would
///               act is a miss, and the app says so rather than quietly dropping
///               it. Today is never counted until it is over.
/// credit        full = 1.0, minimum = [minimumCredit], missed = 0.0.
/// momentum      total credit ÷ decided days, as a percentage. Reported **only**
///               once there are at least [minDecidedDaysForRate] decided days;
///               below that the screen shows "n of 7 days" and no percentage.
///
/// A minimum is *not* a completion. It keeps the chain alive and earns partial
/// credit; no surface in this app renders it as a full day — not the calendar,
/// not the streak, not the weekly review.
///
/// ---------------------------------------------------------------------------
/// WHAT THIS IS NOT
/// ---------------------------------------------------------------------------
/// It is not a discipline score, a willpower index or a scientific measure. It is
/// the arithmetic ratio of the days you did the thing to the days you said you
/// would, with rest and deliberate skips excluded rather than punished. The
/// Momentum screen prints the formula, the sample size and the window next to
/// every figure it shows.
class MomentumEngine {
  const MomentumEngine._();

  /// Credit for showing up at the minimum. Not 1.0 — a minimum is not a full
  /// completion — and not 0 — doing something is worth something.
  static const double minimumCredit = 0.6;

  /// Below this many decided days no rate is reported. Seven days is where a
  /// percentage stops being noise, and the number is stated in the UI.
  static const int minDecidedDaysForRate = 7;

  /// Consecutive missed planned days that trigger a restart plan.
  static const int recoveryGap = 3;

  /// Rolling window the headline rate is computed over.
  static const int rateWindowDays = 28;

  /// Sample sizes below which a pattern is withheld.
  static const int weekdayMinSample = 3;
  static const int improvementMinSample = 7;

  /// Improvement smaller than this (in percentage points) is not called progress.
  static const int improvementMinPoints = 10;

  // ------------------------------------------------------------------ schedule
  /// Whether [day] was a planned day for [c], using the schedule revision that was
  /// in force **on that day**. Changing the schedule today never rewrites the past:
  /// the revision that covered those days still governs them, so history keeps
  /// meaning what it meant when it happened.
  static bool isPlanned(Commitment c, int day, List<Pause> pauses) {
    if (day < c.createdDay) return false;
    final revision = c.scheduleInForceOn(day);
    if (revision == null || !revision.weekdays.contains(weekdayOfDayKey(day))) return false;
    for (final p in pauses) {
      if (p.commitmentId != c.id) continue;
      if (day < p.fromDay) continue;
      if (p.toDay == null || day <= p.toDay!) return false;
    }
    return true;
  }

  /// Every planned day in a range, inclusive of both ends.
  static List<int> plannedDays(Commitment c, List<Pause> pauses, {required int from, required int to}) {
    final out = <int>[];
    var day = from;
    var guard = 0;
    // Bounded: `to` is always a recent day, so this is a few hundred iterations at
    // most, and a corrupt key cannot spin the loop forever.
    while (day <= to && guard < 1000) {
      if (isPlanned(c, day, pauses)) out.add(day);
      day = nextDayKey(day);
      guard++;
    }
    return out;
  }

  // ------------------------------------------------------------------ snapshot
  static MomentumSnapshot compute({
    required Commitment c,
    required Map<int, CommitmentDay> recorded,
    required List<Pause> pauses,
    required int today,
  }) {
    // The window never starts before the commitment existed.
    var from = today;
    for (var i = 1; i < rateWindowDays; i++) {
      from = previousDayKey(from);
    }
    if (from < c.createdDay) from = c.createdDay;

    final planned = plannedDays(c, pauses, from: from, to: today);

    var decided = 0, full = 0, minimum = 0, missed = 0, excluded = 0;
    var credit = 0.0;

    for (final day in planned) {
      final outcome = recorded[day]?.outcome;
      if (day == today && outcome == null) continue; // still open, not a verdict
      switch (outcome) {
        case DayOutcome.full:
          decided++;
          full++;
          credit += 1;
          break;
        case DayOutcome.minimum:
          decided++;
          minimum++;
          credit += minimumCredit;
          break;
        case DayOutcome.missed:
          decided++;
          missed++;
          break;
        case DayOutcome.rest:
        case DayOutcome.skipped:
          excluded++; // a deliberate rest is not a failure and not a decision
          break;
        case null:
          // Planned, in the past, nothing recorded: counted as a miss. The user
          // said this day was planned and claimed no rest or skip.
          decided++;
          missed++;
          break;
      }
    }

    final rate = decided >= minDecidedDaysForRate ? credit / decided * 100 : null;

    // ---- streaks, walking backwards over planned days ------------------------
    // Rest, skip and unscheduled days neither extend nor break a streak: the user
    // did not commit to them. A miss breaks it. Today, still open, does not.
    var fullStreak = 0;
    var keepGoing = 0;
    var fullStreakOpen = true;
    var keepGoingOpen = true;
    var lastFull = 0;
    var longestFull = 0;
    var runningFull = 0;

    for (var i = planned.length - 1; i >= 0; i--) {
      final day = planned[i];
      final outcome = recorded[day]?.outcome;
      if (day == today && outcome == null) continue;

      switch (outcome) {
        case DayOutcome.full:
          if (fullStreakOpen) fullStreak++;
          if (keepGoingOpen) keepGoing++;
          if (lastFull == 0) lastFull = day;
          runningFull++;
          if (runningFull > longestFull) longestFull = runningFull;
          break;
        case DayOutcome.minimum:
          // Alive, but not a full completion: the full streak stops here while the
          // keep-going streak continues.
          fullStreakOpen = false;
          if (keepGoingOpen) keepGoing++;
          runningFull = 0;
          break;
        case DayOutcome.rest:
        case DayOutcome.skipped:
          break; // neither extends nor breaks
        case DayOutcome.missed:
        case null:
          if (day == today) break; // today is not judged yet
          fullStreakOpen = false;
          keepGoingOpen = false;
          runningFull = 0;
          break;
      }
    }

    // The trailing missed run is the recovery trigger, so it gets its own pass
    // rather than being inferred from the streak walk above.
    //
    // If today has been answered — anything except an explicit miss — there is no
    // live gap: the user has already dealt with today, and a plan that fired anyway
    // would be punishing someone for a run that ended this morning.
    var missedRun = 0;
    final todayOutcome = recorded[today]?.outcome;
    final todayAnswered = todayOutcome != null && todayOutcome != DayOutcome.missed;
    if (!todayAnswered) {
      for (var i = planned.length - 1; i >= 0; i--) {
        final day = planned[i];
        if (day == today) continue;
        final outcome = recorded[day]?.outcome;
        if (outcome == DayOutcome.rest || outcome == DayOutcome.skipped) continue; // excluded
        if (outcome == DayOutcome.full || outcome == DayOutcome.minimum) break;
        missedRun++; // recorded miss, or silence on a planned day
      }
    }

    // ---- recovery ------------------------------------------------------------
    RestartPlan? plan;
    if (missedRun >= recoveryGap) {
      final upcoming = _nextPlannedDays(c, pauses, from: today, count: 4);
      final backOn = upcoming.isEmpty ? null : upcoming.last;
      plan = RestartPlan(
        reason: '$missedRun planned days in a row went unlogged. '
            'The last full day on record was '
            '${lastFull == 0 ? 'none yet' : shortDayKey(lastFull)}.',
        missedRun: missedRun,
        steps: [
          RestartStep(
            title: 'Next ${upcoming.isEmpty ? 3 : upcoming.length - 1} planned days: minimum only',
            detail: 'Do the smallest version and log it. This rebuilds the record, not the fitness.',
          ),
          RestartStep(
            title: backOn == null
                ? 'Then the full target again'
                : 'Then the full target on ${shortDayKey(backOn)}',
            detail: 'One full day is enough to start with. The plan does not ask for a week of them.',
          ),
          RestartStep(
            title: 'If it slips again, change the commitment',
            detail: 'Misses clustering on one weekday are a scheduling problem, not a character '
                'problem. Drop that weekday, or lower the full target and keep the minimum.',
          ),
        ],
        generatedOn: today,
      );
    }

    return MomentumSnapshot(
      commitmentId: c.id,
      windowFrom: from,
      windowTo: today,
      plannedDays: planned.length,
      decidedDays: decided,
      fullDays: full,
      minimumDays: minimum,
      missedDays: missed,
      excludedDays: excluded,
      credit: credit,
      rate: rate,
      fullStreak: fullStreak,
      keepGoingStreak: keepGoing,
      longestFullStreakInWindow: longestFull,
      lastFullDay: lastFull == 0 ? null : lastFull,
      missedRun: missedRun,
      restart: plan,
      todayOpen: isPlanned(c, today, pauses) && recorded[today] == null,
    );
  }

  /// The next [count] planned days, starting with [from] itself.
  static List<int> _nextPlannedDays(Commitment c, List<Pause> pauses, {required int from, int count = 3}) {
    final out = <int>[];
    var day = from;
    var guard = 0;
    while (out.length < count && guard < 200) {
      if (isPlanned(c, day, pauses)) out.add(day);
      day = nextDayKey(day);
      guard++;
    }
    return out;
  }

  // --------------------------------------------------------------- patterns
  /// Weekday misses, reported only where the evidence carries them.
  ///
  /// Rule: a weekday is reported when it has at least [weekdayMinSample] decided
  /// days, the user missed at least half of them, and that weekday's miss rate is
  /// at least 25 points worse than the same user's overall rate. No weekday clears
  /// the bar → no card. The sentence names counts, never causes.
  static List<WeekdayPattern> weekdayPatterns({
    required Commitment c,
    required Map<int, CommitmentDay> recorded,
    required List<Pause> pauses,
    required int today,
    int weeks = 12,
  }) {
    var from = today;
    for (var i = 1; i < weeks * 7; i++) {
      from = previousDayKey(from);
    }
    if (from < c.createdDay) from = c.createdDay;

    final planned = plannedDays(c, pauses, from: from, to: today);
    final perWeekday = <int, List<DayOutcome?>>{};
    var totalDecided = 0;
    var totalMissed = 0;

    for (final day in planned) {
      if (day == today) continue;
      final outcome = recorded[day]?.outcome;
      if (outcome == DayOutcome.rest || outcome == DayOutcome.skipped) continue;
      perWeekday.putIfAbsent(weekdayOfDayKey(day), () => <DayOutcome?>[]).add(outcome);
      totalDecided++;
      if (outcome == null || outcome == DayOutcome.missed) totalMissed++;
    }

    final overall = totalDecided == 0 ? 0.0 : totalMissed / totalDecided;
    final found = <WeekdayPattern>[];
    for (final entry in perWeekday.entries) {
      final n = entry.value.length;
      if (n < weekdayMinSample) continue;
      final misses = entry.value.where((o) => o == null || o == DayOutcome.missed).length;
      final rate = misses / n;
      if (rate < .5 || rate - overall < .25) continue;
      found.add(WeekdayPattern(
        weekday: entry.key,
        decided: n,
        missed: misses,
        overallMissRate: overall,
      ));
    }
    found.sort((a, b) => b.missRate.compareTo(a.missRate));
    return found;
  }

  /// Improvement between the last [window] days and the [window] days before them.
  /// Both halves need [improvementMinSample] decided days and the change must reach
  /// [improvementMinPoints] points, otherwise nothing is said.
  static Improvement? improvement({
    required Commitment c,
    required Map<int, CommitmentDay> recorded,
    required List<Pause> pauses,
    required int today,
    int window = 14,
  }) {
    var boundary = today;
    for (var i = 1; i < window; i++) {
      boundary = previousDayKey(boundary);
    }
    final recent = _creditOver(c, recorded, pauses, from: boundary, to: today);

    var prevTo = previousDayKey(boundary);
    var prevFrom = prevTo;
    for (var i = 1; i < window; i++) {
      prevFrom = previousDayKey(prevFrom);
    }
    if (prevFrom < c.createdDay) prevFrom = c.createdDay;
    final previous = _creditOver(c, recorded, pauses, from: prevFrom, to: prevTo);

    if (!recent.reportable || !previous.reportable) return null;
    final delta = recent.rate - previous.rate;
    if (delta < improvementMinPoints) return null;
    return Improvement(
      recentRate: recent.rate,
      previousRate: previous.rate,
      delta: delta,
      recentDays: recent.decided,
      previousDays: previous.decided,
      windowDays: window,
    );
  }

  static _Credit _creditOver(
    Commitment c,
    Map<int, CommitmentDay> recorded,
    List<Pause> pauses, {
    required int from,
    required int to,
  }) {
    var decided = 0;
    var credit = 0.0;
    for (final day in plannedDays(c, pauses, from: from, to: to)) {
      // The final day of the range is "today": still open, so unlogged here means
      // "not yet", not "missed".
      if (day == to && recorded[day] == null) continue;
      final outcome = recorded[day]?.outcome;
      switch (outcome) {
        case DayOutcome.full:
          decided++;
          credit += 1;
          break;
        case DayOutcome.minimum:
          decided++;
          credit += minimumCredit;
          break;
        case DayOutcome.missed:
          decided++;
          break;
        case DayOutcome.rest:
        case DayOutcome.skipped:
          break; // excluded, not punished
        case null:
          decided++;
          break;
      }
    }
    final rate = decided == 0 ? 0.0 : credit / decided * 100;
    return _Credit(rate: rate, decided: decided, reportable: decided >= improvementMinSample);
  }

  // --------------------------------------------------------- weekly review
  /// Monday-to-Sunday review built from that week's records only, with the totals
  /// it was computed from attached, so the screen can show its own sample size.
  static WeeklyReview weeklyReview({
    required List<Commitment> commitments,
    required Map<String, Map<int, CommitmentDay>> recorded,
    required List<Pause> pauses,
    required int anyDayInWeek,
  }) {
    final start = weekStartKey(anyDayInWeek);
    var end = start;
    for (var i = 1; i < 7; i++) {
      end = nextDayKey(end);
    }

    final lines = <CommitmentWeek>[];
    var decided = 0, full = 0, minimum = 0, missed = 0, excluded = 0;
    var credit = 0.0;

    for (final c in commitments) {
      if (c.archived) continue;
      final days = recorded[c.id] ?? const <int, CommitmentDay>{};
      var cDecided = 0, cFull = 0, cMinimum = 0, cMissed = 0, cExcluded = 0;
      var cCredit = 0.0;

      for (final day in plannedDays(c, pauses, from: start, to: end)) {
        final outcome = days[day]?.outcome;
        switch (outcome) {
          case DayOutcome.full:
            cDecided++;
            cFull++;
            cCredit += 1;
            break;
          case DayOutcome.minimum:
            cDecided++;
            cMinimum++;
            cCredit += minimumCredit;
            break;
          case DayOutcome.missed:
            cDecided++;
            cMissed++;
            break;
          case DayOutcome.rest:
          case DayOutcome.skipped:
            cExcluded++;
            break;
          case null:
            // A past day in this week with no record counts as missed; days still
            // ahead are not judged.
            if (day < anyDayInWeek) {
              cDecided++;
              cMissed++;
            }
            break;
        }
      }

      decided += cDecided;
      full += cFull;
      minimum += cMinimum;
      missed += cMissed;
      excluded += cExcluded;
      credit += cCredit;

      lines.add(CommitmentWeek(
        name: c.name,
        emoji: c.emoji,
        planned: cDecided + cExcluded,
        decided: cDecided,
        full: cFull,
        minimum: cMinimum,
        missed: cMissed,
        excluded: cExcluded,
      ));
    }

    return WeeklyReview(
      weekStart: start,
      weekEnd: end,
      decidedDays: decided,
      fullDays: full,
      minimumDays: minimum,
      missedDays: missed,
      excludedDays: excluded,
      // The same sample rule as the rolling rate: below
      // [minDecidedDaysForRate] decided days a week is a count, not a score.
      // Withholding it here rather than in the card keeps the rule in one place,
      // so the weekly figure can never disagree with the 28-day one.
      rate: decided < minDecidedDaysForRate ? null : credit / decided * 100,
      commitments: lines,
      complete: end < anyDayInWeek,
    );
  }
}

class _Credit {
  const _Credit({required this.rate, required this.decided, required this.reportable});

  final double rate;
  final int decided;
  final bool reportable;
}
