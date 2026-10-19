import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/pro_config.dart';
import '../data/focus_engine.dart';
import '../main.dart' show Pressable, TrackTheme;
import '../models/focus_models.dart';
import '../models/models.dart';
import '../services/haptics.dart';
import '../state/app_state.dart';
import '../widgets/glass.dart';
import '../widgets/pro_gate.dart';
import 'focus_screen.dart';
import 'paywall_screen.dart';

/// Setting up a focus session.
///
/// This sheet has one rule that outranks looking nice: **everything the session
/// cannot do is stated here, before it starts.** Not in a help page, not after the
/// fact. In particular:
///
///   * each mode's `limitation` line is printed under the mode it applies to;
///   * the cancellation behaviour of the chosen mode is printed above the start
///     button, because discovering the rules mid-session is how a feature like this
///     becomes something people resent;
///   * if the app can't block at all right now (no usage access, no overlay grant,
///     or no native channel in this build) the start button says what the session
///     will actually be, and offers the fix instead of quietly doing less than the
///     user asked;
///   * the essential-app whitelist is stated, not implied.
///
/// Nothing here can grant Pro, and nothing here can grant a permission. Permission
/// buttons open the *system* screen; the app never toggles anything itself, and a
/// granted permission never changes the tier.
Future<void> showFocusStartSheet(
  BuildContext context, {
  String? commitmentId,
  String? goalLabel,
  FocusMode? mode,
  int? minutes,
  List<String>? packages,
}) async {
  final app = context.read<AppState>();
  await app.refreshFocusPermissions();

  await showGlassSheet<void>(
    context,
    title: 'Focus session',
    subtitle: 'Choose how long, and how much Track Pro should hold back.',
    accent: TrackTheme.indigo,
    scrollable: true,
    body: _StartBody(
      commitmentId: commitmentId,
      goalLabel: goalLabel,
      mode: mode,
      minutes: minutes,
      packages: packages,
    ),
    actions: const [],
  );
}

class _StartBody extends StatefulWidget {
  const _StartBody({this.commitmentId, this.goalLabel, this.mode, this.minutes, this.packages});

  final String? commitmentId;
  final String? goalLabel;
  final FocusMode? mode;
  final int? minutes;
  final List<String>? packages;

  @override
  State<_StartBody> createState() => _StartBodyState();
}

class _StartBodyState extends State<_StartBody> {
  late FocusMode _mode;
  late int _minutes;
  late List<String> _packages;
  late String? _commitmentId;
  late String _goal;
  late final TextEditingController _goalController = TextEditingController(
    text: widget.goalLabel ?? '',
  );

  /// The routine's own name, remembered so a typed edit can be told apart from the
  /// link that put the text there.
  String? _linkedLabel;
  bool _busy = false;

