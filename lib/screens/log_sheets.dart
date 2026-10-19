import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/haptics.dart';

import '../main.dart' show TrackTheme;
import '../models/models.dart';
import '../data/food_reference.dart';
import '../state/app_state.dart';
import '../util/day_key.dart';
import '../util/format.dart';
import '../widgets/glass.dart';
import 'paywall_screen.dart';

/// The soft prompt, deferred behind the toast.
///
/// It only ever fires when the user has real value to lose (a 7-day streak, or a
/// tracker ceiling they just walked into) and never more than once a fortnight —
/// all of that logic lives in `maybeShowSoftPrompt`. Deferring by a beat matters:
/// interrupting the confirmation the user just earned reads as a bait-and-switch,
/// while asking 900ms later reads as a suggestion.
void nudgeProIfDue(BuildContext context, AppState state) {
  Future<void>.delayed(const Duration(milliseconds: 900), () {
    if (context.mounted) maybeShowSoftPrompt(context, state);
  });
}

/// A tiny in-app toast so every log gives visual confirmation (paired with a
/// real haptic on device) without pulling in a package.
void showTrackToast(BuildContext context, String message) {
  final overlay = Overlay.of(context);
  final dark = Theme.of(context).brightness == Brightness.dark;
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _ToastHost(message: message, dark: dark, onDone: () => entry.remove()),
  );
  overlay.insert(entry);
}

/// The primary action of a log sheet, in one place.
///
/// Two things were wrong with how these were written, and both are fixed here rather
/// than in six near-identical copies:
///
/// 1. `Navigator.pop()` came **before** the write. The sheet was already leaving the
///    screen while its button was still live, so a second tap inside the dismiss
///    animation wrote a second time — a calorie delta counted twice, an expense booked
///    twice. [SubmitOnce] latches the button off the moment the action runs.
/// 2. A refused value still produced a success toast. Now the sheet closes only on a
///    write it can stand behind; a refusal says so and leaves the value on screen to
///    correct, instead of disappearing behind a green tick.
///
/// `write` is evaluated on the tap, not when the sheet was built, so it reads the
/// value the user actually settled on.
Widget _sheetAction({
  required BuildContext context,
  required String label,
  required Color color,
  required bool Function() write,
  required String success,
  VoidCallback? after,
}) {
  return SubmitOnce(
    onSubmit: () async {
      if (!context.mounted) return true;
      if (!write()) {
        showTrackToast(context, 'Nothing was saved — that value was refused.');
        return false;
      }
      Navigator.of(context).pop();
      showTrackToast(context, success);
      after?.call();
      return true;
    },
    builder: (context, submit) => TrackFilledButton(label: label, color: color, onTap: submit),
  );
}

class _ToastHost extends StatefulWidget {
  const _ToastHost({required this.message, required this.dark, required this.onDone});

  final String message;
  final bool dark;
  final VoidCallback onDone;

  @override
  State<_ToastHost> createState() => _ToastHostState();
}

