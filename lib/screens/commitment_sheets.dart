/// Everything a commitment needs from the user: recording a day, defining one,
/// picking a starter, and reading the rules.
///
/// All four go through `showGlassSheet`, so the visual language matches the rest of
/// the app. None of them writes anything the player cannot see: a sheet never saves
/// a value the user did not type, and never claims a result before the write
/// returns.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/design_system.dart';
import '../config/pro_config.dart';
import '../data/commitment_templates.dart';
import '../data/momentum.dart';
import '../main.dart' show TrackTheme;
import '../models/models.dart';
import '../services/haptics.dart';
import '../state/app_state.dart';
import '../util/day_key.dart';
import '../widgets/glass.dart';
import 'focus_history_screen.dart';
import 'focus_screen.dart';
import 'focus_setup_sheets.dart';
import 'log_sheets.dart';
import 'paywall_screen.dart';
import 'settings_screen.dart';

// ---------------------------------------------------------------- record a day
/// "What actually happened today?" — the tap that makes the whole system work.
///
/// The sheet always shows the commitment's own text (its full target and its
/// minimum), so the choice is between two things the user wrote, not two labels.
Future<void> showOutcomeSheet(BuildContext context, Commitment c, {int? day}) async {
  final state = context.read<AppState>();
  final key = day ?? state.commitmentRepo.todayKey;
  final existing = state.commitmentRepo.daysFor(c.id)[key];

  await showGlassSheet<void>(
    context,
    title: c.name,
    subtitle: c.scheduleLabel.isEmpty ? null : '${c.scheduleLabel} · ${shortDayKey(key)}',
    accent: c.color,
    body: _OutcomeBody(commitment: c, day: key, existing: existing),
    actions: const [],
  );
}

class _OutcomeBody extends StatefulWidget {
  const _OutcomeBody({required this.commitment, required this.day, this.existing});

  final Commitment commitment;
  final int day;
  final CommitmentDay? existing;

  @override
  State<_OutcomeBody> createState() => _OutcomeBodyState();
}