  @override
  void dispose() {
    _goalController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _mode = widget.mode ?? FocusMode.standard;
    _linkedLabel = widget.commitmentId == null ? null : widget.goalLabel;
    _minutes = FocusEngine.clampMinutes(widget.minutes ?? 25);
    _packages = List<String>.from(widget.packages ?? const <String>[]);
    _commitmentId = widget.commitmentId;
    _goal = widget.goalLabel ?? 'Focus session';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AppState>().setFocusDraftAppCount(_packages.length);
    });
  }

  void _setMode(FocusMode mode) {
    setState(() => _mode = mode);
    Haptics.selection();
  }

  void _setMinutes(int minutes) {
    setState(() => _minutes = FocusEngine.clampMinutes(minutes));
    Haptics.selection();
  }

  Future<void> _pickApps() async {
    final app = context.read<AppState>();
    final picked = await showFocusAppPicker(context, selected: _packages, mode: _mode);
    if (picked == null || !mounted) return;
    setState(() => _packages = picked);
    app.setFocusDraftAppCount(picked.length);
  }

  Future<void> _pickGoal() async {
    final app = context.read<AppState>();
    final chosen = await showFocusGoalPicker(context);
    if (chosen == null || !mounted) return;
    setState(() {
      _commitmentId = chosen.id;
      _goal = chosen.label;
      _linkedLabel = chosen.id == null ? null : chosen.label;
      _goalController.text = chosen.id == null ? '' : chosen.label;
    });
  }

  Future<void> _start() async {
    if (_busy) return;
    setState(() => _busy = true);
    final app = context.read<AppState>();
    final started = await app.startFocus(
      mode: _mode,
      minutes: _minutes,
      packages: _mode == FocusMode.standard ? const <String>[] : _packages,
      commitmentId: _commitmentId,
      goalLabel: _goal,
      accentArgb: 0xFFFF7A18,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (started == null) {
      showTrackToast(context, 'A session is already running');
      return;
    }
    // Capture the navigator *before* the sheet closes: after `pop()` this widget is
    // on its way out, and pushing the session route through a disposed context is
    // exactly the kind of bug that only shows up on a slow frame.
    final navigator = Navigator.of(context);
    navigator.pop();
    // One entry point for the session route, so two taps cannot stack two screens
    // (or two countdowns) for the same session.
    await openFocusSession(navigator.context);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final dark = Theme.of(context).brightness == Brightness.dark;
    final wantsBlocking = _mode != FocusMode.standard && _packages.isNotEmpty;
    final willBlock = wantsBlocking && app.focusCanBlock;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ------------------------------------------------------------ duration
        _Label('How long'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final preset in FocusEngine.presetMinutes)
              _Chip(
                label: '$preset min',
                selected: _minutes == preset && preset != 0,
                onTap: () => _setMinutes(preset),
              ),
            _Chip(
              label: 'Custom: $_minutes min',
              selected: !FocusEngine.presetMinutes.contains(_minutes),
              onTap: () async {
                final custom = await showFocusCustomMinutesSheet(context, initial: _minutes);
                if (custom != null && mounted) _setMinutes(custom);
              },
            ),
          ],
        ),

        // ---------------------------------------------------------------- mode
        _Label('How much should Track Pro hold back?'),
        for (final mode in FocusMode.values) ...[
          _ModeCard(
            mode: mode,
            selected: _mode == mode,
            onTap: () => _setMode(mode),
            permissions: app.focusPermissions,
            platformAvailable: app.focusPlatformAvailable,
          ),
          const SizedBox(height: 8),
        ],

        // ---------------------------------------------------- selected apps
        if (_mode != FocusMode.standard) ...[
          _Label('Apps to cover'),
          GlassList(children: [
            GlassRow(
              title: _packages.isEmpty ? 'Choose apps' : '${_packages.length} app${_packages.length == 1 ? '' : 's'} chosen',
              subtitle: _packages.isEmpty
                  ? 'Nothing is covered until you pick something.'
                  : _packages.map(_shortName).take(4).join(', ') + (_packages.length > 4 ? '…' : ''),
              leading: const Icon(Icons.block_outlined, size: 18, color: TrackTheme.orange),
              accent: TrackTheme.indigo,
              onTap: _pickApps,
            ),
            if (!app.canBlockMoreApps)
              ProLockedRow(
                title: 'Cover the whole list',
                subtitle: 'Pro covers every app you open when you are avoiding work — free sessions cover '
                    '${ProConfig.freeBlockedApps}.',
                emoji: 'focus',
                accent: TrackTheme.indigo,
                onTap: () => showPaywall(context, trigger: PaywallTrigger.focusApps),
              ),
          ]),
        ],

        // -------------------------------------------------------------- goal
        // Two ways to name a session: type it (a study plan, a workout, anything that is
        // not a routine in the app), or pick a routine so the history connects back.
        // Both end up in the same `goalLabel` column, and the routine link adds only the
        // id — the label is always the user's own words or their routine's name.
        _Label('What is this for?'),
        TextField(
          controller: _goalController,
          textCapitalization: TextCapitalization.sentences,
          maxLength: 60,
          style: TextStyle(fontSize: 15, color: TrackTheme.label(dark)),
          decoration: InputDecoration(
            hintText: 'Focus session',
            filled: true,
            fillColor: TrackTheme.fill(dark),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(11),
              borderSide: BorderSide.none,
            ),
          ),
          onChanged: (v) => setState(() {
            _goal = v.trim().isEmpty ? 'Focus session' : v.trim();
            // Typing something else is how a user unlinks a routine. Leaving the
            // commitmentId attached to a goal the user has overwritten would put a
            // routine's name in the history beside a session that was not for it.
            if (_commitmentId != null && v.trim() != _linkedLabel) _commitmentId = null;
          }),
        ),
        GlassList(children: [
          GlassRow(
            title: _commitmentId == null ? 'Link a routine' : 'Linked to ${_linkedLabel ?? 'a routine'}',
            subtitle: _commitmentId == null
                ? 'Optional. The session keeps its own name either way.'
                : 'Tap to change or remove the link',
            leading: const Icon(Icons.link_rounded, size: 18, color: TrackTheme.orange),
            accent: TrackTheme.green,
            onTap: _pickGoal,
          ),
        ]),

        // -------------------------------------------------------- enforcement
        _Label('What will actually happen'),
        _PermissionSummary(
          permissions: app.focusPermissions,
          platformAvailable: app.focusPlatformAvailable,
          willBlock: willBlock,
          onOpenSettings: () => openFocusPermissionSheet(context),
        ),

        const SizedBox(height: 12),
        Text(
          FocusEngine.cancellationCopy(_mode),
          style: TextStyle(fontSize: 12.5, height: 1.5, fontWeight: FontWeight.w500, color: TrackTheme.label2(dark)),
        ),
        const SizedBox(height: 10),
        _EmergencyNote(mode: _mode),
        const SizedBox(height: 16),
        TrackFilledButton(
          label: _busy ? 'Starting…' : _startLabel(wantsBlocking, willBlock),
          color: _mode == FocusMode.deep ? TrackTheme.purple : TrackTheme.blue,
          onTap: _busy ? null : () => unawaited(_start()),
        ),
        const SizedBox(height: 6),
        Text(
          'Track Pro never turns a permission on for you, and a permission never unlocks anything paid.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11.5, height: 1.4, fontWeight: FontWeight.w500, color: TrackTheme.label3(dark)),
        ),
      ],
    );
  }

  String _startLabel(bool wantsBlocking, bool willBlock) {
    final count = _packages.length;
    if (!wantsBlocking) return 'Start focus';
    // When blocking was asked for and cannot happen, the button says so. A button
    // labelled "Start" that quietly delivers less is how trust in a feature like this
    // gets spent.
    if (willBlock) return 'Start with $count app${count == 1 ? '' : 's'} selected';
    return 'Start without blocking';
  }

  String _shortName(String packageName) {
    final parts = packageName.split('.');
    final last = parts.isEmpty ? packageName : parts.last;
    return last.isEmpty ? packageName : '${last[0].toUpperCase()}${last.substring(1)}';
  }
}

