import 'package:flutter/cupertino.dart';
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

/// Routines — where commitments are created, edited, paused and retired.
///
/// This screen is deliberately about *definitions*. Today's actions live on Today,
/// and the record lives on Momentum; mixing the three is how habit apps end up
/// showing the same thing four times.
class RoutinesScreen extends StatelessWidget {
  const RoutinesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final active = state.commitments;
    final archived = state.archivedCommitments;

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      slivers: [
        SliverToBoxAdapter(
          child: LargeTitleHeader(
            title: 'Routines',
            subtitle: active.isEmpty
                ? 'No routines yet'
                : '${active.length} active'
                    '${state.hasCommitments && state.bestCommitmentStreak > 0 ? ' · best run ${state.bestCommitmentStreak} days' : ''}',
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(Editorial.s4, Editorial.s1, Editorial.s4, 130),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              if (active.isEmpty)
                _EmptyRoutines()
              else
                for (final c in active) ...[
                  _RoutineRow(state: state, commitment: c),
                  const SizedBox(height: Editorial.s3),
                ],
              if (active.isNotEmpty) ...[
                const SizedBox(height: Editorial.s2),
                Row(
                  children: [
                    Expanded(
                      child: TrackFilledButton(
                        label: 'Start a routine',
                        onTap: () => state.canAddCommitment()
                            ? showTemplatePicker(context)
                            : showPaywall(context, trigger: PaywallTrigger.commitmentLimit),
                      ),
                    ),
                    const SizedBox(width: Editorial.s2),
                    Expanded(
                      child: TrackTintedButton(
                        label: 'From scratch',
                        // The other creation path used to skip the limit entirely, so
                        // "Free includes 3 routines" was true on one button and false on
                        // the one beside it.
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
              GlassList(children: [
                GlassRow(
                  title: 'Water, mood, money, sleep…',
                  subtitle: 'The measurement trackers live here now — separate from habits, because '
                      '"how much" and "did you" are different questions',
                  leading: const Text('📊', style: TextStyle(fontSize: 15)),
                  accent: Editorial.accent,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const MeasurementsPage()),
                  ),
                ),
              ]),
            ]),
          ),
        ),
      ],
    );
  }

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
            ['Log today', CupertinoIcons.checkmark_circle, false],
            [paused ? 'Resume' : 'Pause', CupertinoIcons.pause_circle, false],
            [archived ? 'Restore' : 'Archive', CupertinoIcons.archivebox, false],
            ['Delete', CupertinoIcons.trash, true],
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
              body: 'This removes the routine and its '
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
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: c.color.withOpacity(.16), borderRadius: BorderRadius.circular(13)),
                child: Text(c.emoji, style: const TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: Editorial.s4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(child: Text(c.name, style: Editorial.figure.copyWith(fontSize: 16), overflow: TextOverflow.ellipsis)),
                        if (!archived && logged) ...[
                          const SizedBox(width: Editorial.s2),
                          Icon(CupertinoIcons.checkmark_seal_fill, size: 13, color: Editorial.full),
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
                    logged ? CupertinoIcons.checkmark_circle : CupertinoIcons.circle,
                    size: 22,
                    color: logged ? Editorial.full : Editorial.inkTertiary,
                  ),
                ),
              const SizedBox(width: Editorial.s2),
              Icon(CupertinoIcons.chevron_right, size: 15, color: Editorial.inkTertiary),
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
          TrackFilledButton(
            label: 'Create your first routine',
            onTap: () => showTemplatePicker(context),
          ),
          const SizedBox(height: Editorial.s2),
          TrackTintedButton(
            label: 'Build one yourself',
            onTap: () => showCommitmentEditor(context),
          ),
        ],
      ),
    );
  }
}