class _ToastHostState extends State<_ToastHost> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 260))..forward();

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 2000), () async {
      if (mounted) await c.reverse();
      widget.onDone();
    });
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 122 + bottom,
      child: IgnorePointer(
        child: FadeTransition(
          opacity: c,
          child: Center(
            child: TrackTheme.frosted(
              dark: widget.dark,
              radius: 20,
              strong: true,
              padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 11),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: TrackTheme.green,
                      boxShadow: [BoxShadow(color: TrackTheme.green.withOpacity(.5), blurRadius: 8, spreadRadius: 2)],
                    ),
                  ),
                  const SizedBox(width: 9),
                  Text(widget.message,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: -.2, color: TrackTheme.label(widget.dark))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Log sheets — one entry point, a bespoke affordance per metric kind.
/// ---------------------------------------------------------------------------
Future<void> openLogSheet(BuildContext context, Tracker t) async {
  final state = context.read<AppState>();
  final value = ValueNotifier<double>(state.today(t.id));

  switch (t.id) {
    case 'mood':
      return showGlassSheet<void>(
        context,
        title: 'How was today?',
        subtitle: 'Mood · tap a face to log instantly',
        accent: t.accent,
        body: _MoodBody(onPick: (v) {
          // Write first, then close: the toast describes what was stored, not what was
          // intended.
          final ok = state.log(t.id, v);
          Navigator.of(context).pop();
          showTrackToast(context,
              ok ? 'Mood logged · ${fmtValue(t, v)}' : 'That entry was refused — nothing was logged.');
        }),
        actions: [TrackTintedButton(label: 'Cancel', onTap: () => Navigator.of(context).pop())],
      );
    case 'habits':
      return showGlassSheet<void>(
        context,
        title: 'Today\'s habits',
        subtitle: '${state.habits.where((h) => h.done).length} of ${state.habits.length} complete',
        accent: t.accent,
        body: _HabitBody(state: state),
        actions: [
          _sheetAction(
            context: context,
            label: 'Save habits',
            color: t.accent,
            // The checkboxes wrote themselves; this only confirms the rollup the user
            // can see. No write is claimed that has not already happened.
            write: () => true,
            success: 'Habits saved · ${state.habits.where((h) => h.done).length}/${state.habits.length}',
            // The habit loop is where a 7-day streak becomes worth protecting.
            after: () => nudgeProIfDue(context, state),
          ),
          TrackTintedButton(label: 'Cancel', onTap: () => Navigator.of(context).pop()),
        ],
      );
    case 'expenses':
      return showGlassSheet<void>(
        context,
        title: 'Add expense',
        subtitle: 'Today: ${fmtValue(t, state.today(t.id))} of ₹${t.goal.round()}',
        accent: t.accent,
        body: _ExpenseBody(value: value),
        actions: [
          _sheetAction(
            context: context,
            label: 'Add to today',
            color: t.accent,
            // The sheet's answer is the *write's* answer. It used to be its own
            // `amount > 0` test, which confirmed a success that had been refused or
            // clamped by the state layer.
            write: () => state.addExpense(value.value, 'Other'),
            success: 'Expense logged · ₹${value.value.round()}',
          ),
          TrackTintedButton(label: 'Cancel', onTap: () => Navigator.of(context).pop()),
        ],
      );
    case 'sleep':
      return showGlassSheet<void>(
        context,
        title: 'Last night\'s sleep',
        subtitle: 'Hours + quality · 7-day avg ${state.avg('sleep', 7).toStringAsFixed(1)} h',
        accent: t.accent,
        body: _SleepBody(value: value, start: state.today('sleep')),
        actions: [
          _sheetAction(
            context: context,
            label: 'Save sleep',
            color: t.accent,
            write: () => state.log('sleep', value.value),
            success: 'Sleep logged · ${value.value.toStringAsFixed(1)} h',
          ),
          TrackTintedButton(label: 'Cancel', onTap: () => Navigator.of(context).pop()),
        ],
      );
    case 'calories':
      return showGlassSheet<void>(
        context,
        title: 'Add food',
        subtitle: '${fmtValue(t, state.today(t.id))} of ${t.goal.round()} kcal today',
        accent: t.accent,
        body: _CalorieBody(value: value, onFood: (kcal, name) {
          // A food item is a genuine *delta* — it is added to today's running total.
          final ok = state.logAdd('calories', kcal);
          Navigator.of(context).pop();
          showTrackToast(context, ok ? 'Added $name · $kcal kcal' : '$name was not added — that amount was refused.');
        }, start: state.today('calories')),
        actions: [
          _sheetAction(
            context: context,
            // "Add" described a delta; this button stores the day's total. The label
            // says which of the two it is, so the sheet cannot be misread.
            label: 'Save total',
            color: t.accent,
            // `value` here is the day's running total (the stepper is seeded from it and
            // every food tap moves it), so it is an absolute value for the day. Sending
            // it to the delta API added today's calories to themselves: log 1,800, tap
            // Add, and the day read 3,600.
            write: () => state.log('calories', value.value),
            success: 'Calories · ${value.value.round()} kcal today',
          ),
          TrackTintedButton(label: 'Cancel', onTap: () => Navigator.of(context).pop()),
        ],
      );
    case 'period':
      // One draft per sheet: the body renders from it and the action reads it, so there
      // is exactly one copy of what the user chose.
      final draft = _PeriodDraft();
      return showGlassSheet<void>(
        context,
        title: 'Log period',
        subtitle: 'Cycle day ${state.today('period').round()} · next in ${28 - state.today('period').round()} days',
        accent: t.accent,
        body: _PeriodBody(draft: draft),
        actions: [
          _sheetAction(
            context: context,
            label: 'Save',
            color: t.accent,
            // Before this, "Save" popped and toasted "Cycle updated" without writing a
            // single thing the user had tapped: the flow and the symptom chips lived
            // inside the body widget and were discarded with it.
            write: () => state.logPeriod(flow: draft.flow, symptoms: draft.symptoms.toList()),
            success: 'Cycle logged · day ${state.today('period').round()}',
          ),
          TrackTintedButton(label: 'Cancel', onTap: () => Navigator.of(context).pop()),
        ],
      );
    default:
      return showGlassSheet<void>(
        context,
        title: 'Log ${t.name}',
        subtitle: 'Today · goal ${fmtGoalLong(t)}',
        accent: t.accent,
        body: _StepperBody(
          tracker: t,
          value: value,
          start: state.today(t.id),
          presets: _presetsFor(t),
          min: 0,
          max: t.kind == MetricKind.steps ? 40000 : t.goal * 3,
        ),
        actions: [
          _sheetAction(
            context: context,
            label: 'Save',
            color: t.accent,
            write: () => state.log(t.id, value.value),
            success: '${t.name} logged · ${fmtValue(t, value.value)}',
            // Hitting the ceiling is the moment the ask is most concrete.
            after: () => nudgeProIfDue(context, state),
          ),
          TrackTintedButton(label: 'Cancel', onTap: () => Navigator.of(context).pop()),
        ],
      );
  }
}

List<double> _presetsFor(Tracker t) {
  switch (t.kind) {
    case MetricKind.volume:
      return [t.goal * .5, t.goal, t.goal * 1.2];
    case MetricKind.steps:
      return [5000, 8000, 10000];
    case MetricKind.minutes:
      return [120, 180, 240];
    case MetricKind.weight:
      return [t.goal + 2, t.goal + 1, t.goal];
    default:
      return [t.goal * .5, t.goal, t.goal * 1.25];
  }
}

/// Big −/+ stepper with a live ring preview and preset chips.
class _StepperBody extends StatefulWidget {
  const _StepperBody({
    required this.tracker,
    required this.value,
    required this.start,
    required this.presets,
    required this.min,
    required this.max,
    this.increment,
  });

  final Tracker tracker;
  final ValueNotifier<double> value;
  final double start;
  final List<double> presets;
  final double min;
  final double max;
  final double? increment;

  @override
  State<_StepperBody> createState() => _StepperBodyState();
}

class _StepperBodyState extends State<_StepperBody> {
  @override
  void initState() {
    super.initState();
    widget.value.value = widget.start;
  }

  void _bump(double dir) {
    final step = widget.increment ?? widget.tracker.step;
    setState(() => widget.value.value = (widget.value.value + dir * step).clamp(widget.min, widget.max).toDouble());
    Haptics.selection();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tracker;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _RoundBtn(icon: Icons.remove_rounded, color: t.accent, onTap: () => _bump(-1)),
            Container(
              width: 150,
              alignment: Alignment.center,
              child: Column(
                children: [
                  Text(
                    t.kind == MetricKind.money ? '₹${widget.value.value.round()}' : fmtValue(t, widget.value.value),
                    style: TextStyle(fontSize: 40, fontWeight: FontWeight.w700, letterSpacing: -1.4, color: TrackTheme.label(dark)),
                  ),
                  Text('of ${fmtGoalLong(t)}',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: TrackTheme.label3(dark))),
                ],
              ),
            ),
            _RoundBtn(icon: Icons.add_rounded, color: t.accent, onTap: () => _bump(1)),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (final p in widget.presets)
              _Chip(
                label: t.kind == MetricKind.money ? '₹${p.round()}' : fmtValue(t, p),
                color: t.accent,
                onTap: () {
                  setState(() => widget.value.value = p.clamp(widget.min, widget.max).toDouble());
                  Haptics.selection();
                },
              ),
          ],
        ),
      ],
    );
  }
}