class _OutcomeBodyState extends State<_OutcomeBody> {
  final _note = TextEditingController();
  double? _amount;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _amount = widget.existing?.value;
    _note.text = widget.existing?.note ?? '';
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _record(DayOutcome outcome) async {
    if (_busy) return;
    setState(() => _busy = true);
    Haptics.light();
    final state = context.read<AppState>();
    final saved = await state.logCommitmentDay(
      widget.commitment.id,
      outcome,
      day: widget.day,
      value: _amount,
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
    );
    if (!mounted) return;
    if (!saved) {
      // The sheet stays open on a failed write, so the tap cannot look like a save.
      setState(() => _busy = false);
      showTrackToast(context, 'That did not save. Nothing about this day changed.');
      return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _clear() async {
    if (_busy) return;
    setState(() => _busy = true);
    final cleared = await context.read<AppState>().clearCommitmentDay(widget.commitment.id, day: widget.day);
    if (!mounted) return;
    if (!cleared) {
      setState(() => _busy = false);
      showTrackToast(context, 'That day could not be cleared. It is still recorded.');
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.commitment;
    final isToday = widget.day == context.read<AppState>().commitmentRepo.todayKey;
    // What the engine will do with whatever is chosen here, said out loud. This is
    // the sentence that stops "minimum" being mistaken for "done".
    final consequence = <DayOutcome, String>{
      DayOutcome.full: 'You did the whole thing.',
      DayOutcome.minimum: 'You did the minimum. It keeps your streak going, but it is not a full day.',
      DayOutcome.rest: 'A planned rest day. It does not count for or against you.',
      DayOutcome.skipped: 'Skipped on purpose. It does not break your streak.',
      DayOutcome.missed: 'You did not do it. This counts as a missed day.',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DefinitionRow(label: 'FULL', text: c.fullAction, color: Editorial.full),
        const SizedBox(height: Editorial.s2),
        _DefinitionRow(label: 'MINIMUM', text: c.minimumAction, color: Editorial.minimum),
        if (c.outcome.trim().isNotEmpty) ...[
          const SizedBox(height: Editorial.s3),
          Text(c.outcome, style: Editorial.caption.copyWith(color: Editorial.inkSecondary)),
        ],
        const SizedBox(height: Editorial.s5),
        for (final o in const [
          DayOutcome.full,
          DayOutcome.minimum,
          DayOutcome.missed,
          DayOutcome.rest,
          DayOutcome.skipped,
        ])
          _OutcomeTile(
            outcome: o,
            selected: widget.existing?.outcome == o,
            note: consequence[o] ?? '',
            accent: c.color,
            onTap: _busy ? null : () => _record(o),
          ),
        // Focus Lock, reachable from the routine it belongs to. The link is one-way
        // and honest: a session started here records focus time against this routine
        // as its goal, and marking THIS routine done is still done with the buttons
        // above. A blocked app is not a completed run of a run.
        const SizedBox(height: Editorial.s4),
        _FocusLink(commitment: c),
        const SizedBox(height: Editorial.s4),
        Text('AMOUNT (OPTIONAL)', style: Editorial.label),
        const SizedBox(height: Editorial.s2),
        _AmountField(initial: _amount, unit: c.fullAction, onChanged: (v) => _amount = v),
        const SizedBox(height: Editorial.s4),
        Text('NOTE (OPTIONAL)', style: Editorial.label),
        const SizedBox(height: Editorial.s2),
        Container(
          decoration: Editorial.card(fill: Editorial.well),
          padding: const EdgeInsets.symmetric(horizontal: Editorial.s3, vertical: Editorial.s2),
          child: TextField(
            controller: _note,
            maxLines: 2,
            style: Editorial.body.copyWith(color: Editorial.ink),
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              hintText: 'Anything worth remembering about today',
            ),
          ),
        ),
        if (widget.existing != null) ...[
          const SizedBox(height: Editorial.s4),
          TrackTintedButton(label: 'Clear this day', color: Editorial.danger, onTap: _busy ? null : _clear),
          const SizedBox(height: Editorial.s2),
          Text(
            isToday ? 'Clearing leaves today open.' : 'Clearing makes this day unlogged again.',
            style: Editorial.caption,
          ),
        ],
      ],
    );
  }
}

class _DefinitionRow extends StatelessWidget {
  const _DefinitionRow({required this.label, required this.text, required this.color});

  final String label;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(color: color.withValues(alpha: .16), borderRadius: BorderRadius.circular(6)),
          child: Text(label, style: Editorial.label.copyWith(color: color, letterSpacing: .8)),
        ),
        const SizedBox(width: Editorial.s3),
        Expanded(
          child: Text(
            text,
            style: Editorial.body.copyWith(color: Editorial.ink, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _OutcomeTile extends StatelessWidget {
  const _OutcomeTile({
    required this.outcome,
    required this.selected,
    required this.note,
    required this.accent,
    this.onTap,
  });

  final DayOutcome outcome;
  final bool selected;
  final String note;
  final Color accent;
  final VoidCallback? onTap;

  Color get _tint => switch (outcome) {
    DayOutcome.full => Editorial.full,
    DayOutcome.minimum => Editorial.minimum,
    DayOutcome.missed => Editorial.missed,
    DayOutcome.rest => Editorial.rest,
    DayOutcome.skipped => Editorial.rest,
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Editorial.s2),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: Editorial.medium,
          curve: Editorial.ease,
          decoration: Editorial.card(
            fill: selected ? _tint.withValues(alpha: .14) : Editorial.well,
            border: selected ? _tint : Editorial.hairline,
          ),
          padding: const EdgeInsets.symmetric(horizontal: Editorial.s4, vertical: Editorial.s3),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: _tint, shape: BoxShape.circle),
              ),
              const SizedBox(width: Editorial.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(outcome.verb, style: Editorial.figure),
                    const SizedBox(height: 2),
                    Text(note, style: Editorial.caption),
                  ],
                ),
              ),
              if (selected) Icon(Icons.check_rounded, size: 20, color: _tint),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small numeric field. Kept deliberately plain: the number is optional and the
/// outcome is what matters, so this cannot be mistaken for a required form.
class _AmountField extends StatefulWidget {
  const _AmountField({required this.initial, required this.unit, required this.onChanged});