/// One mode, with its own limit printed on it.
class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.mode,
    required this.selected,
    required this.onTap,
    required this.permissions,
    required this.platformAvailable,
  });

  final FocusMode mode;
  final bool selected;
  final VoidCallback onTap;
  final FocusPermissions permissions;
  final bool platformAvailable;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = switch (mode) {
      FocusMode.standard => TrackTheme.blue,
      FocusMode.blocking => TrackTheme.indigo,
      FocusMode.deep => TrackTheme.purple,
    };
    final canBlock = platformAvailable && permissions.canBlock;

    return Pressable(
      onTap: onTap,
      scale: .985,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
        decoration: BoxDecoration(
          color: selected ? accent.withOpacity(dark ? .2 : .1) : TrackTheme.surface(dark),
          borderRadius: BorderRadius.circular(TrackTheme.radiusCard),
          border: Border.all(color: selected ? accent.withOpacity(.55) : Colors.transparent, width: 1),
          boxShadow: selected ? null : TrackTheme.cardShadow(dark),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_focusModeIcon(mode), size: 19, color: accent),
                const SizedBox(width: 8),
                Text(mode.label,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: -.25, color: TrackTheme.label(dark))),
                const Spacer(),
                if (selected) Icon(Icons.check_circle_rounded, size: 19, color: accent),
                if (!selected && mode != FocusMode.standard && !canBlock)
                  Text('needs setup',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: TrackTheme.orange)),
              ],
            ),
            const SizedBox(height: 5),
            Text(mode.blurb,
                style: TextStyle(fontSize: 12.8, height: 1.45, fontWeight: FontWeight.w500, color: TrackTheme.label2(dark))),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 15, color: TrackTheme.label3(dark)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(mode.limitation,
                      style: TextStyle(fontSize: 11.8, height: 1.45, fontWeight: FontWeight.w500, color: TrackTheme.label3(dark))),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