class _RoundBtn extends StatelessWidget {
  const _RoundBtn({required this.icon, required this.color, required this.onTap});

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 60,
        height: 60,
        alignment: Alignment.center,
        decoration: BoxDecoration(shape: BoxShape.circle, color: TrackTheme.fill(dark)),
        child: Icon(icon, size: 26, color: color),
      ),
    );
  }
}

class _Chip extends StatefulWidget {
  const _Chip({required this.label, required this.color, required this.onTap, this.active = false});

  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool active;

  @override
  State<_Chip> createState() => _ChipState();
}

class _ChipState extends State<_Chip> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? .94 : 1,
        duration: const Duration(milliseconds: 180),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            color: widget.active ? widget.color : TrackTheme.fill(dark),
            borderRadius: BorderRadius.circular(11),
            boxShadow: widget.active
                ? [BoxShadow(color: widget.color.withOpacity(.5), blurRadius: 16, offset: const Offset(0, 6), spreadRadius: -8)]
                : null,
          ),
          child: Text(widget.label,
              style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: widget.active ? Colors.white : TrackTheme.label(dark))),
        ),
      ),
    );
  }
}

class _MoodBody extends StatelessWidget {
  const _MoodBody({required this.onPick});

  final void Function(double) onPick;

  @override
  Widget build(BuildContext context) {
    const faces = [
      Icons.sentiment_very_dissatisfied_outlined,
      Icons.sentiment_dissatisfied_outlined,
      Icons.sentiment_neutral_outlined,
      Icons.sentiment_satisfied_alt_outlined,
      Icons.sentiment_very_satisfied_outlined,
    ];
    const words = ['Awful', 'Low', 'Okay', 'Good', 'Great'];
    return Row(
      children: [
        for (var i = 0; i < 5; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i == 4 ? 0 : 6),
              child: GestureDetector(
                onTap: () => onPick((i + 1).toDouble()),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? TrackTheme.fill(true)
                        : TrackTheme.orange.withOpacity(.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      Icon(faces[i], size: 26, color: TrackTheme.orange),
                      const SizedBox(height: 5),
                      Text(words[i],
                          style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: TrackTheme.label2(Theme.of(context).brightness == Brightness.dark))),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _HabitBody extends StatelessWidget {
  const _HabitBody({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) => GlassList(
        children: [
          for (var i = 0; i < state.habits.length; i++)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                Haptics.selection();
                state.toggleHabit(i);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                child: Row(
                  children: [
                    TrackRecordIcon(label: state.habits[i].name, color: state.habits[i].color, size: 29, iconSize: 16),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(state.habits[i].name,
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, letterSpacing: -.32, color: TrackTheme.label(dark))),
                          Text('${state.habits[i].streak}-day streak',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: TrackTheme.label3(dark))),
                        ],
                      ),
                    ),
                    _Switch(value: state.habits[i].done),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Expense capture: category chips + a big money stepper that adds to today.
class _ExpenseBody extends StatefulWidget {
  const _ExpenseBody({required this.value});

  final ValueNotifier<double> value;

  @override
  State<_ExpenseBody> createState() => _ExpenseBodyState();
}

class _ExpenseBodyState extends State<_ExpenseBody> {
  String selected = 'Food';

  @override
  Widget build(BuildContext context) {
    const cats = ['Food', 'Groceries', 'Transport', 'Shopping', 'Bills', 'Fun', 'Health'];
    return Column(
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in cats)
              _Chip(
                label: c,
                color: TrackTheme.green,
                active: c == selected,
                onTap: () => setState(() => selected = c),
              ),
          ],
        ),
        const SizedBox(height: 18),
        _StepperBody(
          tracker: _moneyTracker(),
          value: widget.value,
          start: 300,
          min: 0,
          max: 20000,
          increment: 10,
          presets: const [100, 250, 500, 1000],
        ),
      ],
    );
  }
}

Tracker _moneyTracker() => Tracker(
      id: 'expenses',
      name: 'Expenses',
      emoji: '💰',
      accent: TrackTheme.green,
      accent2: TrackTheme.mint,
      kind: MetricKind.money,
      goal: 1500,
      step: 10,
      unit: '₹',
      blurb: '',
      insight: '',
    );

/// Sleep: hours stepper + a quality segmented control.
class _SleepBody extends StatefulWidget {
  const _SleepBody({required this.value, required this.start});

  final ValueNotifier<double> value;
  final double start;

  @override
  State<_SleepBody> createState() => _SleepBodyState();
}

class _SleepBodyState extends State<_SleepBody> {
  int quality = 2;

  @override
  Widget build(BuildContext context) {
    final t = Tracker(
      id: 'sleep',
      name: 'Sleep',
      emoji: '😴',
      accent: TrackTheme.indigo,
      accent2: TrackTheme.purple,
      kind: MetricKind.hours,
      goal: 8,
      step: .5,
      unit: 'h',
      blurb: '',
      insight: '',
    );
    const labels = ['Poor', 'Fair', 'Good', 'Great'];
    return Column(
      children: [
        _StepperBody(
          tracker: t,
          value: widget.value,
          start: widget.start,
          min: 0,
          max: 14,
          presets: const [6, 7, 7.5, 8, 9],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            for (var i = 0; i < labels.length; i++)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i == labels.length - 1 ? 0 : 8),
                  child: _Chip(
                    label: labels[i],
                    color: TrackTheme.indigo,
                    active: i == quality,
                    onTap: () => setState(() => quality = i),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text('Quality feeds the sleep ⇄ mood pattern on Insights.',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: TrackTheme.label3(Theme.of(context).brightness == Brightness.dark))),
      ],
    );
  }
}

/// Calories: quick-add foods, or a manual stepper.
class _CalorieBody extends StatelessWidget {
  const _CalorieBody({required this.value, required this.onFood, required this.start});

  final ValueNotifier<double> value;
  final void Function(int kcal, String name) onFood;
  final double start;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final t = Tracker(
      id: 'calories',
      name: 'Calories',
      emoji: '🔥',
      accent: const Color(0xFFFF6B22),
      accent2: TrackTheme.orange,
      kind: MetricKind.calories,
      goal: 2200,
      step: 50,
      unit: 'kcal',
      blurb: '',
      insight: '',
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('Quick add'),
        GlassList(
          children: [
            for (final f in FoodReference.common)
              GlassRow(
                title: f.name,
                subtitle: 'tap to add',
                leading: const Icon(Icons.restaurant_outlined, size: 18, color: TrackTheme.orange),
                trailing: Text('${f.kcal} kcal',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: TrackTheme.label2(dark))),
                accent: TrackTheme.orange,
                showChevron: false,
                onTap: () => onFood(f.kcal, f.name),
              ),
          ],
        ),
        const SectionLabel('Or enter manually'),
        _StepperBody(
          tracker: t,
          value: value,
          start: start,
          min: 0,
          max: 3000,
          increment: 50,
          presets: const [200, 350, 500],
        ),
      ],
    );
  }
}

