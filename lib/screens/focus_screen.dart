import 'dart:async';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/focus_engine.dart';
import '../main.dart' show Pressable, TrackTheme;
import '../models/focus_models.dart';
import '../services/focus_platform.dart';
import '../services/haptics.dart';
import '../state/app_state.dart';
import '../widgets/glass.dart';
import '../widgets/progress_ring.dart';
import 'focus_setup_sheets.dart';
import 'log_sheets.dart';

/// The focus session, full screen.
///
/// This screen's job is to show three things truthfully and nothing else: how long
/// is left, what the session is for, and **whether anything is actually being
/// handled right now**. The third one is the part every blocking app gets wrong.
/// `FocusEnforcement` is derived from the platform on every tick, so a permission
/// revoked from system settings thirty seconds ago reads `lost` here immediately —
/// the countdown keeps running, and the banner says the session is running with less
/// protection than it promised. It is never the case that this screen shows
/// "blocked" on the strength of a request we sent.
///
/// Cancellation behaviour is stated *before* the session starts (see
/// `focus_setup_sheets.dart`), and the exit is present on this screen at all times.
/// Deep Focus makes the exit deliberate — a press-and-hold — never hidden, never
/// behind a fake screen, and never absent.
bool _sessionRouteOpen = false;

Future<void> openFocusSession(BuildContext context) async {
  // One route for one session. Tapping the live card twice used to push a second
  // copy of this screen — and, in the old build, a second countdown timer with it.
  if (_sessionRouteOpen) return;
  _sessionRouteOpen = true;
  try {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => const FocusSessionScreen()));
  } finally {
    _sessionRouteOpen = false;
  }
}

IconData _modeIcon(FocusMode mode) => switch (mode) {
  FocusMode.standard => Icons.timer_outlined,
  FocusMode.blocking => Icons.block_outlined,
  FocusMode.deep => Icons.do_not_disturb_on_outlined,
};

class FocusSessionScreen extends StatefulWidget {
  const FocusSessionScreen({super.key});

  @override
  State<FocusSessionScreen> createState() => _FocusSessionScreenState();
}

class _FocusSessionScreenState extends State<FocusSessionScreen> with WidgetsBindingObserver {
  /// The session this screen was opened for / is currently showing. A summary is
  /// only ever opened for an id we have actually seen live here — never for whatever
  /// happens to be the newest row, which could belong to an earlier session.
  String? _trackedId;