IconData _focusModeIcon(FocusMode mode) => switch (mode) {
      FocusMode.standard => Icons.timer_outlined,
      FocusMode.blocking => Icons.block_outlined,
      FocusMode.deep => Icons.do_not_disturb_on_outlined,
    };

/// The plain-language state of enforcement, before the session starts.
class _PermissionSummary extends StatelessWidget {
  const _PermissionSummary({
    required this.permissions,
    required this.platformAvailable,
    required this.willBlock,
    required this.onOpenSettings,
  });

  final FocusPermissions permissions;
  final bool platformAvailable;
  final bool willBlock;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    final String headline;
    final Color accent;
    if (!platformAvailable) {
      headline = 'This build has no focus channel, so sessions are timers only. '
          'The timer, the goal and the reflection all work; covering other apps does not.';
      accent = TrackTheme.orange;
    } else if (willBlock) {
      headline = 'Track Pro can request coverage for the apps you chose. It says coverage is verified only after '
          'it sees a selected app and Android accepts the coverage-panel launch; until then the status reads "armed".';
      accent = TrackTheme.green;
    } else if (permissions.canBlock) {
      headline = 'Track Pro can cover apps, but none are chosen.';
      accent = TrackTheme.blue;
    } else {
      headline = 'App covering needs ${permissions.missingForBlockingLabel}. '
          'Without ${permissions.missingForBlocking.length == 1 ? 'it' : 'them'} this session will be a timer, '
          'and Track Pro will say so rather than pretend.';
      accent = TrackTheme.orange;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
      decoration: BoxDecoration(
        color: accent.withOpacity(dark ? .16 : .09),
        borderRadius: BorderRadius.circular(TrackTheme.radiusCard),
        border: Border.all(color: accent.withOpacity(.28), width: .5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(headline,
              style: TextStyle(fontSize: 12.8, height: 1.5, fontWeight: FontWeight.w500, color: TrackTheme.label2(dark))),
          if (platformAvailable) ...[
            const SizedBox(height: 8),
            Pressable(
              onTap: onOpenSettings,
              child: Text('What each permission does →',
                  style: TextStyle(fontSize: 12.8, fontWeight: FontWeight.w700, color: accent)),
            ),
          ],
        ],
      ),
    );
  }
}

/// Emergency functions are never in scope, in any mode. Said out loud, because a
/// blocking feature that does not say this invites the worst possible assumption.
class _EmergencyNote extends StatelessWidget {
  const _EmergencyNote({required this.mode});

  final FocusMode mode;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (mode == FocusMode.standard) {
      return Text(
        'A timer session changes nothing outside Track Pro — your phone works exactly as it always does.',
        style: TextStyle(fontSize: 12, height: 1.45, fontWeight: FontWeight.w500, color: TrackTheme.label3(dark)),
      );
    }
    return Text(
      'Calls, emergency dialling, the system launcher, keyboards, the clock and Track Pro itself are never '
      'covered, in any mode. You can always reach your phone and always leave this session.',
      style: TextStyle(fontSize: 12, height: 1.45, fontWeight: FontWeight.w500, color: TrackTheme.label3(dark)),
    );
  }
}