/// Period: flow chips + symptom chips.
/// What the period sheet collected.
///
/// It lives outside the body on purpose: the body used to own this privately, and the
/// sheet's "Save" had no way to see it — which is why it toasted "Cycle updated" over a
/// discarded selection. One draft per sheet, rendered and edited by the body, read by
/// the action.
class _PeriodDraft {
  int flow = 0;
  final Set<String> symptoms = <String>{};
}

class _PeriodBody extends StatefulWidget {
  const _PeriodBody({required this.draft});

  final _PeriodDraft draft;

  @override
  State<_PeriodBody> createState() => _PeriodBodyState();
}

class _PeriodBodyState extends State<_PeriodBody> {
  int get flow => widget.draft.flow;
  Set<String> get symptoms => widget.draft.symptoms;

  @override
  Widget build(BuildContext context) {
    const flows = ['None', 'Spotting', 'Light', 'Medium', 'Heavy'];
    const symp = ['Cramps', 'Headache', 'Bloating', 'Fatigue', 'Back pain', 'Tender'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('Flow'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < flows.length; i++)
              _Chip(
                label: flows[i],
                color: TrackTheme.pink,
                active: i == flow,
                onTap: () => setState(() => widget.draft.flow = i),
              ),
          ],
        ),
        const SectionLabel('Symptoms'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in symp)
              _Chip(
                label: s,
                color: TrackTheme.pink,
                active: symptoms.contains(s),
                onTap: () => setState(() => symptoms.contains(s) ? symptoms.remove(s) : symptoms.add(s)),
              ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

/// Where a stored value came from, in the user's words rather than the database's.
String _sourceWords(String source) {
  switch (source) {
    case 'health':
      return 'synced from Health';
    case 'usage':
      return 'read from Android Usage Access';
    case 'widget':
      return 'from the widget';
    case 'import':
      return 'from an import';
    case 'demo':
      // Should not exist in a shipped build; if it ever does, say so instead of
      // dressing sample data up as the user's own.
      return 'from sample data';
    default:
      return 'logged by you';
  }
}

/// Edit or delete **one stored day**.
///
/// This is the sheet the app was missing: every write path wrote *today*, so a value
/// typed on Sunday for Saturday had nowhere to go, and a mis-tap could not be undone.
/// It edits the row behind the number the user tapped, and the header names the day, so
/// there is no doubt which day is about to change.
///
/// Deleting leaves the day **empty**, not zero. A zero is a reading; absence is not. The
/// confirmation spells that out before the button does anything, because "clear the day"
/// and "the day reads 0" are different outcomes and only one of them is honest.
Future<void> openDaySheet(
  BuildContext context,
  Tracker t, {
  required int day,
  required double value,
  required String source,
  VoidCallback? onChanged,
}) async {
  final state = context.read<AppState>();
  final draft = ValueNotifier<double>(value);
  final isToday = day == dayKey(DateTime.now());
  final when = isToday ? 'Today' : '${weekdayName(weekdayOfDayKey(day))}, ${shortDayKey(day)}';

  await showGlassSheet<void>(
    context,
    title: '$when · ${t.name}',
    subtitle: '${switch (source) {
      'health' => 'Health Connect entry',
      'usage' => 'Android Usage Access entry',
      _ => 'Your entry',
    }}, ${_sourceWords(source)}',
    accent: t.accent,
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StepperBody(
          tracker: t,
          value: draft,
          start: value,
          presets: _presetsFor(t),
          min: 0,
          max: t.kind == MetricKind.steps ? 40000 : t.goal * 3,
        ),
        const SizedBox(height: 12),
        Text(
          isToday
              // Same row, same upsert: it is today's entry, wherever it is edited from.
              ? 'This is the same entry the log sheet writes — editing it here changes today.'
              : 'Editing ${shortDayKey(day)} changes only that day. Streaks, averages and '
                  'insights are recomputed from the stored rows, so nothing else moves silently.',
          style: TextStyle(fontSize: 12, height: 1.4, fontWeight: FontWeight.w500, color: TrackTheme.label3(
              Theme.of(context).brightness == Brightness.dark)),
        ),
      ],
    ),
    actions: [
      SubmitOnce(
        onSubmit: () async {
          if (!context.mounted) return true;
          final ok = await state.setDayValue(t.id, day, draft.value);
          if (!context.mounted) return true;
          if (!ok) {
            // Either the value was refused or the write failed. Both are stated, and the
            // sheet stays open so the value is not lost with the message.
            showTrackToast(context, 'Nothing was saved — that value was refused.');
            return false;
          }
          onChanged?.call();
          Navigator.of(context).pop();
          showTrackToast(context, '${shortDayKey(day)} saved · ${fmtValue(t, draft.value)}');
          return true;
        },
        builder: (context, submit) => TrackFilledButton(label: 'Save', color: t.accent, onTap: submit),
      ),
      SubmitOnce(
        onSubmit: () async {
          if (!context.mounted) return true;
          final confirmed = await _confirmClearDay(context, t, day);
          if (!confirmed || !context.mounted) return false;
          final removed = await state.clearDay(t.id, day);
          if (!context.mounted) return true;
          if (removed == null) {
            showTrackToast(context, 'The entry could not be removed — it is still there.');
            return false;
          }
          onChanged?.call();
          Navigator.of(context).pop();
          showTrackToast(
            context,
            removed == 0
                ? 'There was nothing stored for ${shortDayKey(day)}.'
                : 'Cleared ${shortDayKey(day)} · ${t.name} now has no entry for that day.',
          );
          return true;
        },
        builder: (context, submit) => TrackTintedButton(label: 'Delete this day', color: TrackTheme.red, onTap: submit),
      ),
    ],
  );
}

