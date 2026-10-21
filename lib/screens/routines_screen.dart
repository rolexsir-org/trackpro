import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/design_system.dart';
import '../config/pro_config.dart';
import '../data/momentum.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../widgets/glass.dart';
import '../widgets/large_title_header.dart';
import 'commitment_sheets.dart';
import 'measurements_page.dart';
import 'paywall_screen.dart';
import 'settings_screen.dart';

/// Routines — where commitments are created, edited, paused and retired.
///
/// This screen is deliberately about *definitions*. Today's actions live on Today,
/// and the record lives on Momentum; mixing the three is how habit apps end up
/// showing the same thing four times.
class RoutinesScreen extends StatefulWidget {
  const RoutinesScreen({super.key});

  @override
  State<RoutinesScreen> createState() => _RoutinesScreenState();
}

enum _RoutineFilter { all, daily, weekly }

class _RoutinesScreenState extends State<RoutinesScreen> {
  _RoutineFilter _filter = _RoutineFilter.all;

  List<Commitment> _filtered(List<Commitment> commitments) => switch (_filter) {
    _RoutineFilter.all => commitments,
    // Schedules are stored as sets of ISO weekdays. The current product does
    // not model a separate custom cadence, so the filters reflect only data we
    // can truthfully query: every day and selected weekly days.
    _RoutineFilter.daily => commitments.where((c) => c.schedule.length == 7).toList(),
    _RoutineFilter.weekly => commitments.where((c) => c.schedule.length < 7).toList(),
  };

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final allActive = state.commitments;
    final active = _filtered(allActive);
    final archived = state.archivedCommitments;

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        LargeTitleHeader(
          title: 'Routines',
          subtitle: allActive.isEmpty
              ? 'No routines yet'
              : '${allActive.length} active'
                    '${state.hasCommitments && state.bestCommitmentStreak > 0 ? ' · best run ${state.bestCommitmentStreak} days' : ''}',
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(Editorial.s5, Editorial.s1, Editorial.s5, 130),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              if (allActive.isNotEmpty) ...[
                _RoutineFilters(selected: _filter, onChanged: (value) => setState(() => _filter = value)),
                const SizedBox(height: Editorial.s4),
              ],
              if (allActive.isEmpty)
                const _EmptyRoutines()
              else if (active.isEmpty)
                _FilteredEmpty(filter: _filter)
              else
                for (final c in active) ...[
                  _RoutineRow(state: state, commitment: c),
                  const SizedBox(height: Editorial.s3),
                ],
              if (allActive.isNotEmpty) ...[
                const SizedBox(height: Editorial.s2),
                Row(
                  children: [
                    Expanded(
                      child: TrackFilledButton(
                        label: 'Add routine',
                        onTap: () => state.canAddCommitment()
                            ? showTemplatePicker(context)
                            : showPaywall(context, trigger: PaywallTrigger.commitmentLimit),
                      ),
                    ),
                    const SizedBox(width: Editorial.s2),
                    Expanded(
                      child: TrackTintedButton(
                        label: 'From scratch',
                        onTap: () => state.canAddCommitment()
                            ? showCommitmentEditor(context)
                            : showPaywall(context, trigger: PaywallTrigger.commitmentLimit),
                      ),
                    ),
                  ],
                ),
              ],
              if (!state.isPro && !state.canAddCommitment())
                Padding(
                  padding: const EdgeInsets.only(top: Editorial.s3),
                  child: Text(
                    'Free includes ${ProConfig.freeCommitmentLimit} routines. Yours and every logged day '
                    'stay put; Pro removes the limit.',
                    style: Editorial.caption,
                  ),
                ),
              if (archived.isNotEmpty) ...[
                const SizedBox(height: Editorial.s6),
                Text('ARCHIVED', style: Editorial.label),
                const SizedBox(height: Editorial.s3),
                for (final c in archived) ...[
                  _RoutineRow(state: state, commitment: c, archived: true),
                  const SizedBox(height: Editorial.s3),
                ],
              ],
              const SizedBox(height: Editorial.s6),
              Text('MEASUREMENTS', style: Editorial.label),
              const SizedBox(height: Editorial.s3),
              GlassList(
                children: [
                  GlassRow(
                    title: 'Water, mood, money, sleep…',
                    subtitle: 'Track quantities separately from routines, so “how much” and “did you” stay clear.',
                    leading: const Icon(Icons.bar_chart_rounded, size: 17, color: Editorial.accent),
                    accent: Editorial.accent,
                    onTap: () =>
                        Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const MeasurementsPage())),
                  ),
                ],
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

class _RoutineFilters extends StatelessWidget {
  const _RoutineFilters({required this.selected, required this.onChanged});

  final _RoutineFilter selected;
  final ValueChanged<_RoutineFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    const filters = <MapEntry<_RoutineFilter, String>>[
      MapEntry(_RoutineFilter.all, 'All'),
      MapEntry(_RoutineFilter.daily, 'Daily'),
      MapEntry(_RoutineFilter.weekly, 'Weekly'),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final filter in filters) ...[
            _RoutineFilterChip(
              label: filter.value,
              selected: selected == filter.key,
              onTap: () => onChanged(filter.key),
            ),
            if (filter.key != filters.last.key) const SizedBox(width: Editorial.s2),
          ],
        ],
      ),
    );
  }
}