// ---------------------------------------------------------------------------
// Permission explainer — what each one is for, and what happens without it.
// ---------------------------------------------------------------------------
Future<void> openFocusPermissionSheet(BuildContext context) async {
  final app = context.read<AppState>();
  await app.refreshFocusPermissions();

  if (!context.mounted) return;
  await showGlassSheet<void>(
    context,
    title: 'Permissions, and why',
    subtitle: 'Track Pro asks for the least it can. Each of these does one job, and each can be revoked '
        'whenever you like.',
    accent: TrackTheme.orange,
    scrollable: true,
    body: const _PermissionBody(),
    actions: const [],
  );
}

class _PermissionBody extends StatelessWidget {
  const _PermissionBody();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final dark = Theme.of(context).brightness == Brightness.dark;
    final p = app.focusPermissions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PermissionRow(
          icon: Icons.query_stats_outlined,
          title: 'Usage access',
          granted: p.usageAccess,
          reason: 'Lets Track Pro notice when a covered app comes to the front, so it can step in. It reads '
              'only the package name and the moment — never what is on the screen, never messages, '
              'never your accounts.',
          without: 'Without it, no app can be covered. Sessions become timers.',
          onOpen: app.openUsageAccessSettings,
        ),
        _PermissionRow(
          icon: Icons.open_in_new_rounded,
          title: 'Display over other apps',
          granted: p.overlay,
          reason: 'Lets Track Pro draw the "this is covered" panel over the app you opened. The panel has '
              'one action — leave the covered app — and it never imitates another app\'s interface.',
          without: 'Without it, Track Pro can detect an app but cannot say anything about it, so it does not claim to cover it.',
          onOpen: app.openOverlaySettings,
        ),
        _PermissionRow(
          icon: Icons.notifications_outlined,
          title: 'Notifications',
          granted: p.notifications,
          reason: 'Used for the running-session notice Android requires while the detector is active, and '
              'for scheduled sessions you set up. Reminder text stays private on the lock screen.',
          without: 'Without it, the running-session notice is missing and Android may stop the detector. '
              'A session still runs as a timer.',
          onOpen: app.openNotificationSettings,
        ),
        _PermissionRow(
          icon: Icons.battery_saver_outlined,
          title: 'Battery optimisation',
          granted: p.batteryOptimised,
          reason: 'If Android is optimising Track Pro, it can suspend the detector mid-session, and covering '
              'apps stops until you come back.',
          without: 'Sessions still run, but they may quietly stop being enforced — which is exactly the '
              'case this screen exists to avoid.',
          onOpen: app.openBatterySettings,
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
          decoration: BoxDecoration(
            color: TrackTheme.fill(dark),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('What Track Pro will never ask for',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: TrackTheme.label(dark))),
              const SizedBox(height: 5),
              Text(
                'No Accessibility Service, no Device Admin, no VPN, no device-owner profile, no kiosk mode. '
                'Those routes can cover a whole phone, and they can also see and control everything on it. '
                'Track Pro covers a list of apps you choose, and nothing else.',
                style: TextStyle(fontSize: 12.5, height: 1.5, fontWeight: FontWeight.w500, color: TrackTheme.label2(dark)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Track Pro keeps focus sessions on this device. Nothing about which apps you open is sent anywhere: '
          'the counts you see during a session are computed here and deleted with the session.',
          style: TextStyle(fontSize: 12, height: 1.5, fontWeight: FontWeight.w500, color: TrackTheme.label3(dark)),
        ),
      ],
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.icon,
    required this.title,
    required this.granted,
    required this.reason,
    required this.without,
    required this.onOpen,
  });

  final IconData icon;
  final String title;
  final bool granted;
  final String reason;
  final String without;
  final Future<void> Function() onOpen;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: TrackTheme.surface(dark),
        borderRadius: BorderRadius.circular(TrackTheme.radiusCard),
        border: Border.all(color: TrackTheme.separator(dark), width: .5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 19, color: TrackTheme.orange),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, letterSpacing: -.2, color: TrackTheme.label(dark))),
              ),
              Text(granted ? 'Granted' : 'Not granted',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: granted ? TrackTheme.green : TrackTheme.orange,
                  )),
            ],
          ),
          const SizedBox(height: 6),
          Text(reason,
              style: TextStyle(fontSize: 12.5, height: 1.45, fontWeight: FontWeight.w500, color: TrackTheme.label2(dark))),
          const SizedBox(height: 4),
          Text(without,
              style: TextStyle(fontSize: 12, height: 1.45, fontWeight: FontWeight.w500, color: TrackTheme.label3(dark))),
          const SizedBox(height: 8),
          Pressable(
            onTap: () => unawaited(onOpen()),
            child: Text(granted ? 'Open system settings' : 'Open system settings →',
                style: TextStyle(fontSize: 12.8, fontWeight: FontWeight.w700, color: granted ? TrackTheme.label2(dark) : TrackTheme.blue)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// App picker
// ---------------------------------------------------------------------------
/// Multi-select over the launchable apps the platform reports.
///
/// Three things the picker refuses to do: list an app it cannot actually cover,
/// let the free tier quietly drop the extra selections, or hide *why* an app is
/// unselectable. Protected entries (dialer, launcher, system UI, keyboards, Track Pro)
/// appear greyed with their reason, because a missing entry looks like a bug and an
/// unexplained one looks like a decision the user did not make.
Future<List<String>?> showFocusAppPicker(
  BuildContext context, {
  required List<String> selected,
  required FocusMode mode,
}) async {
  final app = context.read<AppState>();
  final apps = await app.loadFocusApps();
  if (!context.mounted) return null;

  return showGlassSheet<List<String>>(
    context,
    title: 'Cover which apps?',
    subtitle: apps.isEmpty
        ? 'This device did not report any apps to Track Pro. Without usage access, the list cannot be read — '
            'that permission is also what makes covering possible.'
        : 'Only the apps you pick are selected for coverage, and only while a session runs.',
    accent: TrackTheme.indigo,
    scrollable: true,
    body: _AppPickerBody(apps: apps, selected: selected, mode: mode),
    actions: const [],
  );
}

class _AppPickerBody extends StatefulWidget {
  const _AppPickerBody({required this.apps, required this.selected, required this.mode});

  final List<FocusAppInfo> apps;
  final List<String> selected;
  final FocusMode mode;

  @override
  State<_AppPickerBody> createState() => _AppPickerBodyState();
}

class _AppPickerBodyState extends State<_AppPickerBody> {
  late final Set<String> _selected = Set<String>.from(widget.selected);
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final dark = Theme.of(context).brightness == Brightness.dark;
    final query = _query.trim().toLowerCase();

    final visible = widget.apps
        .where((a) => query.isEmpty || a.label.toLowerCase().contains(query) || a.packageName.contains(query))
        .toList()
      ..sort((a, b) {
        if (a.protectedFromBlocking != b.protectedFromBlocking) return a.protectedFromBlocking ? 1 : -1;
        final aSel = _selected.contains(a.packageName);
        final bSel = _selected.contains(b.packageName);
        if (aSel != bSel) return aSel ? -1 : 1;
        return a.label.toLowerCase().compareTo(b.label.toLowerCase());
      });

    final atLimit = !app.canBlockMoreApps;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          textInputAction: TextInputAction.search,
          style: TextStyle(fontSize: 14.5, color: TrackTheme.label(dark)),
          decoration: InputDecoration(
            hintText: 'Search apps',
            prefixIcon: const Icon(Icons.search_rounded),
            filled: true,
            fillColor: TrackTheme.fill(dark),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(11),
              borderSide: BorderSide.none,
            ),
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
        const SizedBox(height: 10),
        if (widget.apps.isEmpty)
          Text(
            'No apps available to cover on this device right now. Sessions still work as timers.',
            style: TextStyle(fontSize: 13, height: 1.5, fontWeight: FontWeight.w500, color: TrackTheme.label2(dark)),
          )
        else
          GlassList(children: [
            for (final info in visible.take(200))
              _AppRow(
                info: info,
                selected: _selected.contains(info.packageName),
                locked: !info.protectedFromBlocking && atLimit && !_selected.contains(info.packageName),
                onToggle: () => _toggle(info, app),
              ),
            if (visible.length > 200)
              Padding(
                padding: const EdgeInsets.fromLTRB(15, 12, 15, 12),
                child: Text('${visible.length - 200} more apps match — narrow the search.',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: TrackTheme.label3(dark))),
              ),
          ]),
        if (atLimit) ...[
          const SizedBox(height: 10),
          ProLockedRow(
            title: 'Cover more than ${ProConfig.freeBlockedApps} apps',
            subtitle: 'Pro removes the ceiling on the app list. Every mode, the timer and your session '
                'history stay free.',
            emoji: 'focus',
            accent: TrackTheme.indigo,
            onTap: () => showPaywall(context, trigger: PaywallTrigger.focusApps),
          ),
        ],
        const SizedBox(height: 12),
        TrackFilledButton(
          label: _selected.isEmpty ? 'No apps selected' : 'Select ${_selected.length} app${_selected.length == 1 ? '' : 's'}',
          color: TrackTheme.indigo,
          onTap: () => Navigator.of(context).pop(_selected.toList()),
        ),
        const SizedBox(height: 8),
        Text(
          'Track Pro requests coverage for these apps only while a ${widget.mode.label.toLowerCase()} session is running '
          '${FocusEngine.pauseSuspendsEnforcement(widget.mode) ? '— and a pause stops coverage until you resume' : '— a paused session keeps coverage requested'}.',
          style: TextStyle(fontSize: 11.8, height: 1.45, fontWeight: FontWeight.w500, color: TrackTheme.label3(dark)),
        ),
        const SizedBox(height: 4),
        Text(
          'Dialer, launcher, system interface, keyboards and Track Pro are listed but cannot be chosen.',
          style: TextStyle(fontSize: 11.8, height: 1.45, fontWeight: FontWeight.w500, color: TrackTheme.label3(dark)),
        ),
      ],
    );
  }

  void _toggle(FocusAppInfo info, AppState app) {
    if (info.protectedFromBlocking) {
      showTrackToast(context, '${info.label} is protected and is never covered');
      return;
    }
    if (_selected.contains(info.packageName)) {
      setState(() => _selected.remove(info.packageName));
      app.setFocusDraftAppCount(_selected.length);
      Haptics.selection();
      return;
    }
    if (!app.canBlockMoreApps) {
      showPaywall(context, trigger: PaywallTrigger.focusApps);
      return;
    }
    setState(() => _selected.add(info.packageName));
    app.setFocusDraftAppCount(_selected.length);
    Haptics.selection();
  }
}