/// The last thing standing between a stray tap and a deleted history entry.
Future<bool> _confirmClearDay(BuildContext context, Tracker t, int day) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final dark = Theme.of(dialogContext).brightness == Brightness.dark;
      return AlertDialog(
        backgroundColor: TrackTheme.surface(dark),
        surfaceTintColor: Colors.transparent,
        title: Text('Clear ${shortDayKey(day)}?', style: TextStyle(color: TrackTheme.label(dark))),
        content: Text(
          'The entry for ${t.name} on ${shortDayKey(day)} is deleted. The day goes back to '
          'having no record — it will not read as a 0, and your streaks, averages and insights '
          'recompute without it.',
          style: TextStyle(color: TrackTheme.label2(dark), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: TrackTheme.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete entry'),
          ),
        ],
      );
    },
  );
  return confirmed ?? false;
}

/// The list of goals, so a control labelled "Goal settings" actually goes to the goals.
///
/// It used to call `setTab(3)`, which is Insights — the user tapped something about
/// goals and arrived on a screen about correlations, with no route to what they asked
/// for. Every row here opens the same goal sheet the detail screen uses.
Future<void> openGoalsSheet(BuildContext context) async {
  final state = context.read<AppState>();
  final trackers = state.visibleTrackers.toList();
  await showGlassSheet<void>(
    context,
    title: 'Goals',
    subtitle: 'Rings, streaks and insights are all measured against these',
    accent: TrackTheme.blue,
    body: Column(
      children: [
        if (trackers.isEmpty)
          Text(
            'No active trackers yet. Add one from the Trackers screen and its goal appears here.',
            style: TextStyle(
                fontSize: 13.5,
                height: 1.4,
                fontWeight: FontWeight.w500,
                color: TrackTheme.label3(Theme.of(context).brightness == Brightness.dark)),
          )
        else
          for (final t in trackers)
            GlassRow(
              title: t.name,
              subtitle: 'Goal ${fmtGoalLong(t)}',
              leading: Icon(Icons.flag_outlined, size: 18, color: t.accent),
              accent: t.accent,
              onTap: () => openGoalSheet(context, t),
            ),
      ],
    ),
    actions: [TrackTintedButton(label: 'Done', onTap: () => Navigator.of(context).pop())],
  );
}

