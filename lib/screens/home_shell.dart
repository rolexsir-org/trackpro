import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/default_trackers.dart';
import '../main.dart' show TrackTheme;
import '../models/models.dart';
import '../widgets/glass.dart';
import '../services/notification_service.dart';
import '../state/app_state.dart';
import '../widgets/ios_tab_bar.dart';
import '../widgets/large_title_header.dart';
import '../widgets/progress_ring.dart';
import 'focus_setup_sheets.dart';
import 'insights_screen.dart';
import 'log_sheets.dart';
import 'momentum_screen.dart';
import 'routines_screen.dart';
import 'settings_screen.dart';
import 'today_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

/// One countdown ticker for the whole app.
///
/// The focus countdown used to be driven by the session screen alone, which meant
/// the card on Today froze whenever the screen was closed and a second ticker
/// started every time the screen was pushed again. There is now one timer, owned by
/// the shell (which is alive for the whole session), and every surface reads the
/// same clock-derived value. The value itself is never accumulated here: each tick
/// is recomputed from the monotonic clock, so a late or dropped tick cannot drift.
class _HomeShellState extends State<HomeShell> {
  Timer? _focusTicker;

  @override
  void initState() {
    super.initState();
    _focusTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final state = context.read<AppState>();
      if (state.focusLive) unawaited(state.tickFocus());
    });
  }

  @override
  void dispose() {
    _focusTicker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final tab = state.tabIndex;

    // Five sections, in the order the product thinks in: do → commit → verify →
    // understand → configure. Measurements are reached from Routines or Profile
    // rather than taking a tab of their own, because the habit loop is the app.
    final screens = <Widget>[
      const TodayScreen(),
      const RoutinesScreen(),
      const MomentumScreen(),
      const InsightsScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      backgroundColor: TrackTheme.bg(Theme.of(context).brightness == Brightness.dark),
      body: Stack(
        children: [
          // Keep every destination mounted. This preserves each tab's scroll
          // position and transient UI (such as Routines filters) while still
          // letting AppState own the actual persisted records.
          Positioned.fill(
            child: IndexedStack(index: tab, children: screens),
          ),
          Positioned(
            right: 18,
            // The tab bar grows when Android accessibility text wraps a tab
            // label. Anchor the FAB above its measured height instead of a
            // fixed 104px so the two controls cannot overlap.
            bottom: IosTabBar.totalHeight(context) + 20,
            child: QuickAddFab(
              visible: tab == 0,
              onTap: () => showQuickAdd(context),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IosTabBar(index: tab, onChanged: (i) => context.read<AppState>().setTab(i)),
          ),
          // A write that did not reach the database says so, once, until it is
          // dismissed. This is the other half of the rollback in `AppState._persist`:
          // the projection is corrected silently, so without this the user would simply
          // see their number change back with no explanation.
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            left: 12,
            right: 12,
            child: _WriteFailureBanner(
              failure: state.writeFailure,
              onDismiss: state.acknowledgeWriteFailure,
            ),
          ),
          // First-launch story: three screens, then straight into a populated app.
          const _OnboardingOverlay(),
          // Tapping the 9pm check-in or a streak saver lands on the right sheet
          // instead of dumping the user on the dashboard.
          const NotificationRouter(),
        ],
      ),
    );
  }
}

/// "That change was not saved", in the app's own surfaces.
///
/// It names the action in the user's words ("Water was not saved"), states what happened
/// to their data ("your previous value is unchanged") and never blocks the UI: it is a
/// banner, not a dialog, because the write already failed and an alert would only add a
/// second interruption to the first one.
class _WriteFailureBanner extends StatelessWidget {
  const _WriteFailureBanner({required this.failure, required this.onDismiss});

