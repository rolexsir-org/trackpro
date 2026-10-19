import 'package:flutter/material.dart';

/// How a tracker's numbers behave: formatting, ring maths, log affordance.
enum MetricKind { volume, mood, money, hours, habits, calories, steps, cycle, minutes, weight }

class Tracker {
  Tracker({
    required this.id,
    required this.name,
    required this.emoji,
    required this.accent,
    required this.accent2,
    required this.kind,
    required this.goal,
    required this.step,
    required this.unit,
    required this.blurb,
    required this.insight,
    this.hero = false,
    this.hidden = false,
    this.order = 0,
  });

  final String id;
  final String name;
  final String emoji;
  final Color accent;
  final Color accent2;
  final MetricKind kind;
  final String unit;
  final String blurb;

  /// Static explanation of how to use this tracker.
  ///
  /// Not a finding. Anything that reads like a statistic about the user is
  /// computed by `InsightsEngine` from real rows — this string only ever
  /// describes what the tracker does.
  final String insight;
  final bool hero;

  double goal;
  double step;
  bool hidden;
  int order;

  Tracker copy() => Tracker(
        id: id,
        name: name,
        emoji: emoji,
        accent: accent,
        accent2: accent2,
        kind: kind,
        goal: goal,
        step: step,
        unit: unit,
        blurb: blurb,
        insight: insight,
        hero: hero,
        hidden: hidden,
        order: order,
      );
}

/// A habit in the user's own checklist.
///
/// Only the *definition* is persisted. `done` and `streak` are projected from
/// the stored per-day checklist (`daily_entries.meta` for the `habits` tracker)
/// by `AppState._projectHabitHistory`, so they can never drift from history and
/// a fresh install starts at a genuine zero rather than a seeded number.
class Habit {
  Habit(this.name, this.emoji, this.color, {this.streak = 0, this.done = false});

  final String name;
  final String emoji;
  final Color color;

  /// Derived from history — never read from disk, never seeded.
  int streak;
  bool done;

  Map<String, dynamic> toJson() => {
        'name': name,
        'emoji': emoji,
        'color': color.toARGB32(),
      };
}

class Transaction {
  Transaction(this.title, this.category, this.amount, this.when);

  final String title;
  final String category;
  final double amount;
  final String when;
}

class CategoryTotal {
  CategoryTotal(this.name, this.amount, this.color);

  final String name;
  final double amount;
  final Color color;
}

class Milestone {
  const Milestone(this.emoji, this.title, this.subtitle, this.unlocked);

  final String emoji;
  final String title;
  final String subtitle;
  final bool unlocked;
}


class FoodItem {
  const FoodItem(this.name, this.kcal, this.emoji);

  final String name;
  final int kcal;
  final String emoji;
}


/// ---------------------------------------------------------------------------
/// Momentum: commitments, the days they were actually kept, and the derived
/// figures. Everything here is a *definition* or a *record of something that
/// happened* — nothing is a placeholder, and nothing carries a default value that
/// could be mistaken for history.
/// ---------------------------------------------------------------------------

/// What actually happened on one planned day.
///
/// The order matters: [full] and [minimum] are the two ways of showing up, and the
/// engine's credit table keys off them. [rest] and [skipped] are deliberate
/// decisions that are **excluded** from scoring rather than counted as failures —
/// a rest day is part of a plan, not a lapse in one.
enum DayOutcome { full, minimum, missed, rest, skipped }

extension DayOutcomeText on DayOutcome {
  /// The string written to the database. Stable: an export from an older build
  /// must keep importing.
  String get storage => name;

  String get label => switch (this) {
        DayOutcome.full => 'Full',
        DayOutcome.minimum => 'Minimum',
        DayOutcome.missed => 'Missed',
        DayOutcome.rest => 'Rest day',
        DayOutcome.skipped => 'Skipped on purpose',
      };

  /// Short verb for the logging sheet.
  String get verb => switch (this) {
        DayOutcome.full => 'Did the full thing',
        DayOutcome.minimum => 'Did the minimum',
        DayOutcome.missed => 'Did not do it',
        DayOutcome.rest => 'Rest day',
        DayOutcome.skipped => 'Skipping on purpose',
      };

  bool get countsAsDecided => this == DayOutcome.full || this == DayOutcome.minimum || this == DayOutcome.missed;

  static DayOutcome? fromStorage(String? raw) {
    for (final o in DayOutcome.values) {
      if (o.storage == raw) return o;
    }
    return null;
  }
}

/// One revision of a commitment's schedule, in force from [fromDay] until the next
/// revision supersedes it. Schedules are versioned so that editing one today does
/// not retroactively rewrite which days the user was supposed to act on.
class ScheduleRevision {
  const ScheduleRevision(this.fromDay, this.weekdays);

  final int fromDay;

  /// ISO weekdays: 1 = Monday … 7 = Sunday.
  final Set<int> weekdays;

  Map<String, dynamic> toJson() => {'from': fromDay, 'days': weekdays.toList()..sort()};
}

