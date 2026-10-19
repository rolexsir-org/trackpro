import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/pro_config.dart';
import '../data/focus_engine.dart';
import '../main.dart' show Pressable, TrackTheme;
import '../models/focus_models.dart';
import '../services/haptics.dart';
import '../state/app_state.dart';
import '../widgets/glass.dart';
import '../widgets/large_title_header.dart';
import '../widgets/pro_gate.dart';
import 'focus_screen.dart';
import 'focus_setup_sheets.dart';
import 'log_sheets.dart';
import 'paywall_screen.dart';

/// Profiles and schedules — the two "set it up once" halves of Focus Lock.
///
/// Both are Pro, and both are *additive*: free users can run every mode, cover apps
/// and read their own history without either. Nothing on this screen is required to
/// use Focus Lock at all, which is why the locked state explains what would be
/// cheaper with it (one tap instead of six) rather than blocking a feature.
///
/// Schedules arm a **reminder**, not an auto-start. See
/// `NotificationService.scheduleFocusSession`: the session begins when the person
/// taps the notification. Starting to cover apps at a time nobody is holding the
/// phone is the behaviour users correctly call malware, and it is not what this does.
class FocusProfilesScreen extends StatelessWidget {
  const FocusProfilesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          AmbientBackground(accent: TrackTheme.purple, accent2: TrackTheme.indigo),
          CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              LargeTitleHeader(
                title: 'Profiles & schedules',
                subtitle: 'Rules you set once and reuse',
                leading: const TrackBackButton(),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 60),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    if (!app.hasFocusSupport)
                      const InsightCard(
                        emoji: '⏱️',
                        title: 'Focus Lock is unavailable in this build',
                        body: 'Profiles and schedules configure the session engine, and this build has no '
                            'platform channel behind it. Nothing here would run.',
                        accent: TrackTheme.orange,
                        accent2: TrackTheme.yellow,
                      )
                    else ...[
                      // -------------------------------------------------- profiles
                      SectionLabel(
                        'Profiles',
                        trailing: app.canUseFocusProfiles ? _AddButton(onTap: () => _editProfile(context)) : null,
                      ),
                      if (!app.canUseFocusProfiles)
                        ProLockedRow(
                          title: 'Saved profiles',
                          subtitle: 'One tap to start the exact session you use every day — mode, length and '
                              'app list included.',
                          emoji: '⚡️',
                          accent: TrackTheme.purple,
                          onTap: () => showPaywall(context, trigger: PaywallTrigger.focusProfiles),
                        )
                      else if (app.focusProfiles.isEmpty)
                        const InsightCard(
                          emoji: '⚡️',
                          title: 'No profiles yet.',
                          body: 'A profile is a session you have already decided about: the mode, the length, '
                              'the apps. Set one up and tomorrow\'s session starts with a single tap.',
                          accent: TrackTheme.purple,
                          accent2: TrackTheme.indigo,
                        )
                      else
                        for (final profile in app.focusProfiles)
                          _ProfileRow(
                            profile: profile,
                            onStart: () => _startProfile(context, profile),
                            onEdit: () => _editProfile(context, existing: profile),
                            onDelete: () => app.deleteFocusProfile(profile.id),
                          ),

                      // ------------------------------------------------- schedules
                      SectionLabel(
                        'Schedules',
                        trailing: app.canUseFocusSchedules ? _AddButton(onTap: () => _editSchedule(context)) : null,
                      ),
                      if (!app.canUseFocusSchedules)
                        ProLockedRow(
                          title: 'Scheduled deep focus',
                          subtitle: 'Track Pro reminds you at the time you chose, with one tap to start. It never '
                              'starts covering apps on its own.',
                          emoji: '🕘',
                          accent: TrackTheme.indigo,
                          onTap: () => showPaywall(context, trigger: PaywallTrigger.focusSchedules),
                        )
                      else if (app.focusSchedules.isEmpty)
                        const InsightCard(
                          emoji: '🕘',
                          title: 'No schedules yet.',
                          body: 'Pick a time and the days it applies to. At that time Track Pro sends a reminder; '
                              'the session starts when you tap it, and not before.',
                          accent: TrackTheme.indigo,
                          accent2: TrackTheme.blue,
                        )
                      else
                        for (final schedule in app.focusSchedules)
                          _ScheduleRow(
                            schedule: schedule,
                            onToggle: (v) async {
                              await app.saveFocusSchedule(
                                id: schedule.id,
                                mode: schedule.mode,
                                minutes: schedule.minutes,
                                hour: schedule.hour,
                                minute: schedule.minute,
                                weekdays: schedule.weekdays,
                                commitmentId: schedule.commitmentId,
                                packages: schedule.packages,
                                enabled: v,
                              );
                              if (context.mounted) {
                                showTrackToast(context, v ? 'Reminder armed' : 'Reminder off — nothing changed in any app');
                              }
                            },
                            onEdit: () => _editSchedule(context, existing: schedule),
                            onDelete: () => app.deleteFocusSchedule(schedule.id),
                          ),

                      const SizedBox(height: 18),
                      Text(
                        'A schedule is a reminder from Track Pro. It cannot start a session for you, and it never '
                        'covers an app while you are not there — Android restricts background work like that, '
                        'and, more importantly, nobody wants an app that starts blocking things at 9am whether '
                        'or not they are at their desk.',
                        style: TextStyle(fontSize: 11.8, height: 1.5, fontWeight: FontWeight.w500, color: TrackTheme.label3(dark)),
                      ),
                    ],
                  ]),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _startProfile(BuildContext context, FocusProfile profile) async {
    final app = context.read<AppState>();
    final navigator = Navigator.of(context);
    final started = await app.startFocus(
      mode: profile.mode,
      minutes: profile.minutes,
      packages: profile.packages,
      commitmentId: profile.commitmentId,
      goalLabel: profile.name,
    );
    if (started == null) {
      if (context.mounted) showTrackToast(context, 'A session is already running');
      return;
    }
    await openFocusSession(navigator.context);
  }
}