/// Goal editor sheet, shared by Settings, the context menu and detail screens.
Future<void> openGoalSheet(BuildContext context, Tracker t) async {
  final state = context.read<AppState>();
  final value = ValueNotifier<double>(t.goal);
  await showGlassSheet<void>(
    context,
    title: 'Goal for ${t.name}',
    subtitle: 'Used for rings, streaks and insights',
    accent: t.accent,
    body: _StepperBody(
      tracker: t,
      value: value,
      start: t.goal,
      min: t.step,
      max: t.id == 'expenses' ? 20000 : (t.goal * 2.5),
      presets: [t.goal * .75, t.goal, t.goal * 1.25, t.goal * 1.5],
    ),
    actions: [
      SubmitOnce(
        // The goal write is awaited, so the sheet only closes once the row is stored:
        // "Goal set to 10.0km" over an unchanged goal is the kind of confirmation this
        // pass exists to remove.
        onSubmit: () async {
          if (!context.mounted) return true;
          final ok = await state.setGoal(t.id, value.value);
          if (!context.mounted) return true;
          if (!ok) {
            showTrackToast(context, 'The goal could not be saved — the previous one is unchanged.');
            return false;
          }
          Navigator.of(context).pop();
          showTrackToast(context, 'Goal set to ${fmtGoalLong(t)}');
          return true;
        },
        builder: (context, submit) =>
            TrackFilledButton(label: 'Update goal', color: t.accent, onTap: submit),
      ),
      TrackTintedButton(label: 'Cancel', onTap: () => Navigator.of(context).pop()),
    ],
  );
}