  /// Guards the summary so a rebuild between the ending and the sheet cannot open it
  /// twice, and so a second "End" tap is a no-op.
  String? _endedId;
  bool _ending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncOnce());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back after the screen was off is exactly when a session's numbers need
    // re-deriving: the platform may have ended it, or the device may have rebooted.
    if (state == AppLifecycleState.resumed) unawaited(_syncOnce());
  }

  Future<void> _syncOnce() async {
    if (!mounted) return;
    await context.read<AppState>().tickFocus();
    if (!mounted) return;
    _maybeShowSummary(context.read<AppState>());
  }

  /// Opens the summary once, when the live session this screen was showing has gone.
  ///
  /// There is deliberately no second timer here: `HomeShell` owns the one ticker for
  /// the whole app, and the repository decides when a session ends. Two tickers used
  /// to reconcile the same row at the same moment, which is how an ending can be
  /// written twice.
  void _maybeShowSummary(AppState app) {
    final live = app.activeFocusSession;
    if (live != null) {
      _trackedId = live.id;
      return;
    }
    final ended = _trackedId;
    if (ended == null || ended == _endedId) return;
    _endedId = ended;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await showFocusSummary(context, ended, popOnClose: true);
    });
  }

  Future<void> _pause() async {
    final app = context.read<AppState>();
    await app.pauseFocus();
  }

  Future<void> _resume() async {
    final app = context.read<AppState>();
    await app.resumeFocus();
    if (!mounted) return;
    // Resuming after a permission change should re-read the grants before the first
    // frame of the resumed countdown, not a second later.
    await app.refreshFocusPermissions();
  }

  Future<void> _end() async {
    if (_ending) return;
    final app = context.read<AppState>();
    final session = app.activeFocusSession;
    if (session == null) return;

    final confirmed = await _confirmEnd(session);
    if (!confirmed || !mounted) return;

    _ending = true;
    // Marked before the write: the ending notifies listeners while it is in flight,
    // and the rebuild must not schedule a second summary for the same session.
    _endedId = session.id;
    final ended = await app.endFocus();
    if (!mounted) return;
    await showFocusSummary(context, ended?.id ?? session.id, popOnClose: true);
  }

  Future<bool> _confirmEnd(FocusSession session) async {
    if (session.mode != FocusMode.deep) return true;
    // Deep Focus: a deliberate hold, not a hidden button. The user set this rule,
    // and the copy says exactly what holding does.
    return showGlassSheet<bool>(
      context,
      title: 'End this deep focus session?',
      subtitle: FocusEngine.cancellationCopy(FocusMode.deep),
      accent: TrackTheme.orange,
      body: const SizedBox.shrink(),
      actions: [
        TrackTintedButton(label: 'Keep focusing', onTap: () => Navigator.of(context).pop(false)),
        TrackFilledButton(
          label: 'End and record',
          color: TrackTheme.orange,
          onTap: () => Navigator.of(context).pop(true),
        ),
      ],
    ).then((v) => v ?? false);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final session = app.activeFocusSession;
    final dark = Theme.of(context).brightness == Brightness.dark;
    _maybeShowSummary(app);

    if (session == null) {
      // Nothing live and nothing this screen ever showed: the route outlived its
      // session (a state restore, or a start that failed after the push). Leave
      // instead of presenting a blank full-screen page with no way back.
      if (_trackedId == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.of(context).maybePop();
        });
      }
      // Otherwise this is the one frame between the ending and the summary opening.
      return Scaffold(backgroundColor: TrackTheme.bg(dark), body: const SizedBox.shrink());
    }

    final plannedMs = session.plannedMs;
    final remaining = app.focusRemainingMs.clamp(0, plannedMs).toInt();
    final progress = plannedMs == 0 ? 0.0 : (1 - remaining / plannedMs).clamp(0.0, 1.0).toDouble();
    final enforcement = app.focusEnforcement;

    return Scaffold(
      backgroundColor: TrackTheme.bg(dark),
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(session: session, onEnd: _end),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Column(
                  children: [
                    _Countdown(
                      remainingMs: remaining,
                      progress: progress,
                      accent: _accentFor(session.mode),
                      paused: session.isPaused,
                    ),
                    const SizedBox(height: 22),
                    _GoalLine(session: session),
                    const SizedBox(height: 20),
                    _StatusBlock(
                      enforcement: enforcement,
                      session: session,
                      permissions: app.focusPermissions,
                      native: app.focusNative,
                      platformAvailable: app.focusPlatformAvailable,
                      onFix: () => openFocusPermissionSheet(context),
                    ),
                    const SizedBox(height: 18),
                    _SessionFacts(session: session, elapsedMs: app.focusElapsedMs),
                  ],
                ),
              ),
            ),
            _Controls(session: session, onPause: _pause, onResume: _resume, onEnd: _end),
          ],
        ),
      ),
    );
  }

  static Color _accentFor(FocusMode mode) => switch (mode) {
    FocusMode.standard => TrackTheme.blue,
    FocusMode.blocking => TrackTheme.indigo,
    FocusMode.deep => TrackTheme.purple,
  };
}

