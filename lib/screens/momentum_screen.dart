import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/design_system.dart';
import '../data/momentum.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../util/day_key.dart';
import '../widgets/glass.dart';
import '../widgets/large_title_header.dart';
import 'commitment_sheets.dart';
import 'focus_history_screen.dart';
import 'focus_setup_sheets.dart';

/// Momentum — the consistency record, and the screen that has to be honest.
///
/// Three rules govern everything below:
///  1. **No figure without its sample.** Every rate prints the decided-day count it
///     came from, and below [MomentumEngine.minDecidedDaysForRate] there is no rate
///     at all — the card shows "n of 7 days" instead. A blank figure is a feature.
///  2. **No colour without a definition.** Full, minimum, missed and rest have one
///     meaning each, and the legend is always on screen.
///  3. **No advice without evidence.** Patterns appear only past the engine's
///     thresholds; otherwise the section explains what would qualify, rather than
///     filling the space with something plausible.
class MomentumScreen extends StatelessWidget {
  const MomentumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final overall = state.overallMomentum;
    final commitments = state.commitments;

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      slivers: [
        SliverToBoxAdapter(
          child: LargeTitleHeader(
            title: 'Momentum',
            subtitle: commitments.isEmpty
                ? 'Your progress at a glance'
                : '${commitments.length} routine${commitments.length == 1 ? '' : 's'} · '
                    'last ${MomentumEngine.rateWindowDays} days',
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(Editorial.s4, Editorial.s1, Editorial.s4, 130),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              if (commitments.isEmpty && !state.focusStats.hasAny)
                _EmptyMomentum(showFocus: state.hasFocusSupport)
              else ...[
                if (overall != null) ...[
                  _HeadlineCard(state: state, overall: overall),
                  const SizedBox(height: Editorial.s4),
                ],
                if (state.focusStats.hasAny) ...[
                  _FocusProgressCard(state: state),
                  const SizedBox(height: Editorial.s4),
                ],
                if (state.needsRestart.isNotEmpty) ...[
                  _RestartCard(state: state),
                  const SizedBox(height: Editorial.s4),
                ],
                if (commitments.isNotEmpty) ...[
                  _Legend(),
                  const SizedBox(height: Editorial.s4),
                  for (final c in commitments) ...[
                    _CommitmentCard(state: state, commitment: c),
                    const SizedBox(height: Editorial.s3),
                  ],
                  const SizedBox(height: Editorial.s1),
                  _PatternsSection(state: state),
                  const SizedBox(height: Editorial.s4),
                  _WeeklyReviewCard(state: state),
                  const SizedBox(height: Editorial.s4),
                ],
                GestureDetector(
                  onTap: () => showMomentumExplainer(context),
                  child: Container(
                    decoration: Editorial.card(),
                    padding: const EdgeInsets.all(Editorial.s4),
                    child: Row(
                      children: [
                        Icon(CupertinoIcons.info_circle, size: 18, color: Editorial.inkTertiary),
                        const SizedBox(width: Editorial.s3),
                        Expanded(
                          child: Text('How momentum is calculated', style: Editorial.figure),
                        ),
                        Icon(CupertinoIcons.chevron_right, size: 16, color: Editorial.inkTertiary),
                      ],
                    ),
                  ),
                ),
              ],
            ]),
          ),
        ),
      ],
    );
  }
}

/// The one number the screen is about — or an honest account of why there isn't one.
class _HeadlineCard extends StatelessWidget {
  const _HeadlineCard({required this.state, required this.overall});

  final AppState state;
  final MomentumSnapshot? overall;

  @override
  Widget build(BuildContext context) {
    final o = overall;
    if (o == null) return const SizedBox.shrink();

    final decided = o.decidedDays;
    final enough = o.rate != null;

    return Container(
      decoration: Editorial.card(),
      padding: const EdgeInsets.all(Editorial.s5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            enough ? 'MOMENTUM · LAST ${MomentumEngine.rateWindowDays} DAYS' : 'JUST GETTING STARTED',
            style: Editorial.label,
          ),
          const SizedBox(height: Editorial.s3),
          if (o.rate case final rate)
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('${rate.round()}%', style: Editorial.display),
                const SizedBox(width: Editorial.s3),
                Text('$decided days counted', style: Editorial.caption),
              ],
            )
          else ...[
            Text('$decided of ${MomentumEngine.minDecidedDaysForRate} days counted',
                style: Editorial.display.copyWith(fontSize: 26)),
            const SizedBox(height: Editorial.s2),
            Text(
              'Momentum appears after ${MomentumEngine.minDecidedDaysForRate} days, so it reflects a habit '
              'rather than a good week. Keep logging and it will show up here.',
              style: Editorial.body,
            ),
          ],
          const SizedBox(height: Editorial.s4),
          _FigureRow(label: 'Full days', value: '${o.fullDays}', tint: Editorial.full),
          _FigureRow(label: 'Minimum days', value: '${o.minimumDays}', tint: Editorial.minimum),
          _FigureRow(label: 'Missed days', value: '${o.missedDays}', tint: Editorial.missed),
          _FigureRow(label: 'Rest or skipped', value: '${o.excludedDays}', tint: Editorial.rest),
          const SizedBox(height: Editorial.s3),
          Text(
            'A minimum day keeps your streak going and counts partly. Rest days do not count against you.',
            style: Editorial.caption,
          ),
        ],
      ),
    );
  }
}