  final double? initial;
  final String unit;
  final ValueChanged<double?> onChanged;

  @override
  State<_AmountField> createState() => _AmountFieldState();
}

class _AmountFieldState extends State<_AmountField> {
  late final TextEditingController _c = TextEditingController(
    text: widget.initial == null
        ? ''
        : (widget.initial! % 1 == 0 ? widget.initial!.toInt().toString() : widget.initial!.toString()),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: Editorial.card(fill: Editorial.well),
      padding: const EdgeInsets.symmetric(horizontal: Editorial.s3, vertical: Editorial.s2),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _c,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: Editorial.figure,
              decoration: const InputDecoration(border: InputBorder.none, isDense: true, hintText: 'Amount (optional)'),
              onChanged: (raw) {
                final parsed = double.tryParse(raw.trim());
                widget.onChanged(parsed);
              },
            ),
          ),
          if (widget.unit.trim().isNotEmpty)
            Text(widget.unit, style: Editorial.caption, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

/// --------------------------------------------------------------- starter picker
Future<void> showTemplatePicker(BuildContext context) async {
  final state = context.read<AppState>();
  await showGlassSheet<void>(
    context,
    title: 'Start a routine',
    subtitle: 'Pick a starter. You can change everything after.',
    accent: Editorial.accent,
    body: _TemplateBody(canAdd: state.canAddCommitment()),
    actions: const [],
  );
}

class _TemplateBody extends StatelessWidget {
  const _TemplateBody({required this.canAdd});

  final bool canAdd;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final categories = CommitmentTemplates.categories();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!canAdd)
          Container(
            margin: const EdgeInsets.only(bottom: Editorial.s4),
            padding: const EdgeInsets.all(Editorial.s4),
            decoration: Editorial.card(border: Editorial.accent.withValues(alpha: .5)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Free runs ${ProConfig.freeCommitmentLimit} routines at once',
                  style: Editorial.title.copyWith(fontSize: 16),
                ),
                const SizedBox(height: Editorial.s2),
                Text(ProConfig.commitmentCeilingCopy, style: Editorial.caption),
                const SizedBox(height: Editorial.s3),
                TrackTintedButton(
                  label: 'See Pro',
                  onTap: () => showPaywall(context, trigger: PaywallTrigger.commitmentLimit),
                ),
              ],
            ),
          ),
        for (final category in categories) ...[
          Padding(
            padding: const EdgeInsets.only(top: Editorial.s2, bottom: Editorial.s2),
            child: Text(category.toUpperCase(), style: Editorial.label),
          ),
          for (final t in CommitmentTemplates.all().where((t) => t.category == category))
            Padding(
              padding: const EdgeInsets.only(bottom: Editorial.s2),
              child: GestureDetector(
                onTap: () async {
                  Haptics.selection();
                  if (!state.canAddCommitment()) {
                    state.analytics?.log('pro_gate_tapped', {'gate': 'commitment_limit'});
                    showPaywall(context, trigger: PaywallTrigger.commitmentLimit);
                    return;
                  }
                  await state.addCommitmentFromTemplate(t);
                  if (context.mounted) Navigator.of(context).pop();
                },
                child: Container(
                  decoration: Editorial.card(),
                  padding: const EdgeInsets.symmetric(horizontal: Editorial.s4, vertical: Editorial.s3),
                  child: Row(
                    children: [
                      TrackRecordIcon(label: t.name, color: Editorial.accent, size: 38, iconSize: 20),
                      const SizedBox(width: Editorial.s3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t.name, style: Editorial.figure),
                            const SizedBox(height: 2),
                            Text(
                              'Full: ${t.fullAction}',
                              style: Editorial.caption.copyWith(color: Editorial.inkSecondary),
                            ),
                            Text('Minimum: ${t.minimumAction}', style: Editorial.caption),
                          ],
                        ),
                      ),
                      Icon(Icons.add_rounded, size: 20, color: Editorial.inkTertiary),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

/// ------------------------------------------------------------------- editor
/// Create or edit a commitment. Editing the schedule **adds a revision from today**,
/// so yesterday keeps the schedule it actually had; the sheet says so, because a
/// user who changes "daily" to "weekdays" deserves to know their past is not being
/// silently rewritten.
Future<void> showCommitmentEditor(BuildContext context, {Commitment? existing}) async {
  final state = context.read<AppState>();
  await showGlassSheet<void>(
    context,
    title: existing == null ? 'New routine' : existing.name,
    subtitle: existing == null
        ? 'Name the outcome, then the smallest version you would still count.'
        : 'Changes apply from today. Earlier days keep the plan they had.',
    accent: existing?.color ?? Editorial.accent,
    body: _EditorBody(existing: existing, state: state),
    actions: const [],
  );
}

class _EditorBody extends StatefulWidget {
  const _EditorBody({this.existing, required this.state});

  final Commitment? existing;
  final AppState state;

  @override
  State<_EditorBody> createState() => _EditorBodyState();
}

class _EditorBodyState extends State<_EditorBody> {
  // Keys remain the persisted emoji values used by existing databases, exports and
  // templates. The editor renders stable Material icons for them instead of glyphs.
  static const _iconChoices = <String, IconData>{
    '🚶': Icons.directions_walk_outlined,
    '🏋️': Icons.fitness_center_outlined,
    '📚': Icons.menu_book_outlined,
    '🌙': Icons.bedtime_outlined,
    '📖': Icons.auto_stories_outlined,
    '🧘': Icons.self_improvement_outlined,
    '💧': Icons.water_drop_outlined,
    '📝': Icons.edit_note_outlined,
    '🗂️': Icons.folder_outlined,
    '🏃': Icons.directions_run_outlined,
    '🫁': Icons.air_outlined,
    '🧹': Icons.cleaning_services_outlined,
  };
  static const _colors = [
    Color(0xFF5B7CFA),
    Color(0xFF3FB27F),
    Color(0xFFE0A44A),
    Color(0xFFE5484D),
    Color(0xFF8B5CF6),
    Color(0xFF22B8CF),
  ];

  late final TextEditingController _name = TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _outcome = TextEditingController(text: widget.existing?.outcome ?? '');
  late final TextEditingController _minimum = TextEditingController(text: widget.existing?.minimumAction ?? '');
  late final TextEditingController _full = TextEditingController(text: widget.existing?.fullAction ?? '');
  late String _emoji = widget.existing?.emoji ?? '🚶';
  late Color _color = widget.existing?.color ?? const Color(0xFF5B7CFA);
  late Set<int> _days = {
    ...(widget.existing?.schedule ?? const {1, 2, 3, 4, 5, 6, 7}),
  };

  /// Validation messages that appear only after the user tries to save, so an empty
  /// form does not open already scolding.
  List<String> _errors = const [];

  @override
  void dispose() {
    _name.dispose();
    _outcome.dispose();
    _minimum.dispose();
    _full.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final errors = <String>[];
    if (_name.text.trim().isEmpty) errors.add('Give it a name you will recognise.');
    if (_full.text.trim().isEmpty) errors.add('The full target cannot be empty — that is the thing being kept.');
    if (_minimum.text.trim().isEmpty) {
      errors.add('Add a minimum. A routine without a fallback is the one people abandon.');
    }
    if (_days.isEmpty) errors.add('Pick at least one day.');

    setState(() => _errors = errors);
    if (errors.isNotEmpty) return;

    Haptics.light();
    final state = widget.state;
    final existing = widget.existing;
    try {
      if (existing == null) {
        await state.addCommitment(
          name: _name.text,
          emoji: _emoji,
          color: _color,
          outcome: _outcome.text,
          minimumAction: _minimum.text,
          fullAction: _full.text,
          weekdays: _days,
        );
      } else {
        await state.updateCommitment(
          existing.copyWith(
            name: _name.text.trim(),
            emoji: _emoji,
            color: _color,
            outcome: _outcome.text.trim(),
            minimumAction: _minimum.text.trim(),
            fullAction: _full.text.trim(),
          ),
          weekdays: _days,
        );
      }
    } catch (_) {
      if (!mounted) return;
      showTrackToast(context, 'That routine was not saved. Nothing was changed.');
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final existing = widget.existing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Field(label: 'WHAT DO YOU WANT OUT OF IT?', controller: _outcome, hint: 'Get through a 5k without stopping'),
        const SizedBox(height: Editorial.s4),
        _Field(label: 'NAME', controller: _name, hint: 'Run'),
        const SizedBox(height: Editorial.s4),
        _Field(label: 'FULL TARGET', controller: _full, hint: 'Run 5 km'),
        const SizedBox(height: Editorial.s4),
        _Field(
          label: 'MINIMUM — THE SMALLEST VERSION YOU WOULD STILL COUNT',
          controller: _minimum,
          hint: 'Put shoes on, walk 5 minutes',
        ),
        const SizedBox(height: Editorial.s5),
        Text('DAYS', style: Editorial.label),
        const SizedBox(height: Editorial.s2),
        Wrap(
          spacing: Editorial.s2,
          children: [
            for (var d = 1; d <= 7; d++)
              GestureDetector(
                onTap: () => setState(() {
                  if (_days.contains(d)) {
                    _days.remove(d);
                  } else {
                    _days.add(d);
                  }
                }),
                child: AnimatedContainer(
                  duration: Editorial.fast,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _days.contains(d) ? _color.withValues(alpha: .2) : Editorial.well,
                    borderRadius: BorderRadius.circular(Editorial.rPill),
                    border: Border.all(color: _days.contains(d) ? _color : Editorial.hairline, width: .5),
                  ),
                  child: Text(
                    weekdayName(d, short: true),
                    style: Editorial.caption.copyWith(color: _days.contains(d) ? Editorial.ink : Editorial.inkTertiary),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: Editorial.s5),
        Text('ICON', style: Editorial.label),
        const SizedBox(height: Editorial.s2),
        Wrap(
          spacing: Editorial.s2,
          runSpacing: Editorial.s2,
          children: [
            for (final choice in _iconChoices.entries)
              GestureDetector(
                onTap: () => setState(() => _emoji = choice.key),
                child: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _emoji == choice.key ? _color.withValues(alpha: .18) : Editorial.well,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _emoji == choice.key ? _color : Editorial.hairline, width: .5),
                  ),
                  child: Icon(choice.value, size: 20, color: _emoji == choice.key ? _color : Editorial.inkSecondary),
                ),
              ),
          ],
        ),
        const SizedBox(height: Editorial.s4),
        Text('COLOUR', style: Editorial.label),
        const SizedBox(height: Editorial.s2),
        Row(
          children: [
            for (final c in _colors)
              GestureDetector(
                onTap: () => setState(() => _color = c),
                child: Container(
                  margin: const EdgeInsets.only(right: Editorial.s3),
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(color: _color == c ? Editorial.ink : Colors.transparent, width: 2),
                  ),
                ),
              ),
          ],
        ),
        if (_errors.isNotEmpty) ...[
          const SizedBox(height: Editorial.s5),
          for (final e in _errors)
            Padding(
              padding: const EdgeInsets.only(bottom: Editorial.s1),
              child: Text('• $e', style: Editorial.caption.copyWith(color: Editorial.danger)),
            ),
        ],
        const SizedBox(height: Editorial.s6),
        TrackFilledButton(label: existing == null ? 'Start the routine' : 'Save changes', color: _color, onTap: _save),
        const SizedBox(height: Editorial.s4),
        if (existing != null) ...[
          Text('PAUSING AND ENDING', style: Editorial.label),
          const SizedBox(height: Editorial.s2),
          GlassList(
            children: [
              GlassRow(
                title: state.isCommitmentPaused(existing.id) ? 'Resume counting' : 'Pause for a while',
                subtitle: state.isCommitmentPaused(existing.id)
                    ? 'Days are counted again, starting today'
                    : 'Paused days are not counted, and are not judged as misses',
                leading: const Icon(Icons.pause_circle_outline_rounded, size: 18, color: Editorial.minimum),
                accent: Editorial.minimum,
                showChevron: false,
                onTap: () async {
                  if (state.isCommitmentPaused(existing.id)) {
                    await state.resumeCommitment(existing.id);
                  } else {
                    await state.pauseCommitment(existing.id);
                  }
                  if (context.mounted) setState(() {});
                },
              ),
              GlassRow(
                title: existing.archived ? 'Bring it back' : 'Archive it',
                subtitle: existing.archived
                    ? 'Returns to your active routines with its history intact'
                    : 'Stops counting, keeps every recorded day',
                leading: const Icon(Icons.archive_outlined, size: 18, color: Editorial.accent),
                accent: Editorial.accent,
                showChevron: false,
                onTap: () async {
                  await state.archiveCommitment(existing.id, archived: !existing.archived);
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
              GlassRow(
                title: 'Delete for good',
                subtitle: 'Removes the routine and every day recorded against it',
                leading: const Icon(Icons.delete_outline_rounded, size: 18, color: Editorial.danger),
                accent: Editorial.danger,
                showChevron: false,
                onTap: () async {
                  final ok = await showTrackConfirm(
                    context,
                    title: 'Delete “${existing.name}”?',
                    body:
                        'This deletes the routine and its ${state.commitmentRepo.daysFor(existing.id).length} '
                        'recorded days. Export first from Profile if you want a copy.',
                    confirmLabel: 'Delete',
                  );
                  if (!ok) return;
                  await state.deleteCommitment(existing.id);
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.controller, required this.hint});

  final String label;
  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Editorial.label),
        const SizedBox(height: Editorial.s2),
        Container(
          decoration: Editorial.card(fill: Editorial.well),
          padding: const EdgeInsets.symmetric(horizontal: Editorial.s3, vertical: Editorial.s2),
          child: TextField(
            controller: controller,
            maxLines: null,
            style: Editorial.body.copyWith(color: Editorial.ink, fontWeight: FontWeight.w600),
            decoration: InputDecoration(border: InputBorder.none, isDense: true, hintText: hint),
          ),
        ),
      ],
    );
  }
}

/// ----------------------------------------------------------------- explainer
/// The rules, in the app, where the numbers are.
///
/// This sheet is not marketing copy: every constant it prints is read from
/// [MomentumEngine], so if a threshold changes the explanation changes with it and
/// cannot drift out of date.
Future<void> showMomentumExplainer(BuildContext context) async {
  await showGlassSheet<void>(
    context,
    title: 'How momentum works',
    subtitle: 'Short, and the same rule for every routine.',
    accent: Editorial.accent,
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Rule(
          title: 'Which days count',
          body:
              'The weekdays you picked for the routine. Rest days, pauses and days before you '
              'created it never count for or against you.',
        ),
        _Rule(
          title: 'What counts',
          body:
              'A full day counts fully. A minimum keeps your streak alive and counts partly. '
              'A miss counts as a day you planned and did not do. Today is never judged until '
              'it is over.',
        ),
        _Rule(
          title: 'The percentage',
          body:
              'Your kept days divided by the days you planned, over the last '
              '${MomentumEngine.rateWindowDays} days. It appears once there are '
              '${MomentumEngine.minDecidedDaysForRate} days to measure, because a percentage of '
              'two days is noise.',
        ),
        _Rule(
          title: 'Streaks and restarts',
          body:
              'A streak counts consecutive planned days you kept. After '
              '${MomentumEngine.recoveryGap} planned days with nothing logged, Momentum suggests a '
              'smaller way back in.',
        ),
        const SizedBox(height: Editorial.s2),
        Text(
          'None of this measures willpower or worth. It is the days you did the thing, against '
          'the days you said you would.',
          style: Editorial.caption.copyWith(color: Editorial.inkSecondary),
        ),
      ],
    ),
    actions: const [],
  );
}

class _Rule extends StatelessWidget {
  const _Rule({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Editorial.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Editorial.figure),
          const SizedBox(height: Editorial.s1),
          Text(body, style: Editorial.body.copyWith(color: Editorial.inkSecondary, fontSize: 14)),
        ],
      ),
    );
  }
}