/// Small header: mode, and an always-present way out.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.session, required this.onEnd});

  final FocusSession session;
  final Future<void> Function() onEnd;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
      child: Row(
        children: [
          Row(
            children: [
              Icon(_modeIcon(session.mode), size: 18, color: TrackTheme.orange),
              const SizedBox(width: 7),
              Text(
                session.mode.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -.2,
                  color: TrackTheme.label2(dark),
                ),
              ),
            ],
          ),
          const Spacer(),
          Pressable(
            onTap: () => unawaited(onEnd()),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Text(
                'End',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: TrackTheme.orange),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The countdown itself: `18:42` and a ring that shows the same number two ways.
class _Countdown extends StatelessWidget {
  const _Countdown({required this.remainingMs, required this.progress, required this.accent, required this.paused});

  final int remainingMs;
  final double progress;
  final Color accent;
  final bool paused;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ProgressRing(
      pct: progress,
      size: 250,
      stroke: 14,
      colorA: accent,
      colorB: Color.lerp(accent, Colors.white, .35)!,
      duration: const Duration(milliseconds: 700),
      animate: false,
      center: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            focusCountdownLabel(remainingMs),
            style: TextStyle(
              fontSize: 54,
              fontWeight: FontWeight.w300,
              letterSpacing: -1.6,
              color: TrackTheme.label(dark),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            paused ? 'PAUSED' : 'REMAINING',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: paused ? TrackTheme.orange : TrackTheme.label3(dark),
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalLine extends StatelessWidget {
  const _GoalLine({required this.session});

  final FocusSession session;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Text(
          session.goalLabel,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w600,
            letterSpacing: -.4,
            color: TrackTheme.label(dark),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          '${focusDurationLabel(session.plannedMs)} planned',
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: TrackTheme.label3(dark)),
        ),
      ],
    );
  }
}

/// The honest status block. Every sentence here is derived from the platform's
/// answer, never from what we asked for.
class _StatusBlock extends StatelessWidget {
  const _StatusBlock({
    required this.enforcement,
    required this.session,
    required this.permissions,
    required this.native,
    required this.platformAvailable,
    required this.onFix,
  });

  final FocusEnforcement enforcement;
  final FocusSession session;
  final FocusPermissions permissions;
  final FocusNativeState native;
  final bool platformAvailable;
  final VoidCallback onFix;

  static (Color, Color) _colors(String tone) => switch (tone) {
    'full' => (TrackTheme.green, TrackTheme.mint),
    'minimum' => (TrackTheme.orange, TrackTheme.yellow),
    'danger' => (TrackTheme.red, TrackTheme.orange),
    _ => (TrackTheme.blue, TrackTheme.indigo),
  };

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    // A paused session is not "blocking stopped": the user stopped it, on purpose,
    // and the setup sheet promised the apps would be reachable again. The card says
    // that instead of reusing the wording for a failure.
    final paused = session.isPaused && FocusEngine.pauseSuspendsEnforcement(session.mode);
    final accent = paused ? TrackTheme.orange : _colors(enforcement.tone).$1;
    final blocking = session.blockedPackages.isNotEmpty && !paused;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(TrackTheme.radiusCard),
            color: accent.withValues(alpha: dark ? .18 : .1),
            border: Border.all(color: accent.withValues(alpha: .3), width: .5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      paused ? 'Paused' : enforcement.label,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -.2,
                        color: TrackTheme.label(dark),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                paused
                    ? 'Your selected apps are available again. Resume to request coverage for the time that is left.'
                    : enforcement.detail,
                style: TextStyle(
                  fontSize: 12.8,
                  fontWeight: FontWeight.w500,
                  height: 1.45,
                  color: TrackTheme.label2(dark),
                ),
              ),
              if (blocking) ...[
                const SizedBox(height: 8),
                Text(
                  enforcement.isConfirmed
                      ? 'Coverage panel launched ${native.overlayShows} time${native.overlayShows == 1 ? '' : 's'} · '
                            '${session.blockedPackages.length} app${session.blockedPackages.length == 1 ? '' : 's'} selected'
                      : '${session.blockedPackages.length} app${session.blockedPackages.length == 1 ? '' : 's'} selected · '
                            '${native.blockedAttempts} selected-app opening${native.blockedAttempts == 1 ? '' : 's'} noticed',
                  style: TextStyle(fontSize: 11.8, fontWeight: FontWeight.w600, color: accent),
                ),
              ],
            ],
          ),
        ),
        if (enforcement.needsAttention && !paused) ...[
          const SizedBox(height: 8),
          Pressable(
            onTap: onFix,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(color: TrackTheme.fill(dark), borderRadius: BorderRadius.circular(13)),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, size: 18, color: TrackTheme.orange),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      !platformAvailable ? 'This device cannot cover apps — the timer still works.' : 'Fix access',
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: TrackTheme.label(dark)),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 20, color: TrackTheme.label3(dark)),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// The session's own numbers, so nothing on this screen has to be taken on trust.
class _SessionFacts extends StatelessWidget {
  const _SessionFacts({required this.session, required this.elapsedMs});