/// Real focus time, from the sessions the user actually finished. This is the same
/// record the Focus history screen reads, shown where progress is expected to live;
/// it is hidden entirely until there is a session to report.
class _FocusProgressCard extends StatelessWidget {
  const _FocusProgressCard({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final stats = state.focusStats;
    final endedEarly = stats.cancelled + stats.interrupted;
    return Container(
      decoration: Editorial.card(),
      padding: const EdgeInsets.all(Editorial.s5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('FOCUS · LAST 7 DAYS', style: Editorial.label),
          const SizedBox(height: Editorial.s3),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('${stats.minutesLast7Days} min', style: Editorial.display),
              const SizedBox(width: Editorial.s3),
              Text('${stats.endedSessions} session${stats.endedSessions == 1 ? '' : 's'}', style: Editorial.caption),
            ],
          ),
          const SizedBox(height: Editorial.s3),
          Text(
            '${stats.completed} completed · ${stats.degraded} with a caveat'
            '${endedEarly > 0 ? ' · $endedEarly ended early' : ''}',
            style: Editorial.body.copyWith(fontSize: 14),
          ),
          if (stats.cleanShare != null) ...[
            const SizedBox(height: Editorial.s2),
            Text('${stats.cleanShare!.round()}% of sessions ran exactly as planned.', style: Editorial.caption),
          ],
          const SizedBox(height: Editorial.s4),
          Row(
            children: [
              Expanded(
                child: TrackFilledButton(
                  label: 'Start a session',
                  onTap: () => showFocusStartSheet(context),
                ),
              ),
              const SizedBox(width: Editorial.s2),
              Expanded(
                child: TrackTintedButton(
                  label: 'Focus history',
                  onTap: () => Navigator.of(context).push(
                    CupertinoPageRoute<void>(builder: (_) => const FocusHistoryScreen()),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A restart plan, presented as arithmetic rather than as a pep talk.
class _RestartCard extends StatelessWidget {
  const _RestartCard({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final names = state.needsRestart;
    if (names.isEmpty) return const SizedBox.shrink();
    final first = names.first;
    final plan = state.momentumFor(first.id)!.restart!;

    return Container(
      decoration: Editorial.card(border: Editorial.minimum.withOpacity(.55)),
      padding: const EdgeInsets.all(Editorial.s5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(CupertinoIcons.arrow_counterclockwise, size: 18, color: Editorial.minimum),
              const SizedBox(width: Editorial.s3),
              Expanded(
                child: Text(
                  names.length == 1 ? 'Restart plan for ${first.name}' : 'Restart plans (${names.length})',
                  style: Editorial.title.copyWith(fontSize: 17),
                ),
              ),
            ],
          ),
          const SizedBox(height: Editorial.s3),
          Text(plan.reason, style: Editorial.body),
          const SizedBox(height: Editorial.s4),
          for (var i = 0; i < plan.steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: Editorial.s3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${i + 1}', style: Editorial.figure.copyWith(color: Editorial.minimum)),
                  const SizedBox(width: Editorial.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(plan.steps[i].title, style: Editorial.figure),
                        const SizedBox(height: 2),
                        Text(plan.steps[i].detail, style: Editorial.caption),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          if (names.length == 1)
            TrackTintedButton(
              label: 'Open ${first.name}',
              color: first.color,
              onTap: () => showCommitmentEditor(context, existing: first),
            )
          else
            const SizedBox.shrink(),
        ],
      ),
    );
  }
}

/// One commitment: today's state, the rate, the streaks, and 14 days of squares.
class _CommitmentCard extends StatelessWidget {
  const _CommitmentCard({required this.state, required this.commitment});

  final AppState state;
  final Commitment commitment;

  @override
  Widget build(BuildContext context) {
    final c = commitment;
    final snap = state.momentumFor(c.id);
    final paused = state.isCommitmentPaused(c.id);
    final today = state.todayCommitments.where((t) => t.commitment.id == c.id).toList();
    final todayCommitment = today.isEmpty ? null : today.first;
    final recorded = state.commitmentRepo.daysFor(c.id);

    return Container(
      decoration: Editorial.card(),
      padding: const EdgeInsets.all(Editorial.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: c.color.withOpacity(.16), borderRadius: BorderRadius.circular(12)),
                child: Text(c.emoji, style: const TextStyle(fontSize: 19)),
              ),
              const SizedBox(width: Editorial.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.name, style: Editorial.figure.copyWith(fontSize: 16)),
                    const SizedBox(height: 2),
                    Text(
                      paused ? 'Paused — days are not counted' : '${c.scheduleLabel} · min: ${c.minimumAction}',
                      style: Editorial.caption,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => showCommitmentEditor(context, existing: c),
                child: Icon(CupertinoIcons.ellipsis, size: 18, color: Editorial.inkTertiary),
              ),
            ],
          ),
          const SizedBox(height: Editorial.s4),
          _Strip(commitment: c, recorded: recorded, pauses: state.commitmentRepo.pauses, todayKey: state.commitmentRepo.todayKey),
          const SizedBox(height: Editorial.s4),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'MOMENTUM',
                  // No sample, no number.
                  value: snap?.rate == null ? '—' : '${snap!.rate!.round()}%',
                  detail: snap == null
                      ? 'No days yet'
                      : (snap.rate == null
                          ? '${snap.decidedDays} of ${MomentumEngine.minDecidedDaysForRate} days'
                          : '${snap.decidedDays} days counted'),
                ),
              ),
              Expanded(
                child: _MiniStat(
                  label: 'STREAK',
                  value: '${snap?.keepGoingStreak ?? 0}',
                  detail: 'days in a row',
                ),
              ),
            ],
          ),
          const SizedBox(height: Editorial.s4),
          if (todayCommitment != null)
            _TodayRow(state: state, item: todayCommitment)
          else
            Text(
              paused
                  ? 'This routine is paused. Resume it from the menu to start counting again.'
                  : 'Not planned today. You can still log it if you did it — untracked effort is still effort.',
              style: Editorial.caption,
            ),
        ],
      ),
    );
  }
}