Future<void> _editProfile(BuildContext context, {FocusProfile? existing}) async {
  final app = context.read<AppState>();
  await showGlassSheet<void>(
    context,
    title: existing == null ? 'New profile' : 'Edit profile',
    subtitle: 'A profile is a decision you make once and reuse.',
    accent: TrackTheme.purple,
    scrollable: true,
    body: _ProfileEditor(profile: existing, onSave: (p) async {
      await app.saveFocusProfile(
        id: existing?.id,
        name: p.name,
        mode: p.mode,
        minutes: p.minutes,
        commitmentId: p.commitmentId,
        packages: p.packages,
      );
      Haptics.commit();
    }),
    actions: const [],
  );
}

class _ProfileEditor extends StatefulWidget {
  const _ProfileEditor({required this.profile, required this.onSave});

  final FocusProfile? profile;
  final Future<void> Function(FocusProfile draft) onSave;

  @override
  State<_ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<_ProfileEditor> {
  late final TextEditingController _name = TextEditingController(text: widget.profile?.name ?? '');
  late FocusMode _mode = widget.profile?.mode ?? FocusMode.deep;
  late int _minutes = FocusEngine.clampMinutes(widget.profile?.minutes ?? 45);
  late List<String> _packages = List<String>.from(widget.profile?.packages ?? const <String>[]);
  late String? _commitmentId = widget.profile?.commitmentId;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CupertinoTextField(
          controller: _name,
          placeholder: 'Name — e.g. "Morning writing"',
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          style: TextStyle(fontSize: 15, color: TrackTheme.label(dark)),
          decoration: BoxDecoration(color: TrackTheme.fill(dark), borderRadius: BorderRadius.circular(11)),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        Text('MODE',
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: .5, color: TrackTheme.label3(dark))),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: [
            for (final mode in FocusMode.values)
              _Chip(
                label: '${mode.emoji} ${mode.shortLabel}',
                selected: _mode == mode,
                onTap: () => setState(() => _mode = mode),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text('LENGTH',
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: .5, color: TrackTheme.label3(dark))),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final preset in FocusEngine.presetMinutes)
              _Chip(label: '$preset min', selected: _minutes == preset, onTap: () => setState(() => _minutes = preset)),
            _Chip(
              label: '${_minutes} min ✎',
              selected: !FocusEngine.presetMinutes.contains(_minutes),
              onTap: () async {
                final custom = await showFocusCustomMinutesSheet(context, initial: _minutes);
                if (custom != null && mounted) setState(() => _minutes = custom);
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        GlassList(children: [
          GlassRow(
            title: _packages.isEmpty ? 'No apps covered' : '${_packages.length} app${_packages.length == 1 ? '' : 's'} covered',
            subtitle: _mode == FocusMode.standard ? 'Standard mode does not cover apps' : 'Tap to choose',
            leading: const Text('📵', style: TextStyle(fontSize: 14)),
            accent: TrackTheme.indigo,
            onTap: _mode == FocusMode.standard
                ? null
                : () async {
                    final picked = await showFocusAppPicker(context, selected: _packages, mode: _mode);
                    if (picked != null && mounted) {
                      setState(() => _packages = picked);
                      app.setFocusDraftAppCount(picked.length);
                    }
                  },
          ),
          GlassRow(
            title: _commitmentId == null ? 'Focus session' : _commitmentName(app),
            subtitle: 'Attach it to a routine, so your history reads like your life',
            leading: const Text('🎯', style: TextStyle(fontSize: 14)),
            accent: TrackTheme.blue,
            onTap: () async {
              final goal = await showFocusGoalPicker(context);
              if (goal != null && mounted) {
                setState(() {
                  _commitmentId = goal.id;
                  if (_name.text.trim().isEmpty) _name.text = goal.label;
                });
              }
            },
          ),
        ]),
        const SizedBox(height: 8),
        Text(
          'Sessions started from this profile still ask for nothing new: the permissions it needs are the '
          'same ones any session needs, and a profile cannot grant them.',
          style: TextStyle(fontSize: 11.5, height: 1.45, fontWeight: FontWeight.w500, color: TrackTheme.label3(dark)),
        ),
        const SizedBox(height: 14),
        TrackFilledButton(
          label: _busy ? 'Saving…' : (widget.profile == null ? 'Create profile' : 'Save changes'),
          color: TrackTheme.purple,
          onTap: _busy
              ? null
              : () async {
                  setState(() => _busy = true);
                  // Built here, at save time, from the live editor state — not from a
                  // snapshot taken at build, which would ship a stale app list if the
                  // picker changed after the last rebuild.
                  await widget.onSave(FocusProfile(
                    id: widget.profile?.id ?? 'draft',
                    name: _name.text.trim().isEmpty ? '${_mode.shortLabel} ${_minutes}m' : _name.text.trim(),
                    mode: _mode,
                    minutes: _minutes,
                    commitmentId: _commitmentId,
                    packages: _packages,
                    sort: widget.profile?.sort ?? 0,
                  ));
                  if (!mounted) return;
                  Navigator.of(context).pop();
                },
        ),
      ],
    );
  }