class _RoutineFilterChip extends StatelessWidget {
  const _RoutineFilterChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: '$label routines',
    child: Material(
      color: selected ? Editorial.accentSurface : Editorial.well,
      borderRadius: BorderRadius.circular(Editorial.rPill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Editorial.rPill),
        child: Container(
          constraints: const BoxConstraints(minHeight: 38),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Editorial.rPill),
            border: Border.all(
              color: selected ? Editorial.accent.withValues(alpha: .55) : Editorial.hairline,
              width: .5,
            ),
          ),
          child: Text(
            label,
            style: Editorial.body.copyWith(
              color: selected ? Editorial.accent : Editorial.inkSecondary,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ),
      ),
    ),
  );
}

class _FilteredEmpty extends StatelessWidget {
  const _FilteredEmpty({required this.filter});

  final _RoutineFilter filter;

  @override
  Widget build(BuildContext context) => Container(
    decoration: Editorial.card(),
    padding: const EdgeInsets.all(Editorial.s4),
    child: Text(
      filter == _RoutineFilter.daily ? 'No every-day routines yet.' : 'No selected-day routines yet.',
      style: Editorial.body,
    ),
  );
}

/// One routine: what it is, how it is going, and how to change it.
class _RoutineRow extends StatelessWidget {
  const _RoutineRow({required this.state, required this.commitment, this.archived = false});

  final AppState state;
  final Commitment commitment;
  final bool archived;

  @override
  Widget build(BuildContext context) {
    final c = commitment;
    final snap = state.momentumFor(c.id);
    final paused = state.isCommitmentPaused(c.id);
    final logged = state.commitmentDayLogged(c.id);

    final status = archived
        ? 'Archived · history kept'
        : paused
        ? 'Paused'
        : snap?.rate != null
        ? '${snap!.rate!.round()}% · ${snap.decidedDays} days counted'
        : (snap?.decidedDays ?? 0) == 0
        ? '${c.scheduleLabel} · nothing logged yet'
        : '${c.scheduleLabel} · ${snap!.decidedDays} of '
              '${MomentumEngine.minDecidedDaysForRate} days';

    return GestureDetector(
      onTap: () => showCommitmentEditor(context, existing: c),
      onLongPress: () async {
        final choice = await showTrackContextMenu(
          context,
          _menuAnchor(context),
          items: [
            ['Log today', Icons.check_circle_outline_rounded, false],
            [paused ? 'Resume' : 'Pause', Icons.pause_circle_outline_rounded, false],
            [archived ? 'Restore' : 'Archive', Icons.archive_outlined, false],
            ['Delete', Icons.delete_outline_rounded, true],
          ],
        );
        if (choice == null || !context.mounted) return;
        switch (choice) {
          case 'Log today':
            await showOutcomeSheet(context, c);
          case 'Pause':
            await state.pauseCommitment(c.id);
          case 'Resume':
            await state.resumeCommitment(c.id);
          case 'Archive':
            await state.archiveCommitment(c.id, archived: true);
          case 'Restore':
            await state.archiveCommitment(c.id, archived: false);
          case 'Delete':
            final ok = await showTrackConfirm(
              context,
              title: 'Delete “${c.name}”?',
              body:
                  'This removes the routine and its '
                  '${state.commitmentRepo.daysFor(c.id).length} recorded days. Archiving keeps the record '
                  'and simply stops counting it.',
              confirmLabel: 'Delete',
            );
            if (ok) await state.deleteCommitment(c.id);
        }
      },
      child: Opacity(
        opacity: archived ? .6 : 1,
        child: Container(
          decoration: Editorial.card(),
          padding: const EdgeInsets.all(Editorial.s4),
          child: Row(
            children: [
              TrackRecordIcon(label: c.name, color: c.color),
              const SizedBox(width: Editorial.s4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            c.name,
                            style: Editorial.figure.copyWith(fontSize: 16),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!archived && logged) ...[
                          const SizedBox(width: Editorial.s2),
                          Icon(Icons.verified_rounded, size: 14, color: Editorial.full),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(status, style: Editorial.caption),
                    if (!archived && c.minimumAction.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        'Minimum: ${c.minimumAction}',
                        style: Editorial.caption.copyWith(fontSize: 11.5),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (!archived)
                GestureDetector(
                  onTap: () => showOutcomeSheet(context, c),
                  child: Icon(
                    logged ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                    size: 22,
                    color: logged ? Editorial.full : Editorial.inkTertiary,
                  ),
                ),
              const SizedBox(width: Editorial.s2),
              Icon(Icons.chevron_right_rounded, size: 20, color: Editorial.inkTertiary),
            ],
          ),
        ),
      ),
    );
  }

  Offset _menuAnchor(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    final origin = box?.localToGlobal(Offset.zero) ?? Offset.zero;
    return Offset(origin.dx + 40, origin.dy + 40);
  }
}

/// The first-run state, with the action inside it.
///
/// It used to be a paragraph and nothing else — the buttons that create a routine
/// lived below it, so the empty screen read as a dead end even though it was not.
class _EmptyRoutines extends StatelessWidget {
  const _EmptyRoutines();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: Editorial.card(),
      padding: const EdgeInsets.all(Editorial.s6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Start with one thing', style: Editorial.title),
          const SizedBox(height: Editorial.s3),
          Text(
            'Pick something you want to do, and the smallest version of it that still counts. '
            'The minimum is what keeps a routine alive on a bad day.',
            style: Editorial.body,
          ),
          const SizedBox(height: Editorial.s5),
          TrackFilledButton(label: 'Create your first routine', onTap: () => showTemplatePicker(context)),
          const SizedBox(height: Editorial.s2),
          TrackTintedButton(label: 'Build one yourself', onTap: () => showCommitmentEditor(context)),
        ],
      ),
    );
  }
}