/// FAB sheet: everything you track, one tap away.
Future<void> showQuickAdd(BuildContext context) async {
  final state = context.read<AppState>();
  final trackers = state.visibleTrackers;
  final dark = Theme.of(context).brightness == Brightness.dark;
  await showGlassSheet<void>(
    context,
    title: 'Quick add',
    subtitle: 'Everything you track, one sheet',
    body: Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final t in trackers)
          SizedBox(
            width: (MediaQuery.sizeOf(context).width - 40 - 12) / 2,
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).pop();
                Future<void>.delayed(const Duration(milliseconds: 240), () => openLogSheet(context, t));
              },
              child: Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: TrackTheme.surface(dark),
                  borderRadius: BorderRadius.circular(TrackTheme.radiusCard),
                  boxShadow: TrackTheme.cardShadow(dark),
                ),
                child: Row(
                  children: [
                    TrackRecordIcon(label: t.name, color: t.accent, size: 34, iconSize: 18),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, letterSpacing: -.24, color: TrackTheme.label(dark))),
                          Text(fmtGoalLong(t),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: TrackTheme.label3(dark))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    ),
    actions: [TrackTintedButton(label: 'Cancel', onTap: () => Navigator.of(context).pop())],
  );
}

/// A non-interactive Material switch used as the state indicator inside the
/// tappable habit row. The row owns the actual toggle action and persistence.
class _Switch extends StatelessWidget {
  const _Switch({required this.value});

  final bool value;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Switch(
          value: value,
          activeColor: TrackTheme.green,
          onChanged: (_) {},
        ),
      );
}