class _AppRow extends StatelessWidget {
  const _AppRow({required this.info, required this.selected, required this.locked, required this.onToggle});

  final FocusAppInfo info;
  final bool selected;
  final bool locked;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Pressable(
      onTap: onToggle,
      scale: .99,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(info.label,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -.2,
                        color: info.protectedFromBlocking ? TrackTheme.label3(dark) : TrackTheme.label(dark),
                      )),
                  Text(
                    info.protectedFromBlocking ? 'Protected — never covered' : info.packageName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.8, fontWeight: FontWeight.w500, color: TrackTheme.label3(dark)),
                  ),
                ],
              ),
            ),
            if (info.protectedFromBlocking)
              Icon(Icons.lock_outline_rounded, size: 16, color: TrackTheme.label3(dark))
            else if (locked)
              ProChip(compact: true)
            else
              Icon(
                selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                size: 21,
                color: selected ? TrackTheme.indigo : TrackTheme.label3(dark).withOpacity(.5),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Goal picker — link a session to a routine, the way the brief asks
// ---------------------------------------------------------------------------
/// Returns the chosen goal: the routine's id (null for a free session) and the label
/// that will be stored on the session row.
Future<({String? id, String label})?> showFocusGoalPicker(BuildContext context) {
  final app = context.read<AppState>();
  return showGlassSheet<({String? id, String label})>(
    context,
    title: 'What is this session for?',
    subtitle: 'The goal is stored with the session, so your history reads as "45 minutes on the '
        'dissertation" instead of "45 minutes".',
    accent: TrackTheme.blue,
    scrollable: true,
    body: _GoalBody(
      commitments: app.commitments,
      onDone: (choice) => Navigator.of(context).pop(choice),
    ),
    actions: const [],
  );
}

class _GoalBody extends StatelessWidget {
  const _GoalBody({required this.commitments, required this.onDone});

  final List<Commitment> commitments;
  final void Function(({String? id, String label}) choice) onDone;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassList(children: [
          GlassRow(
            title: 'Focus session',
            subtitle: 'A plain session with no routine attached',
            leading: const Icon(Icons.track_changes_outlined, size: 18, color: TrackTheme.orange),
            accent: TrackTheme.blue,
            onTap: () => onDone((id: null, label: 'Focus session')),
          ),
          for (final c in commitments)
            GlassRow(
              title: c.name,
              subtitle: c.fullAction.isEmpty ? 'Link this session to your routine' : c.fullAction,
              accent: TrackTheme.green,
              onTap: () => onDone((id: c.id, label: c.name)),
            ),
        ]),
        const SizedBox(height: 10),
        Text(
          'Linking a session to a routine does not mark the routine done — the outcome is still recorded '
          'where you record it, with the buttons that already exist. The link is context for your history.',
          style: TextStyle(
            fontSize: 11.8,
            height: 1.45,
            fontWeight: FontWeight.w500,
            color: TrackTheme.label3(Theme.of(context).brightness == Brightness.dark),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Custom duration
// ---------------------------------------------------------------------------
Future<int?> showFocusCustomMinutesSheet(BuildContext context, {required int initial}) {
  return showGlassSheet<int>(
    context,
    title: 'Custom length',
    subtitle: 'Between ${FocusEngine.minCustomMinutes} minutes and '
        '${FocusEngine.maxCustomMinutes ~/ 60} hours. A session length is a promise you make to yourself; '
        'Track Pro will not let you set one it cannot keep.',
    accent: TrackTheme.blue,
    body: _CustomMinutesBody(initial: initial, onDone: (m) => Navigator.of(context).pop(m)),
    actions: const [],
  );
}

class _CustomMinutesBody extends StatefulWidget {
  const _CustomMinutesBody({required this.initial, required this.onDone});

  final int initial;
  final void Function(int) onDone;

  @override
  State<_CustomMinutesBody> createState() => _CustomMinutesBodyState();
}

class _CustomMinutesBodyState extends State<_CustomMinutesBody> {
  late int _minutes = FocusEngine.clampMinutes(widget.initial);

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('${_minutes} minutes',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: -.8, color: TrackTheme.label(dark))),
        const SizedBox(height: 8),
        Slider(
          value: _minutes.toDouble(),
          min: FocusEngine.minCustomMinutes.toDouble(),
          max: FocusEngine.maxCustomMinutes.toDouble(),
          divisions: FocusEngine.maxCustomMinutes - FocusEngine.minCustomMinutes,
          activeColor: TrackTheme.blue,
          onChanged: (v) => setState(() => _minutes = FocusEngine.clampMinutes(v.round())),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (final step in const <int>[5, 10, 15]) ...[
              Expanded(
                child: TrackTintedButton(
                  label: '+$step',
                  color: TrackTheme.blue,
                  onTap: () => setState(() => _minutes = FocusEngine.clampMinutes(_minutes + step)),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: TrackTintedButton(
                label: '−5',
                color: TrackTheme.orange,
                onTap: () => setState(() => _minutes = FocusEngine.clampMinutes(_minutes - 5)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TrackFilledButton(label: 'Use $_minutes min', onTap: () => widget.onDone(_minutes)),
      ],
    );
  }
}

/// Small helpers shared by the sheets above.
class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 16, 2, 8),
      child: Text(text.toUpperCase(),
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, letterSpacing: .5, color: TrackTheme.label3(dark))),
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? TrackTheme.blue : TrackTheme.fill(dark),
          borderRadius: BorderRadius.circular(TrackTheme.radiusPill),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : TrackTheme.label(dark),
            )),
      ),
    );
  }
}