  String _commitmentName(AppState app) {
    for (final c in app.commitments) {
      if (c.id == _commitmentId) return c.name;
    }
    return 'Linked routine';
  }
}

Future<void> _editSchedule(BuildContext context, {FocusSchedule? existing}) async {
  final app = context.read<AppState>();
  await showGlassSheet<void>(
    context,
    title: existing == null ? 'New schedule' : 'Edit schedule',
    subtitle: 'Track Pro will remind you at this time. The session starts when you tap the reminder.',
    accent: TrackTheme.indigo,
    scrollable: true,
    body: _ScheduleEditor(
      schedule: existing,
      onSave: (values) async {
        await app.saveFocusSchedule(
          id: existing?.id,
          mode: values.mode,
          minutes: values.minutes,
          hour: values.hour,
          minute: values.minute,
          weekdays: values.weekdays,
          commitmentId: existing?.commitmentId,
          packages: values.packages,
          enabled: true,
        );
        Haptics.commit();
      },
    ),
    actions: const [],
  );
}

/// The values an edited schedule carries back out of the editor, as a record so the
/// sheet's public signature stays free of private types.
typedef _ScheduleValues = ({FocusMode mode, int minutes, int hour, int minute, Set<int> weekdays, List<String> packages});

class _ScheduleEditor extends StatefulWidget {
  const _ScheduleEditor({required this.schedule, required this.onSave});