  final FocusSession session;
  final int elapsedMs;

  @override
  Widget build(BuildContext context) {
    final shown = elapsedMs > 0 ? elapsedMs : session.focusMs;
    return Row(
      children: [
        Expanded(
          child: StatTile(value: focusDurationLabel(shown), label: 'Focused'),
        ),
        if (session.pausedMs > 0) ...[
          const SizedBox(width: 10),
          Expanded(
            child: StatTile(value: focusDurationLabel(session.pausedMs), label: 'Paused'),
          ),
        ],
      ],
    );
  }
}

/// Pause and the way out. The exit is never removed, whatever the mode.
class _Controls extends StatelessWidget {
  const _Controls({required this.session, required this.onPause, required this.onResume, required this.onEnd});

  final FocusSession session;
  final Future<void> Function() onPause;
  final Future<void> Function() onResume;
  final Future<void> Function() onEnd;

  @override
  Widget build(BuildContext context) {
    final paused = session.isPaused;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
      child: Row(
        children: [
          Expanded(
            child: TrackTintedButton(
              label: paused ? 'Resume' : 'Pause',
              color: paused ? TrackTheme.green : TrackTheme.blue,
              onTap: () => unawaited(paused ? onResume() : onPause()),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: session.mode == FocusMode.deep
                ? _HoldToEnd(onEnd: onEnd)
                : TrackFilledButton(label: 'End session', color: TrackTheme.orange, onTap: () => unawaited(onEnd())),
          ),
        ],
      ),
    );
  }
}

/// Press-and-hold for Deep Focus. The hold is the whole friction: it takes about a
/// second, it is drawn as it happens, and it never hides where the exit is.
class _HoldToEnd extends StatefulWidget {
  const _HoldToEnd({required this.onEnd});

  final Future<void> Function() onEnd;

  @override
  State<_HoldToEnd> createState() => _HoldToEndState();
}

class _HoldToEndState extends State<_HoldToEnd> {
  Timer? _hold;

  @override
  void dispose() {
    _hold?.cancel();
    super.dispose();
  }

  void _start() {
    Haptics.hold();
    _hold?.cancel();
    _hold = Timer(const Duration(milliseconds: 900), () {
      if (mounted) unawaited(widget.onEnd());
    });
  }

