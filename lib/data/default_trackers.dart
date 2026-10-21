import 'package:flutter/material.dart';

import '../models/models.dart';

/// The catalogue of trackers the app knows how to run.
///
/// These are **definitions only** — names, units, goals, colours. No values, no
/// history, no streaks. A fresh install writes these rows so the user has
/// something to log against; the database's entry tables stay empty until the
/// user (or Health Connect) actually records something.
///
/// This file must never contain a statistic. Anything that reads like a finding
/// ("you drink more on early days") belongs in `lib/data/insights_engine.dart`,
/// computed from real rows, or nowhere at all.
class DefaultTrackers {
  const DefaultTrackers._();

  /// Every tracker the app can run, in default dashboard order.
  static List<Tracker> all() => <Tracker>[
    Tracker(
      id: 'water',
      name: 'Water',
      emoji: '💧',
      accent: const Color(0xFF007AFF),
      accent2: const Color(0xFF5AC8FA),
      kind: MetricKind.volume,
      goal: 2500,
      step: 250,
      unit: 'ml',
      hero: true,
      blurb: '8 cups a day, minus the counting',
      insight: 'Tap + or swipe the card each time you drink. Your ring fills and your week builds up.',
    ),
    Tracker(
      id: 'mood',
      name: 'Mood',
      emoji: '😊',
      accent: const Color(0xFFFF9500),
      accent2: const Color(0xFFFFCC00),
      kind: MetricKind.mood,
      goal: 5,
      step: 1,
      unit: '/5',
      blurb: 'One tap, once a day',
      insight: 'One tap a day is enough to see your month as a heatmap.',
    ),
    Tracker(
      id: 'expenses',
      name: 'Expenses',
      emoji: '💰',
      accent: const Color(0xFF34C759),
      accent2: const Color(0xFF00C7BE),
      kind: MetricKind.money,
      goal: 1500,
      step: 50,
      unit: '₹',
      blurb: 'Daily budget, no spreadsheet',
      insight: 'Log spends as they happen and the category breakdown builds itself.',
    ),
    Tracker(
      id: 'sleep',
      name: 'Sleep',
      emoji: '😴',
      accent: const Color(0xFF5856D6),
      accent2: const Color(0xFFAF52DE),
      kind: MetricKind.hours,
      goal: 8,
      step: .5,
      unit: 'h',
      blurb: 'Hours + quality, 7-day average',
      insight: 'Log hours slept, or connect Health Connect to fill this in automatically.',
    ),
    Tracker(
      id: 'habits',
      name: 'Habits',
      emoji: '✅',
      accent: const Color(0xFFFF2D55),
      accent2: const Color(0xFFFF6482),
      kind: MetricKind.habits,
      goal: 5,
      step: 1,
      unit: 'done',
      blurb: 'Your daily checklist, with real streaks',
      insight: 'Add the habits you actually keep — each one gets its own streak from the days you tick it.',
    ),
    Tracker(
      id: 'calories',
      name: 'Calories',
      emoji: '🔥',
      accent: const Color(0xFFFF6B22),
      accent2: const Color(0xFFFF9500),
      kind: MetricKind.calories,
      goal: 2200,
      step: 100,
      unit: 'kcal',
      blurb: 'Quick-add foods, running total',
      insight: 'Use the quick-add list or type a number. The day total is the sum of what you logged.',
    ),
    Tracker(
      id: 'steps',
      name: 'Steps',
      emoji: '👣',
      accent: const Color(0xFF30B0C7),
      accent2: const Color(0xFF00C7BE),
      kind: MetricKind.steps,
      goal: 10000,
      step: 500,
      unit: 'steps',
      blurb: 'Read from Health Connect, or log by hand',
      insight: 'Health Connect fills steps in without you opening the app. Entries you type always win.',
    ),
    Tracker(
      id: 'period',
      name: 'Period',
      emoji: '🌸',
      accent: const Color(0xFFFF2D55),
      accent2: const Color(0xFFAF52DE),
      kind: MetricKind.cycle,
      goal: 28,
      step: 1,
      unit: 'cycle',
      blurb: 'Log your flow, see your pattern',
      insight: 'Predictions appear once you have logged two cycles — and they always show their range.',
    ),
    Tracker(
      id: 'screen',
      name: 'Screen time',
      emoji: '📱',
      accent: const Color(0xFFAF52DE),
      accent2: const Color(0xFF5E5CE6),
      kind: MetricKind.minutes,
      goal: 240,
      step: 15,
      unit: 'min',
      blurb: 'Read from Android or logged by hand',
      insight:
          'Grant Usage Access to fill screen time automatically, or log a daily total — '
          'typed entries always win.',
    ),
    Tracker(
      id: 'weight',
      name: 'Weight',
      emoji: '⚖️',
      accent: const Color(0xFF5E5CE6),
      accent2: const Color(0xFF0A84FF),
      kind: MetricKind.weight,
      goal: 70,
      step: .1,
      unit: 'kg',
      blurb: 'Trend line, not daily noise',
      insight: 'Weigh in when you like — the trend is drawn from the days you actually logged.',
    ),
  ];

  /// Trackers that exist but are not on the dashboard yet: the "add more"
  /// catalogue. Definitions only, same rule as above.
  static const List<AdditionalTracker> addable = <AdditionalTracker>[
    AdditionalTracker('caffeine', 'Caffeine', '☕️', 0xFF8E6A4B, 'mg a day, cut-off reminders'),
    AdditionalTracker('reading', 'Reading', '📖', 0xFF5856D6, 'Pages or minutes per day'),
    AdditionalTracker('journal', 'Journaling', '📝', 0xFFFF9500, 'One entry a day'),
    AdditionalTracker('meditation', 'Meditation', '🧘', 0xFF34C759, 'Minutes on the cushion'),
    AdditionalTracker('skincare', 'Skincare', '🧴', 0xFFFF2D55, 'AM/PM routine checklist'),
    AdditionalTracker('vitamins', 'Vitamins', '💊', 0xFF00C7BE, 'Daily supplement stack'),
  ];

  /// Tracker ids that the app ships enabled on a new install. Three, which is
  /// exactly the free tier — a new user starts inside the free plan, not against
  /// a wall.
  static const List<String> enabledByDefault = <String>['water', 'mood', 'expenses'];

  /// Habits are user configuration. A new install gets a short starter list with
  /// **no** completion and **no** streak: `streak: 0, done: false` is the only
  /// honest starting state.
  static List<Habit> starterHabits() => <Habit>[
    const Habit('Drink 8 cups of water', '💧', Color(0xFF007AFF)),
    const Habit('Move 30 minutes', '🏃', Color(0xFFFF9500)),
    const Habit('No phone in bed', '🌙', Color(0xFFAF52DE)),
  ];

  /// The default per-day targets used when a tracker is added later.
  static Tracker? byId(String id) {
    for (final t in all()) {
      if (t.id == id) return t;
    }
    return null;
  }
}

/// A tracker that can be added to the dashboard from the "add more" list.
class AdditionalTracker {
  const AdditionalTracker(this.id, this.name, this.emoji, this.accent, this.blurb);

  final String id;
  final String name;
  final String emoji;
  final int accent;
  final String blurb;
}