  final FocusSchedule? schedule;
  final Future<void> Function(_ScheduleValues values) onSave;

  @override
  State<_ScheduleEditor> createState() => _ScheduleEditorState();
}

class _ScheduleEditorState extends State<_ScheduleEditor> {
  late int _hour = widget.schedule?.hour ?? 9;
  late int _minute = widget.schedule?.minute ?? 0;
  late FocusMode _mode = widget.schedule?.mode ?? FocusMode.deep;
  late int _minutes = FocusEngine.clampMinutes(widget.schedule?.minutes ?? 45);
  late Set<int> _weekdays = Set<int>.from(widget.schedule?.weekdays ?? const <int>{});
  late List<String> _packages = List<String>.from(widget.schedule?.packages ?? const <String>[]);
  bool _busy = false;

  static const _dayNames = <int, String>{1: 'Mon', 2: 'Tue', 3: 'Wed', 4: 'Thu', 5: 'Fri', 6: 'Sat', 7: 'Sun'};

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Text('${_two(_hour)}:${_two(_minute)}',
              style: TextStyle(fontSize: 40, fontWeight: FontWeight.w300, letterSpacing: -1, color: TrackTheme.label(dark))),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: TrackTintedButton(
                label: '− 30 min',
                color: TrackTheme.blue,
                onTap: () => _shift(-30),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TrackTintedButton(
                label: '+ 30 min',
                color: TrackTheme.blue,
                onTap: () => _shift(30),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text('DAYS',
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: .5, color: TrackTheme.label3(dark))),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final entry in _dayNames.entries)
              _Chip(
                label: entry.value,
                selected: _weekdays.contains(entry.key),
                onTap: () => setState(() {
                  if (!_weekdays.remove(entry.key)) _weekdays.add(entry.key);
                }),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Text('MODE',
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: .5, color: TrackTheme.label3(dark))),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: [
            for (final mode in FocusMode.values)
              _Chip(
                label: '${mode.emoji} ${mode.shortLabel}',
                selected: _mode == mode,
                onTap: () => setState(() => _mode = mode),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text('LENGTH',
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: .5, color: TrackTheme.label3(dark))),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: [
            for (final preset in FocusEngine.presetMinutes)
              _Chip(label: '$preset min', selected: _minutes == preset, onTap: () => setState(() => _minutes = preset)),
          ],
        ),
        const SizedBox(height: 12),
        GlassList(children: [
          GlassRow(
            title: _packages.isEmpty ? 'No apps covered' : '${_packages.length} app${_packages.length == 1 ? '' : 's'} covered',
            subtitle: _mode == FocusMode.standard ? 'Standard mode does not cover apps' : 'Tap to choose',
            leading: const Text('📵', style: TextStyle(fontSize: 14)),
            accent: TrackTheme.indigo,
            onTap: _mode == FocusMode.standard
                ? null
                : () async {
                    final picked = await showFocusAppPicker(context, selected: _packages, mode: _mode);
                    if (picked != null && mounted) setState(() => _packages = picked);
                  },
          ),
        ]),
        const SizedBox(height: 10),
        Text(
          _weekdays.isEmpty
              ? 'No days chosen means every day. Track Pro sends a reminder at this time; nothing starts by itself.'
              : 'Track Pro sends a reminder on the chosen days. A reminder is not a start — the session begins when you tap it.',
          style: TextStyle(fontSize: 11.5, height: 1.45, fontWeight: FontWeight.w500, color: TrackTheme.label3(dark)),
        ),
        const SizedBox(height: 14),
        TrackFilledButton(
          label: _busy ? 'Saving…' : 'Save schedule',
          color: TrackTheme.indigo,
          onTap: _busy
              ? null
              : () async {
                  setState(() => _busy = true);
                  await widget.onSave((
                    mode: _mode,
                    minutes: _minutes,
                    hour: _hour,
                    minute: _minute,
                    weekdays: _weekdays,
                    packages: _packages,
                  ));
                  if (!mounted) return;
                  Navigator.of(context).pop();
                },
        ),
      ],
    );
  }

  void _shift(int minutes) {
    var total = (_hour * 60 + _minute + minutes) % (24 * 60);
    if (total < 0) total += 24 * 60;
    setState(() {
      _hour = total ~/ 60;
      _minute = total % 60;
    });
    Haptics.selection();
  }

  static String _two(int v) => v < 10 ? '0$v' : '$v';
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.profile, required this.onStart, required this.onEdit, required this.onDelete});

  final FocusProfile profile;
  final VoidCallback onStart;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: TrackTheme.surface(dark),
        borderRadius: BorderRadius.circular(TrackTheme.radiusCard),
        boxShadow: TrackTheme.cardShadow(dark),
        border: Border.all(color: dark ? Colors.white.withOpacity(.05) : Colors.black.withOpacity(.03), width: .5),
      ),
      child: Column(
        children: [
          GlassRow(
            title: profile.name,
            subtitle: '${profile.mode.label} · ${profile.minutes} min'
                '${profile.packages.isEmpty ? '' : ' · ${profile.packages.length} app${profile.packages.length == 1 ? '' : 's'}'}',
            leading: Text(profile.mode.emoji, style: const TextStyle(fontSize: 14)),
            accent: TrackTheme.purple,
            showChevron: false,
            onTap: onStart,
            trailing: Row(
              children: [
                Pressable(
                  onTap: onEdit,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(CupertinoIcons.pencil, size: 16, color: TrackTheme.label3(dark)),
                  ),
                ),
                Pressable(
                  onTap: onDelete,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(CupertinoIcons.trash, size: 16, color: TrackTheme.red.withOpacity(.8)),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 0, 15, 11),
            child: Row(
              children: [
                Expanded(
                  child: TrackFilledButton(
                    label: 'Start now',
                    color: TrackTheme.purple,
                    onTap: onStart,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({
    required this.schedule,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final FocusSchedule schedule;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  static const _dayNames = <int, String>{1: 'Mon', 2: 'Tue', 3: 'Wed', 4: 'Thu', 5: 'Fri', 6: 'Sat', 7: 'Sun'};

  String get _days {
    if (schedule.weekdays.isEmpty) return 'Every day';
    final sorted = schedule.weekdays.toList()..sort();
    if (sorted.length == 7) return 'Every day';
    return sorted.map((d) => _dayNames[d] ?? '').where((d) => d.isNotEmpty).join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: TrackTheme.surface(dark),
        borderRadius: BorderRadius.circular(TrackTheme.radiusCard),
        boxShadow: TrackTheme.cardShadow(dark),
        border: Border.all(color: dark ? Colors.white.withOpacity(.05) : Colors.black.withOpacity(.03), width: .5),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${schedule.label}  ·  ${schedule.mode.emoji} ${schedule.mode.shortLabel}',
                    style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, letterSpacing: -.25, color: TrackTheme.label(dark))),
                const SizedBox(height: 2),
                Text('$_days · ${schedule.minutes} min'
                    '${schedule.packages.isEmpty ? '' : ' · ${schedule.packages.length} app${schedule.packages.length == 1 ? '' : 's'}'}',
                    style: TextStyle(fontSize: 12.3, fontWeight: FontWeight.w500, color: TrackTheme.label3(dark))),
                if (!schedule.enabled)
                  Text('Off — no reminder will be sent',
                      style: TextStyle(fontSize: 11.8, fontWeight: FontWeight.w600, color: TrackTheme.orange)),
              ],
            ),
          ),
          Pressable(
            onTap: onEdit,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Icon(CupertinoIcons.pencil, size: 16, color: TrackTheme.label3(dark)),
            ),
          ),
          Pressable(
            onTap: onDelete,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Icon(CupertinoIcons.trash, size: 16, color: TrackTheme.red.withOpacity(.8)),
            ),
          ),
          CupertinoSwitch(value: schedule.enabled, onChanged: onToggle),
        ],
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(color: TrackTheme.fill(Theme.of(context).brightness == Brightness.dark), borderRadius: BorderRadius.circular(TrackTheme.radiusPill)),
        child: const Text('＋ Add', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: TrackTheme.blue)),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Pressable(
      onTap: onTap,
      scale: .95,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? TrackTheme.purple : TrackTheme.fill(dark),
          borderRadius: BorderRadius.circular(TrackTheme.radiusPill),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : TrackTheme.label(dark),
            )),
      ),
    );
  }
}