  final SaveFailure? failure;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      transitionBuilder: (child, anim) => SizeTransition(
        sizeFactor: anim,
        axisAlignment: -1,
        child: FadeTransition(opacity: anim, child: child),
      ),
      child: failure == null
          ? const SizedBox.shrink(key: ValueKey<String>('no-write-failure'))
          : Container(
              key: const ValueKey<String>('write-failure'),
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
              decoration: BoxDecoration(
                color: dark ? const Color(0xFF2C1B12) : const Color(0xFFFFF4E8),
                borderRadius: BorderRadius.circular(TrackTheme.radiusCard),
                border: Border.all(color: TrackTheme.orange.withOpacity(.45)),
                boxShadow: TrackTheme.cardShadow(dark),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 20, color: TrackTheme.orange),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${failure!.action} was not saved',
                          style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -.2,
                              color: TrackTheme.label(dark)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          failure!.detail,
                          style: TextStyle(
                              fontSize: 12.5,
                              height: 1.35,
                              fontWeight: FontWeight.w500,
                              color: TrackTheme.label2(dark)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: onDismiss,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      child: Text(
                        'Dismiss',
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: dark ? TrackTheme.orange : const Color(0xFF9A4A00)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Onboarding — three beats describing what the app does, ending on a screen
/// that shows the user's *own* counters (zero on a fresh install, which is the
/// honest reading). Nothing here claims history the account does not have.
/// ---------------------------------------------------------------------------
class _OnboardingOverlay extends StatefulWidget {
  const _OnboardingOverlay();

  @override
  State<_OnboardingOverlay> createState() => _OnboardingOverlayState();
}

class _OnboardingOverlayState extends State<_OnboardingOverlay> {
  int step = 0;
  bool played = true;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (state.onboarded) return const SizedBox.shrink();
    final dark = Theme.of(context).brightness == Brightness.dark;

    const copy = <List<String>>[
      ['Start with one thing.', 'Pick a routine and set the smallest version that still counts — a 30-minute run can have a 5-minute minimum.'],
      ['Tap what happened.', 'Full, minimum, rest or skip. That one tap is all it takes, and it is saved on this phone.'],
      ['See what you kept.', 'Momentum shows the days you followed through, plus your focus time. Nothing is invented when there is no data.'],
    ];

    return AnimatedSlide(
      offset: Offset(0, played ? 0 : 1),
      duration: const Duration(milliseconds: 520),
      curve: TrackTheme.sheetCurve,
      child: Container(
        color: TrackTheme.bg(dark),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: _OnboardingArt(step: step, state: state),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 26),
              child: Column(
                children: [
                  Text(copy[step][0],
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 29, height: 1.12, fontWeight: FontWeight.w700, letterSpacing: -.8, color: TrackTheme.label(dark))),
                  const SizedBox(height: 12),
                  Text(copy[step][1],
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15, height: 1.5, fontWeight: FontWeight.w500, color: TrackTheme.label2(dark))),
                  const SizedBox(height: 22),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < 3; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: TrackTheme.easeOut,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: i == step ? 20 : 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: i == step ? TrackTheme.blue : TrackTheme.label3(dark),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  TrackFilledButton(
                    label: step == 2 ? 'Create my first routine' : 'Continue',
                    onTap: () {
                      if (step < 2) {
                        setState(() => step++);
                        return;
                      }
                      final state = context.read<AppState>();
                      state.completeOnboarding();
                      // Land on Routines, not on a dashboard of empty rings: the
                      // first meaningful action is creating a commitment, and the
                      // empty state there says so.
                      if (!state.hasCommitments) state.setTab(1);
                    },
                  ),
                  const SizedBox(height: 9),
                  TrackTintedButton(
                    label: 'Just show me the app',
                    onTap: () => context.read<AppState>().completeOnboarding(),
                  ),
                  const SizedBox(height: 26),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingArt extends StatelessWidget {
  const _OnboardingArt({required this.step, required this.state});

  final int step;

  /// The onboarding art shows the user's **own** counters where it makes a
  /// claim, so a fresh install legitimately reads zero.
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    switch (step) {
      case 0:
        return SizedBox(
          width: 250,
          height: 250,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // The dial encodes a real ratio (the share of the catalogue that
              // ships switched on), not a decorative percentage. A ring that
              // means nothing is exactly the kind of figure this app refuses.
              ProgressRing(
                pct: DefaultTrackers.enabledByDefault.length / DefaultTrackers.all().length,
                size: 196,
                stroke: 15,
                colorA: TrackTheme.blue,
                colorB: TrackTheme.cyan,
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // The real catalogue size, not a marketing number.
                  Text('${DefaultTrackers.enabledByDefault.length}',
                      style: TextStyle(fontSize: 38, fontWeight: FontWeight.w700, letterSpacing: -1.4, color: TrackTheme.label(dark))),
                  Text('TRACKERS READY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: .4, color: TrackTheme.label3(dark))),
                ],
              ),
              for (var i = 0; i < DefaultTrackers.all().length; i++)
                _orb(i, DefaultTrackers.all()[i].name),
            ],
          ),
        );
      case 1:
        // A diagram of the two answers a routine asks for, with no invented
        // quantities: the numbers are whatever the user chooses, so printing example
        // ones here only made them look like the app's defaults.
        return Container(
          width: 280,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: TrackTheme.surface(dark), borderRadius: BorderRadius.circular(18), boxShadow: TrackTheme.cardShadow(dark)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.track_changes_outlined, size: 20, color: TrackTheme.orange),
                  const SizedBox(width: 9),
                  Text('You choose both', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: TrackTheme.label(dark))),
                ],
              ),
              const SizedBox(height: 14),
              _SpecimenRow(
                dark: dark,
                label: 'Full',
                value: 'The thing itself',
                note: 'counts as a completed day',
              ),
              const SizedBox(height: 8),
              _SpecimenRow(
                dark: dark,
                label: 'Minimum',
                value: 'The smallest version',
                note: 'keeps the routine alive — not a full day',
              ),
              const SizedBox(height: 14),
              Text('A hard day still counts for something. It just does not count as the whole thing.',
                  style: TextStyle(fontSize: 12.5, height: 1.4, fontWeight: FontWeight.w500, color: TrackTheme.label3(dark))),
            ],
          ),
        );
      default:
        return Container(
          width: 300,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: TrackTheme.surface(dark), borderRadius: BorderRadius.circular(18), boxShadow: TrackTheme.cardShadow(dark)),
          child: Column(
            children: [
              const InsightCard(
                emoji: 'insight',
                title: 'Your own record, nothing else.',
                body: 'Everything you see is built from what you log here. There is no sample history and no '
                    'one else\'s data.',
                accent: TrackTheme.indigo,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(child: StatTile(value: '${state.entryCount}', label: 'Your entries')),
                  const SizedBox(width: 10),
                  Expanded(child: StatTile(value: '${state.bestStreak}', label: 'Day streak')),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatTile(
                      value: '${state.commitments.length}',
                      label: 'Routines',
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
    }
  }

  Widget _orb(int i, String label) {
    final angle = (i / 10) * math.pi * 2 - math.pi / 2;
    return Align(
      alignment: Alignment(math.cos(angle), math.sin(angle)),
      child: TrackRecordIcon(label: label, color: TrackTheme.orange, size: 34, iconSize: 18),
    );
  }
}


/// Routes notification taps: "quickadd" opens the all-tracker log sheet,
/// "insights" jumps to the Insights tab. Also pays off the cold-start payload
/// parked by the background handler.
class NotificationRouter extends StatefulWidget {
  const NotificationRouter({super.key});

  @override
  State<NotificationRouter> createState() => _NotificationRouterState();
}

class _NotificationRouterState extends State<NotificationRouter> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _drain());
  }

  void _drain() {
    final parked = pendingNotificationPayload;
    if (parked != null) {
      pendingNotificationPayload = null;
      _route(parked);
    }
    context.read<AppState>().notifications?.onTap.listen(_route);
  }

  void _route(String? payload) {
    if (!mounted || payload == null) return;
    final state = context.read<AppState>();
    switch (payload) {
      case 'focus':
        // A scheduled focus session's reminder. It opens the setup sheet — the session
        // is not started here and never starts itself, so the tap is still the moment
        // the person decides, with the mode, length and app list in front of them.
        state.setTab(0);
        Future<void>.delayed(const Duration(milliseconds: 260), () {
          if (mounted) showFocusStartSheet(context);
        });
        break;
      case 'insights':
        state.setTab(3);
        break;
      case 'today':
        state.setTab(0);
        break;
      case 'quickadd':
      default:
        state.setTab(0);
        Future<void>.delayed(const Duration(milliseconds: 260), () {
          if (mounted) showQuickAdd(context);
        });
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// A labelled `label → value` line used by the onboarding specimen card. Kept
/// tiny and local: it is illustration furniture, not a component of the product.
class _SpecimenRow extends StatelessWidget {
  const _SpecimenRow({required this.dark, required this.label, required this.value, required this.note});

  final bool dark;
  final String label;
  final String value;
  final String note;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: TrackTheme.label(dark))),
              Text(note, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: TrackTheme.label3(dark))),
            ],
          ),
        ),
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: TrackTheme.label2(dark))),
      ],
    );
  }
}