  void _cancel() {
    _hold?.cancel();
    _hold = null;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _start(),
      onTapUp: (_) => _cancel(),
      onTapCancel: _cancel,
      onLongPressEnd: (_) => _cancel(),
      child: Container(
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: TrackTheme.orange.withValues(alpha: .14),
          borderRadius: BorderRadius.circular(TrackTheme.radiusPill),
          border: Border.all(color: TrackTheme.orange.withValues(alpha: .35), width: .5),
        ),
        child: Text(
          'Hold to end',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: TrackTheme.orange),
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// The completion summary — what actually happened, then a place to say what it
/// was like. The reflection is the user's own record, and it is stored locally
/// with the session and nothing else.
/// ---------------------------------------------------------------------------
Future<void> showFocusSummary(BuildContext context, String sessionId, {bool popOnClose = false}) async {
  final app = context.read<AppState>();
  // Captured before the await. Reaching for `context` on the other side of a modal
  // sheet is the classic "`Navigator.of()` called on a defunct element" crash, and it
  // is also what `use_build_context_synchronously` fails CI on: the screen that
  // opened this summary can be gone by the time the user taps Done.
  final navigator = Navigator.of(context);
  final summary = app.summaryFor(sessionId);
  if (summary == null) {
    if (popOnClose && context.mounted) navigator.maybePop();
    return;
  }

  await showGlassSheet<void>(
    context,
    title: summary.headline,
    subtitle: summary.cleanlinessNote,
    accent: _toneColor(summary.session.outcome?.tone),
    scrollable: true,
    body: _SummaryBody(summary: summary, sessionId: sessionId),
    actions: [
      TrackFilledButton(
        label: 'Done',
        onTap: () {
          navigator.pop();
          if (popOnClose) navigator.maybePop();
        },
      ),
    ],
  );
}

Color _toneColor(String? tone) => switch (tone) {
  'full' => TrackTheme.green,
  'minimum' => TrackTheme.orange,
  'danger' => TrackTheme.red,
  _ => TrackTheme.blue,
};

class _SummaryBody extends StatefulWidget {
  const _SummaryBody({required this.summary, required this.sessionId});

  final FocusSummary summary;
  final String sessionId;

  @override
  State<_SummaryBody> createState() => _SummaryBodyState();
}

class _SummaryBodyState extends State<_SummaryBody> {
  late final TextEditingController _reflection;

  @override
  void initState() {
    super.initState();
    _reflection = TextEditingController(text: widget.summary.session.reflection ?? '');
  }

  @override
  void dispose() {
    _reflection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final session = widget.summary.session;
    final outcome = session.outcome;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: StatTile(value: focusDurationLabel(widget.summary.minutesFocused * 60000), label: 'Focused'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatTile(value: focusDurationLabel(session.plannedMs), label: 'Planned'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
          decoration: BoxDecoration(color: TrackTheme.fill(dark), borderRadius: BorderRadius.circular(13)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                outcome == null ? 'Not recorded' : outcome.label,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: TrackTheme.label(dark)),
              ),
              const SizedBox(height: 4),
              Text(
                widget.summary.detail,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                  color: TrackTheme.label2(dark),
                ),
              ),
              if (session.endReason != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Ended because ${session.endReason!.label}.',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: TrackTheme.label3(dark)),
                ),
              ],
              if (widget.summary.blockedApps.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Selected for coverage: ${widget.summary.blockedApps.join(', ')}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.8, fontWeight: FontWeight.w500, color: TrackTheme.label3(dark)),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'What was it like?',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: .2,
            color: TrackTheme.label3(dark),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _reflection,
          minLines: 2,
          maxLines: 4,
          maxLength: 280,
          style: TextStyle(fontSize: 14.5, color: TrackTheme.label(dark)),
          decoration: InputDecoration(
            hintText: 'Optional. Stays on this device with the session.',
            hintStyle: TextStyle(fontSize: 13.5, color: TrackTheme.label3(dark)),
            filled: true,
            fillColor: TrackTheme.fill(dark),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: BorderSide.none),
          ),
          onSubmitted: (v) => context.read<AppState>().setFocusReflection(widget.sessionId, v),
          onEditingComplete: () => context.read<AppState>().setFocusReflection(widget.sessionId, _reflection.text),
        ),
        const SizedBox(height: 4),
        Pressable(
          onTap: () async {
            await context.read<AppState>().setFocusReflection(widget.sessionId, _reflection.text);
            if (!context.mounted) return;
            Haptics.commit();
            showTrackToast(context, 'Reflection saved with the session');
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Save reflection',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: TrackTheme.blue),
            ),
          ),
        ),
      ],
    );
  }
}