/// Focus Lock, from inside a routine.
///
/// Two rows, both optional: start a session aimed at this routine, or read the focus
/// history. It is here rather than only on Today because "I am about to do this, help
/// me not do anything else" is the moment the feature is for.
class _FocusLink extends StatelessWidget {
  const _FocusLink({required this.commitment});

  final Commitment commitment;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final live = app.activeFocusSession;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return GlassList(
      children: [
        GlassRow(
          title: live == null ? 'Start a focus session for this' : 'A session is already running',
          subtitle: live == null
              ? 'Timer, blocking or deep focus — linked to ${commitment.name}'
              : '${live.goalLabel} · ${live.mode.label}',
          leading: const Icon(Icons.track_changes_outlined, size: 18, color: TrackTheme.orange),
          accent: commitment.color,
          onTap: () async {
            // This sheet is closing, so the follow-up runs through the navigator's own
            // context (which outlives the pop) rather than through a context that is on
            // its way out.
            final navigator = Navigator.of(context);
            final host = navigator.context;
            navigator.pop();
            if (live == null) {
              await showFocusStartSheet(
                host,
                commitmentId: commitment.id,
                goalLabel: commitment.name,
                // A profile already linked to this routine carries the app list the user
                // chose for it, so the sheet opens pre-filled rather than blank.
                packages: app.focusProfiles
                    .where((p) => p.commitmentId == commitment.id)
                    .expand((p) => p.packages)
                    .toSet()
                    .toList(),
              );
            } else {
              await openFocusSession(host);
            }
          },
        ),
        GlassRow(
          title: 'Focus history',
          subtitle: app.focusStats.endedSessions == 0
              ? 'Nothing recorded yet'
              : '${app.focusStats.endedSessions} session${app.focusStats.endedSessions == 1 ? '' : 's'} · '
                    '${app.focusStats.minutesTotal} minutes',
          leading: const Icon(Icons.history_rounded, size: 18, color: TrackTheme.orange),
          accent: TrackTheme.indigo,
          onTap: () {
            final navigator = Navigator.of(context);
            navigator.pop();
            navigator.push(MaterialPageRoute<void>(builder: (_) => const FocusHistoryScreen()));
          },
        ),
        if (!app.hasFocusSupport)
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 10, 15, 12),
            child: Text(
              'This build has no focus channel behind it, so a session here would be a timer only — and it '
              'would say so rather than pretend.',
              style: TextStyle(fontSize: 12, height: 1.45, fontWeight: FontWeight.w500, color: TrackTheme.label3(dark)),
            ),
          ),
      ],
    );
  }
}