/// Today's two buttons, in the card, so the Momentum screen is also a place you can
/// act from — not just a report.
class _TodayRow extends StatelessWidget {
  const _TodayRow({required this.state, required this.item});

  final AppState state;
  final TodayCommitment item;

  @override
  Widget build(BuildContext context) {
    final c = item.commitment;
    if (item.logged) {
      final o = item.outcome!;
      final tint = switch (o) {
        DayOutcome.full => Editorial.full,
        DayOutcome.minimum => Editorial.minimum,
        DayOutcome.missed => Editorial.missed,
        _ => Editorial.rest,
      };
      return GestureDetector(
        onTap: () => showOutcomeSheet(context, c),
        child: Container(
          decoration: Editorial.card(fill: tint.withOpacity(.12), border: tint.withOpacity(.5)),
          padding: const EdgeInsets.symmetric(horizontal: Editorial.s4, vertical: Editorial.s3),
          child: Row(
            children: [
              Icon(CupertinoIcons.checkmark_alt, size: 16, color: tint),
              const SizedBox(width: Editorial.s3),
              Expanded(child: Text('Today: ${o.label}', style: Editorial.figure.copyWith(fontSize: 14))),
              Text('change', style: Editorial.caption.copyWith(color: Editorial.accent)),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: TrackFilledButton(
            label: 'Did the full thing',
            color: c.color,
            onTap: () => state.logCommitmentDay(c.id, DayOutcome.full),
          ),
        ),
        const SizedBox(width: Editorial.s2),
        Expanded(
          child: TrackTintedButton(
            label: 'Only the minimum',
            color: c.color,
            onTap: () => state.logCommitmentDay(c.id, DayOutcome.minimum),
          ),
        ),
      ],
    );
  }
}

/// Fourteen days, one square each, coloured by what actually happened.
///
/// Days the commitment did not exist, and days that were not planned, are drawn as
/// empty outlines rather than as misses: a square should never accuse the user of
/// something they never agreed to.
class _Strip extends StatelessWidget {
  const _Strip({required this.commitment, required this.recorded, required this.pauses, required this.todayKey});

  final Commitment commitment;
  final Map<int, CommitmentDay> recorded;
  final List<Pause> pauses;
  final int todayKey;

  static const int _days = 14;

  @override
  Widget build(BuildContext context) {
    var from = todayKey;
    for (var i = 1; i < _days; i++) {
      from = previousDayKey(from);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 0; i < _days; i++)
              Expanded(
                child: Builder(builder: (context) {
                  var day = from;
                  for (var k = 0; k < i; k++) {
                    day = nextDayKey(day);
                  }
                  final planned = MomentumEngine.isPlanned(commitment, day, pauses);
                  final outcome = recorded[day]?.outcome;
                  final isToday = day == todayKey;
                  final isFuture = day > todayKey;

                  final Color fill;
                  final Color border;
                  if (outcome == DayOutcome.full) {
                    fill = Editorial.full;
                    border = Editorial.full;
                  } else if (outcome == DayOutcome.minimum) {
                    fill = Editorial.minimum;
                    border = Editorial.minimum;
                  } else if (outcome == DayOutcome.rest || outcome == DayOutcome.skipped) {
                    fill = Editorial.rest;
                    border = Editorial.rest;
                  } else if (outcome == DayOutcome.missed || (planned && day < todayKey && !isFuture)) {
                    fill = Editorial.missed.withOpacity(.28);
                    border = Editorial.missed.withOpacity(.5);
                  } else {
                    // Not planned, in the future, or today and still open.
                    fill = Colors.transparent;
                    border = Editorial.hairline;
                  }

                  return Padding(
                    padding: const EdgeInsets.only(right: 3),
                    child: Container(
                      height: 26,
                      decoration: BoxDecoration(
                        color: fill,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isToday ? Editorial.ink : border,
                          width: isToday ? 1.2 : 0.8,
                        ),
                      ),
                    ),
                  );
                }),
              ),
          ],
        ),
        const SizedBox(height: Editorial.s2),
        Row(
          children: [
            Text('${_days} days ago', style: Editorial.caption),
            const Spacer(),
            Text('Today', style: Editorial.caption),
          ],
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Editorial.s4,
      runSpacing: Editorial.s2,
      children: const [
        _LegendItem(color: Editorial.full, label: 'Full'),
        _LegendItem(color: Editorial.minimum, label: 'Minimum'),
        _LegendItem(color: Editorial.missed, label: 'Missed'),
        _LegendItem(color: Editorial.rest, label: 'Rest / skipped'),
        _LegendItem(color: Editorial.hairline, label: 'Not planned', outline: true),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label, this.outline = false});