/// A commitment: something the user said they would do, with the smallest version
/// of it they would still count as showing up.
class Commitment {
  Commitment({
    required this.id,
    required this.name,
    required this.emoji,
    required this.color,
    required this.outcome,
    required this.minimumAction,
    required this.fullAction,
    required List<ScheduleRevision> revisions,
    required this.createdDay,
    this.archived = false,
    this.archivedDay,
    this.sort = 0,
  }) : revisions = List<ScheduleRevision>.unmodifiable(revisions);

  final String id;
  final String name;
  final String emoji;
  final Color color;

  /// The desired outcome in the user's words ("get through a 5k without stopping").
  /// Descriptive only — nothing is scored against this text.
  final String outcome;

  /// The realistic fallback: "put the shoes on and walk 5 minutes".
  final String minimumAction;

  /// The target on a normal day: "run 5 km".
  final String fullAction;

  /// Oldest first. Always at least one revision for a commitment that exists.
  final List<ScheduleRevision> revisions;

  /// The day this commitment was created — nothing before it is ever scored.
  final int createdDay;

  final bool archived;
  final int? archivedDay;
  final int sort;

  /// The schedule currently in force.
  Set<int> get schedule => revisions.isEmpty ? const <int>{} : revisions.last.weekdays;

  /// The revision that governed [day], or null when the commitment did not exist
  /// yet (or the stored revisions are empty, which is a corrupt row, not a plan).
  ScheduleRevision? scheduleInForceOn(int day) {
    ScheduleRevision? best;
    for (final r in revisions) {
      if (r.fromDay > day) continue;
      if (best == null || r.fromDay > best.fromDay) best = r;
    }
    return best;
  }

  int get sessionsPerWeek => schedule.length;

  String get scheduleLabel {
    final days = schedule.toList()..sort();
    if (days.length == 7) return 'Every day';
    if (days.length == 5 && days.every((d) => d <= 5)) return 'Weekdays';
    if (days.length == 2 && days.contains(6) && days.contains(7)) return 'Weekends';
    if (days.isEmpty) return 'No days selected';
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days.map((d) => names[(d - 1).clamp(0, 6).toInt()]).join(', ');
  }

  Commitment copyWith({
    String? name,
    String? emoji,
    Color? color,
    String? outcome,
    String? minimumAction,
    String? fullAction,
    List<ScheduleRevision>? revisions,
    bool? archived,
    int? archivedDay,
    int? sort,
  }) =>
      Commitment(
        id: id,
        name: name ?? this.name,
        emoji: emoji ?? this.emoji,
        color: color ?? this.color,
        outcome: outcome ?? this.outcome,
        minimumAction: minimumAction ?? this.minimumAction,
        fullAction: fullAction ?? this.fullAction,
        revisions: revisions ?? this.revisions,
        createdDay: createdDay,
        archived: archived ?? this.archived,
        archivedDay: archivedDay ?? this.archivedDay,
        sort: sort ?? this.sort,
      );
}

/// A recorded decision about one planned day.
class CommitmentDay {
  const CommitmentDay({
    required this.commitmentId,
    required this.day,
    required this.outcome,
    this.value,
    this.note,
  });

  final String commitmentId;
  final int day;
  final DayOutcome outcome;

  /// What was actually completed, when the user typed a number. Null means "no
  /// amount recorded" — never zero, which would be a claim.
  final double? value;
  final String? note;
}

/// A stretch of days the user paused a commitment (illness, travel, a deliberate
/// break). An open pause has `toDay == null`.
class Pause {
  const Pause({required this.commitmentId, required this.fromDay, this.toDay, this.reason});

  final String commitmentId;
  final int fromDay;
  final int? toDay;
  final String? reason;

  bool covers(int day) {
    if (day < fromDay) return false;
    return toDay == null || day <= toDay!;
  }

  Pause copyWith({int? toDay, String? reason}) =>
      Pause(commitmentId: commitmentId, fromDay: fromDay, toDay: toDay ?? this.toDay, reason: reason ?? this.reason);
}

/// Everything the Momentum screen needs about one commitment, with the sample it
/// came from attached. [rate] is null until there is enough evidence — that null is
/// the feature, not a loading state.
class MomentumSnapshot {
  const MomentumSnapshot({
    required this.commitmentId,
    required this.windowFrom,
    required this.windowTo,
    required this.plannedDays,
    required this.decidedDays,
    required this.fullDays,
    required this.minimumDays,
    required this.missedDays,
    required this.excludedDays,
    required this.credit,
    required this.rate,
    required this.fullStreak,
    required this.keepGoingStreak,
    required this.longestFullStreakInWindow,
    required this.lastFullDay,
    required this.missedRun,
    required this.todayOpen,
    this.restart,
  });

  final String commitmentId;
  final int windowFrom;
  final int windowTo;
  final int plannedDays;
  final int decidedDays;
  final int fullDays;
  final int minimumDays;
  final int missedDays;
  final int excludedDays;
  final double credit;

