import 'package:flutter/material.dart';

import '../models/models.dart';

/// Starter commitments a user can pick from — **templates, not history**.
///
/// Picking one creates a commitment whose record is empty and whose oldest day is
/// today. Nothing here is pre-completed, pre-streaked or pre-scored, and no template
/// claims anything about the person choosing it.
///
/// Two rules for this file:
///  - Every template must have a genuinely achievable minimum. A template whose
///    minimum is "the full thing" teaches the user that minimums are a lie.
///  - The catalogue is deliberately cross-domain. This is not a fitness app: study,
///    sleep, reading, mindfulness and admin are first-class categories, because a
///    habit app that only understands gym sessions misses most of a life.
class CommitmentTemplates {
  const CommitmentTemplates._();

  static List<CommitmentTemplate> all() => const <CommitmentTemplate>[
    // ------------------------------------------------------------ movement
    CommitmentTemplate(
      id: 'walk_daily',
      category: 'Movement',
      name: 'Walk',
      emoji: '🚶',
      color: Color(0xFF34C759),
      outcome: 'Move every day without it feeling like a workout',
      minimumAction: 'Put shoes on and walk 5 minutes',
      fullAction: 'Walk 30 minutes',
      weekdays: {1, 2, 3, 4, 5, 6, 7},
    ),
    CommitmentTemplate(
      id: 'strength_3x',
      category: 'Movement',
      name: 'Strength',
      emoji: '🏋️',
      color: Color(0xFFFF6B22),
      outcome: 'Get measurably stronger over a season',
      minimumAction: 'One set of the first exercise',
      fullAction: 'Full session, all sets',
      weekdays: {1, 3, 5},
    ),
    CommitmentTemplate(
      id: 'mobility',
      category: 'Movement',
      name: 'Stretch',
      emoji: '🧘',
      color: Color(0xFF30B0C7),
      outcome: 'Loosen the hips and shoulders before they become a problem',
      minimumAction: 'Two minutes of anything',
      fullAction: '10-minute mobility routine',
      weekdays: {1, 2, 3, 4, 5, 6, 7},
    ),

    // --------------------------------------------------------------- study
    CommitmentTemplate(
      id: 'study_focus',
      category: 'Study',
      name: 'Deep work block',
      emoji: '📚',
      color: Color(0xFF5856D6),
      outcome: 'Finish the course I keep restarting',
      minimumAction: 'Open the material and do one exercise',
      fullAction: '90 focused minutes',
      weekdays: {1, 2, 3, 4, 5},
    ),
    CommitmentTemplate(
      id: 'language',
      category: 'Study',
      name: 'Practice a language',
      emoji: '🗣️',
      color: Color(0xFFAF52DE),
      outcome: 'Hold a real conversation by the end of the year',
      minimumAction: 'Five minutes of review',
      fullAction: '20 minutes, including speaking',
      weekdays: {1, 2, 3, 4, 5, 6},
    ),
    CommitmentTemplate(
      id: 'reading',
      category: 'Reading',
      name: 'Read a book',
      emoji: '📖',
      color: Color(0xFF00C7BE),
      outcome: 'Read more books than last year',
      minimumAction: 'One page',
      fullAction: '20 pages',
      weekdays: {1, 2, 3, 4, 5, 6, 7},
    ),

    // ----------------------------------------------------------------- rest
    CommitmentTemplate(
      id: 'sleep_window',
      category: 'Sleep',
      name: 'Wind down',
      emoji: '🌙',
      color: Color(0xFF5E5CE6),
      outcome: 'Wake up without an alarm most days',
      minimumAction: 'Lights out within 30 minutes of target',
      fullAction: 'Screens off an hour before bed',
      weekdays: {1, 2, 3, 4, 5, 6, 7},
    ),
    CommitmentTemplate(
      id: 'breathing',
      category: 'Mindfulness',
      name: 'Sit still',
      emoji: '🫁',
      color: Color(0xFF34C759),
      outcome: 'A calmer baseline on ordinary days',
      minimumAction: 'Three slow breaths',
      fullAction: '10 minutes of sitting practice',
      weekdays: {1, 2, 3, 4, 5, 6, 7},
    ),
    CommitmentTemplate(
      id: 'journal',
      category: 'Mindfulness',
      name: 'Journal',
      emoji: '📝',
      color: Color(0xFFFF9500),
      outcome: 'Notice what actually shapes my days',
      minimumAction: 'One sentence',
      fullAction: 'A page',
      weekdays: {1, 2, 3, 4, 5, 6, 7},
    ),

    // --------------------------------------------------------- productivity
    CommitmentTemplate(
      id: 'inbox_zero',
      category: 'Productivity',
      name: 'Clear the deck',
      emoji: '📥',
      color: Color(0xFF007AFF),
      outcome: 'Stop starting every week already behind',
      minimumAction: 'Clear five items',
      fullAction: 'Inbox and task list to zero',
      weekdays: {1, 2, 3, 4, 5},
    ),
    CommitmentTemplate(
      id: 'admin_block',
      category: 'Productivity',
      name: 'Admin block',
      emoji: '🗂️',
      color: Color(0xFF8E8E93),
      outcome: 'No more letters sitting unopened for a month',
      minimumAction: 'Handle one thing',
      fullAction: 'Full 30-minute admin sweep',
      weekdays: {2, 4},
    ),

    // --------------------------------------------------------------- health
    CommitmentTemplate(
      id: 'water_habit',
      category: 'Health',
      name: 'Drink water',
      emoji: '💧',
      color: Color(0xFF5AC8FA),
      outcome: 'Stop getting afternoon headaches',
      minimumAction: 'One glass, right now',
      fullAction: 'Eight glasses across the day',
      weekdays: {1, 2, 3, 4, 5, 6, 7},
    ),
    CommitmentTemplate(
      id: 'tidy_ten',
      category: 'Home',
      name: 'Ten-minute tidy',
      emoji: '🧹',
      color: Color(0xFF00C7BE),
      outcome: 'A flat that stays guest-ready',
      minimumAction: 'One surface cleared',
      fullAction: 'Ten minutes, timer on',
      weekdays: {1, 2, 3, 4, 5, 6, 7},
    ),
  ];

  /// Categories in catalogue order, for the template picker's section headers.
  static List<String> categories() {
    final seen = <String>[];
    for (final t in all()) {
      if (!seen.contains(t.category)) seen.add(t.category);
    }
    return seen;
  }

  static CommitmentTemplate? byId(String id) {
    for (final t in all()) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// Turns a template into a live commitment. [id] and [createdDay] are supplied
  /// by the caller so this stays a pure function and the repository owns identity.
  static Commitment instantiate(CommitmentTemplate t, {required String id, required int createdDay}) => Commitment(
    id: id,
    name: t.name,
    emoji: t.emoji,
    color: t.color,
    outcome: t.outcome,
    minimumAction: t.minimumAction,
    fullAction: t.fullAction,
    revisions: [ScheduleRevision(createdDay, t.weekdays)],
    createdDay: createdDay,
  );
}