  final Color color;
  final String label;
  final bool outline;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: outline ? Colors.transparent : color,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: color, width: .8),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: Editorial.caption),
      ],
    );
  }
}

/// Deterministic patterns, with their sample sizes — or an explanation of what
/// would be needed to produce one.
class _PatternsSection extends StatelessWidget {
  const _PatternsSection({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final commitments = state.commitments;
    final rows = <Widget>[];

    for (final c in commitments) {
      for (final p in state.patternsFor(c.id)) {
        rows.add(_Finding(
          title: '${c.name} is missed most on ${weekdayName(p.weekday)}',
          body: 'Missed ${p.missed} of ${p.decided} ${weekdayName(p.weekday, short: true)}s'
              ' (${(p.missRate * 100).round()}%), against ${(p.overallMissRate * 100).round()}% on your '
              'other planned days.',
          hint: 'This is about timing, not willpower. A smaller target for that day usually helps.',
          color: Editorial.minimum,
        ));
      }
      final imp = state.improvementFor(c.id);
      if (imp != null) {
        rows.add(_Finding(
          title: '${c.name} is improving',
          body: '${imp.recentRate.round()}% in the last ${imp.windowDays} days, against '
              '${imp.previousRate.round()}% in the ${imp.windowDays} before '
              '(+${imp.delta.round()} points).',
          hint: 'Both periods had enough logged days to compare.',
          color: Editorial.full,
        ));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('PATTERNS FROM YOUR RECORD', style: Editorial.label),
        const SizedBox(height: Editorial.s3),
        if (rows.isEmpty)
          Container(
            decoration: Editorial.card(fill: Editorial.well),
            padding: const EdgeInsets.all(Editorial.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('No patterns yet', style: Editorial.figure),
                const SizedBox(height: Editorial.s2),
                Text(
                  'Patterns appear after a few weeks of logged days, so they describe a habit rather '
                  'than a single week.',
                  style: Editorial.caption,
                ),
              ],
            ),
          )
        else
          for (final r in rows) ...[
            r,
            const SizedBox(height: Editorial.s3),
          ],
      ],
    );
  }
}

class _Finding extends StatelessWidget {
  const _Finding({required this.title, required this.body, required this.hint, required this.color});