  /// Percentage, or null when [decidedDays] is below the reporting threshold.
  final double? rate;
  final int fullStreak;
  final int keepGoingStreak;
  final int longestFullStreakInWindow;
  final int? lastFullDay;
  final int missedRun;
  final bool todayOpen;
  final RestartPlan? restart;
}

class RestartStep {
  const RestartStep({required this.title, required this.detail});

  final String title;
  final String detail;
}

/// A deterministic, reviewable recovery plan. It states why it appeared, how many
/// days it covers, and what to do — and it is generated from the record, never
/// from an inferred emotional state.
class RestartPlan {
  const RestartPlan({
    required this.reason,
    required this.missedRun,
    required this.steps,
    required this.generatedOn,
  });

  final String reason;
  final int missedRun;
  final List<RestartStep> steps;
  final int generatedOn;
}

/// A weekday that is missed noticeably more often than the user's own average.
class WeekdayPattern {
  const WeekdayPattern({
    required this.weekday,
    required this.decided,
    required this.missed,
    required this.overallMissRate,
  });

  /// ISO weekday, 1 = Monday.
  final int weekday;
  final int decided;
  final int missed;
  final double overallMissRate;

  double get missRate => decided == 0 ? 0 : missed / decided;
}

/// Measured improvement against the previous window of the same length.
class Improvement {
  const Improvement({
    required this.recentRate,
    required this.previousRate,
    required this.delta,
    required this.recentDays,
    required this.previousDays,
    required this.windowDays,
  });

  final double recentRate;
  final double previousRate;
  final double delta;
  final int recentDays;
  final int previousDays;
  final int windowDays;
}

/// One commitment's line in the weekly review.
class CommitmentWeek {
  const CommitmentWeek({
    required this.name,
    required this.emoji,
    required this.planned,
    required this.decided,
    required this.full,
    required this.minimum,
    required this.missed,
    required this.excluded,
  });

  final String name;
  final String emoji;
  final int planned;
  final int decided;
  final int full;
  final int minimum;
  final int missed;
  final int excluded;
}

class WeeklyReview {
  const WeeklyReview({
    required this.weekStart,
    required this.weekEnd,
    required this.decidedDays,
    required this.fullDays,
    required this.minimumDays,
    required this.missedDays,
    required this.excludedDays,
    required this.rate,
    required this.commitments,
    required this.complete,
  });

  final int weekStart;
  final int weekEnd;
  final int decidedDays;
  final int fullDays;
  final int minimumDays;
  final int missedDays;
  final int excludedDays;

  /// Null until the week has at least `MomentumEngine.minDecidedDaysForRate`
  /// decided days — the same rule as the rolling rate, applied to one week.
  final double? rate;
  final List<CommitmentWeek> commitments;

  /// True when the week ended before the reference day it was computed against.
  /// A review of the current week is therefore marked incomplete, and the Momentum
  /// screen prints "the week is still running" rather than presenting a partial
  /// week as a verdict.
  final bool complete;
}

/// A starter commitment a user can pick in the Routines screen.
///
/// Templates carry **no history**: choosing one creates a commitment whose record
/// starts empty, today. The text fields describe the commitment, not the person.
class CommitmentTemplate {
  const CommitmentTemplate({
    required this.id,
    required this.category,
    required this.name,
    required this.emoji,
    required this.color,
    required this.outcome,
    required this.minimumAction,
    required this.fullAction,
    required this.weekdays,
  });

  final String id;
  final String category;
  final String name;
  final String emoji;
  final Color color;
  final String outcome;
  final String minimumAction;
  final String fullAction;
  final Set<int> weekdays;
}

/// One row of the Today screen's commitment queue.
///
/// [outcome] is null until the user says what happened — the screen shows two
/// buttons, not a pre-filled state. [scheduled] can be false when the user logged a
/// commitment on a day it was not planned, which is allowed and shown as such.
class TodayCommitment {
  const TodayCommitment({
    required this.commitment,
    required this.scheduled,
    required this.paused,
    this.outcome,
    this.snapshot,
  });

  final Commitment commitment;
  final bool scheduled;
  final bool paused;
  final DayOutcome? outcome;
  final MomentumSnapshot? snapshot;

  bool get logged => outcome != null;
  bool get fullDone => outcome == DayOutcome.full;
  bool get minimumDone => outcome == DayOutcome.minimum;
  bool get rested => outcome == DayOutcome.rest || outcome == DayOutcome.skipped;
}

/// A write that did not reach the database.
///
/// Carried on `AppState` so the UI can say so. The alternative it replaces — swallowing
/// the exception and leaving the optimistic value in the cache — meant the app confirmed
/// a save it never made, and the value reverted on the next launch with no explanation.
class SaveFailure {
  const SaveFailure({required this.action, required this.detail, required this.at});

  /// What the user was doing, in their words ("Water", "Routine done").
  final String action;

  /// What went wrong, in words that suggest a next step.
  final String detail;

  final DateTime at;
}