  final String title;
  final String body;
  final String hint;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: Editorial.card(),
      padding: const EdgeInsets.all(Editorial.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: Editorial.s2),
              Expanded(child: Text(title, style: Editorial.figure)),
            ],
          ),
          const SizedBox(height: Editorial.s2),
          Text(body, style: Editorial.body.copyWith(fontSize: 14)),
          const SizedBox(height: Editorial.s2),
          Text(hint, style: Editorial.caption),
        ],
      ),
    );
  }
}

/// The weekly review: this week's records, in numbers, with the sample attached.
class _WeeklyReviewCard extends StatelessWidget {
  const _WeeklyReviewCard({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final review = state.weeklyReview;
    if (review == null) return const SizedBox.shrink();
    final range = '${shortDayKey(review.weekStart)} – ${shortDayKey(review.weekEnd)}';

    return Container(
      decoration: Editorial.card(),
      padding: const EdgeInsets.all(Editorial.s5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('THIS WEEK · $range'.toUpperCase(), style: Editorial.label),
          const SizedBox(height: Editorial.s3),
          if (review.decidedDays == 0)
            Text('No routine days this week yet.', style: Editorial.body)
          else ...[
            if (review.rate case final rate) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('${rate.round()}%', style: Editorial.title.copyWith(fontSize: 26)),
                  const SizedBox(width: Editorial.s2),
                  Text('over ${review.decidedDays} days counted', style: Editorial.caption),
                ],
              ),
            ] else ...[
              Text(
                '${review.decidedDays} of ${MomentumEngine.minDecidedDaysForRate} days counted this week. '
                'The percentage appears once there are enough.',
                style: Editorial.body,
              ),
            ],
            const SizedBox(height: Editorial.s3),
            Text(
              '${review.fullDays} full · ${review.minimumDays} minimum-only · ${review.missedDays} missed'
              '${review.excludedDays > 0 ? ' · ${review.excludedDays} rest or skipped' : ''}',
              style: Editorial.body.copyWith(fontSize: 14),
            ),
            if (!review.complete) ...[
              const SizedBox(height: Editorial.s2),
              Text('This week is still in progress.', style: Editorial.caption),
            ],
            const SizedBox(height: Editorial.s4),
            for (final line in review.commitments)
              Padding(
                padding: const EdgeInsets.only(bottom: Editorial.s2),
                child: Row(
                  children: [
                    Text(line.emoji, style: const TextStyle(fontSize: 15)),
                    const SizedBox(width: Editorial.s2),
                    Expanded(child: Text(line.name, style: Editorial.body.copyWith(color: Editorial.ink, fontSize: 14))),
                    Text(
                      line.decided == 0
                          ? 'no planned days'
                          : '${line.full} full · ${line.minimum} min · ${line.missed} missed',
                      style: Editorial.caption,
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value, required this.detail});

  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Editorial.label),
        const SizedBox(height: Editorial.s1),
        Text(value, style: Editorial.figure.copyWith(fontSize: 19)),
        const SizedBox(height: 2),
        Text(detail, style: Editorial.caption.copyWith(fontSize: 11)),
      ],
    );
  }
}

class _FigureRow extends StatelessWidget {
  const _FigureRow({required this.label, required this.value, required this.tint});

  final String label;
  final String value;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Editorial.s2),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: Editorial.s3),
          Expanded(child: Text(label, style: Editorial.body.copyWith(fontSize: 14))),
          Text(value, style: Editorial.figure),
        ],
      ),
    );
  }
}

/// First-run state. Describes what the screen will do, and offers the one action
/// that starts it — no sample data, no anonymous streak.
class _EmptyMomentum extends StatelessWidget {
  const _EmptyMomentum({required this.showFocus});

  /// Focus Lock is Android-only; offering the button elsewhere would be a dead end.
  final bool showFocus;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: Editorial.card(),
      padding: const EdgeInsets.all(Editorial.s6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Nothing to show yet', style: Editorial.title),
          const SizedBox(height: Editorial.s3),
          Text(
            'Momentum is built from your own routines: the days you said you would and the days you did. '
            'Start one and this screen fills in as you log.',
            style: Editorial.body,
          ),
          const SizedBox(height: Editorial.s5),
          TrackFilledButton(
            label: 'Create a routine',
            onTap: () => showTemplatePicker(context),
          ),
          if (showFocus) ...[
            const SizedBox(height: Editorial.s2),
            TrackTintedButton(
              label: 'Start a focus session',
              onTap: () => showFocusStartSheet(context),
            ),
          ],
        ],
      ),
    );
  }
}

