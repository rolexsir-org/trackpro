import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'dart:ui' show FontFeature;

import '../config/design_system.dart';
import '../data/focus_engine.dart';
import '../main.dart' show Pressable, TrackTheme;
import '../models/models.dart';
import '../state/app_state.dart';
import '../util/format.dart';
import '../widgets/glass.dart';
import '../widgets/large_title_header.dart';
import '../widgets/ios_tab_bar.dart';
import '../widgets/tracker_card.dart';
import 'commitment_sheets.dart';
import 'detail_screen.dart';
import 'focus_history_screen.dart';
import 'focus_screen.dart';
import 'focus_setup_sheets.dart';
import 'log_sheets.dart';
import 'measurements_page.dart';

/// The dashboard. One scroll surface: greeting → hero tracker → 2-up grid of
/// every other tracker → the patterns only a unified app can surface.
class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final trackers = state.visibleTrackers;
    // The floating tab bar is above Android's navigation inset. Keep the last
    // card beyond both instead of relying on a fixed 130px value that can be too
    // small on gesture/navigation variants with a larger bottom inset.
    final requiredBottomPadding = IosTabBar.scrollClearance(context);
    final scrollBottomPadding = requiredBottomPadding > 130 ? requiredBottomPadding : 130.0;
    if (trackers.isEmpty) return const _NoTrackers();

    final hero = trackers.firstWhere((t) => t.hero, orElse: () => trackers.first);
    final grid = trackers.where((t) => t.id != hero.id).toList();

    return RefreshIndicator(
      color: Editorial.accent,
      backgroundColor: Editorial.surface,
      onRefresh: () => _refresh(context),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
        slivers: [
          LargeTitleHeader(
            title: greetingFor(DateTime.now()),
            subtitle: longDate(DateTime.now()),
            trailing: _Avatar(onTap: () => context.read<AppState>().setTab(4)),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(Editorial.s5, Editorial.s1, Editorial.s5, scrollBottomPadding),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // One quiet sentence when something the user asked for cannot currently
                // happen. It is a card, not a dialog: it never interrupts, and "not now"
                // silences it until the next launch.
                const _PermissionNotice(),
                // The commitment queue leads, because "what do I still have to do
                // today?" is the question this screen exists to answer. Measurements
                // sit underneath, where they are useful but not the point.
                const _CommitmentQueue(),
                // Focus Lock sits directly under the queue: if a session is running, it
                // is the most important thing on the screen, and if one is not, this is
                // where starting one lives. It is a card, not a tab — measurements stay
                // off the tab bar, and so does this.
                const _FocusCard(),
                HeroTrackerCard(
                  tracker: hero,
                  values: state.historyOf(hero.id),
                  // The refusal is surfaced rather than dropped: the card's own `onStep`
                  // returns void, so a swipe that changed nothing used to be
                  // indistinguishable from one that worked — the ring simply did not move
                  // and the haptic warning was the only signal there was.
                  onStep: (d) {
                    final before = state.today(hero.id);
                    if (state.logAdd(hero.id, d)) return;
                    showTrackToast(
                      context,
                      before <= 0
                          ? 'Nothing to remove — nothing is logged for ${hero.name} today.'
                          : 'That change was refused. Today stays as it is.',
                    );
                  },
                  onTap: () => openDetail(context, hero),
                  onLongPress: () => _quickActions(context, hero),
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, c) {
                    final w = (c.maxWidth - 12) / 2;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final t in grid)
                          SizedBox(
                            width: w,
                            child: TrackerCard(
                              tracker: t,
                              values: state.historyOf(t.id),
                              chartValues: state.week(t.id),
                              onTap: () => openDetail(context, t),
                              onLog: () => openLogSheet(context, t),
                              onLongPress: () => _quickActions(context, t),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SectionLabel('Your patterns', trailing: _SeeAll()),
                ..._patterns(state),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _refresh(BuildContext context) async {
    final state = context.read<AppState>();
    var written = 0;
    try {
      written = await state.syncHealth();
    } catch (_) {
      written = 0;
    }
    if (!context.mounted) return;
    final message = switch (written) {
      -2 => 'Health sync is a Pro feature — nothing was read',
      -1 => 'Health Connect permission was not granted',
      0 =>
        state.healthConnected
            ? 'Up to date · nothing new from Health Connect'
            : 'Everything here is local · Health Connect is not connected',
      _ => 'Synced · $written days from Health Connect',
    };
    showTrackToast(context, message);
  }

  /// Observations, or an honest account of why there are none.
  ///
  /// What was here before: a hardcoded "23-day streak" (shown whenever the real
  /// streak was under 20), "you are 7 days from the 30-day badge", "best week in
  /// three" and "sleep is the lever" — four invented claims that ignored the user's
  /// actual rows. Every figure below is now read from the record, and each card
  /// disappears when its own evidence is missing.
  List<Widget> _patterns(AppState state) {
    final cards = <Widget>[];

    // A commitment that is slipping, stated as arithmetic.
    for (final c in state.needsRestart.take(1)) {
      final plan = state.momentumFor(c.id)?.restart;
      if (plan == null) continue;
      cards.add(
        InsightCard(
          emoji: 'restart',
          title: '${c.name} has gone quiet — here is a restart plan.',
          body: '${plan.reason} ${plan.steps.first.title}: ${plan.steps.first.detail}',
          accent: TrackTheme.orange,
          accent2: TrackTheme.yellow,
        ),
      );
    }

    // The strongest measurement, only if it has been logged at all.
    final withData = state.visibleTrackers.where((t) => state.today(t.id) > 0).toList();
    if (withData.isNotEmpty) {
      final strongest =
          (withData..sort((a, b) => ringPct(b, state.today(b.id)).compareTo(ringPct(a, state.today(a.id))))).first;
      cards.add(
        InsightCard(
          emoji: strongest.emoji,
          title:
              '${strongest.name} is at ${(ringPct(strongest, state.today(strongest.id)) * 100).round()}% of today\'s goal.',
          body: strongest.insight,
          accent: strongest.accent,
          accent2: strongest.accent2,
        ),
      );
    }

    // Mood, described rather than explained — and only over days actually logged.
    final moodDays = state.loggedDaysInWindow(7);
    if (moodDays > 0 && state.today('mood') > 0) {
      final avg = state.avg('mood', 7);
      cards.add(
        InsightCard(
          emoji: 'mood',
          title: 'Mood averaged ${avg.toStringAsFixed(1)} over the last 7 days.',
          body:
              'From $moodDays day${moodDays == 1 ? '' : 's'} with a mood logged. '
              'Days you skipped are left out rather than counted as zero.',
          accent: TrackTheme.orange,
          accent2: TrackTheme.yellow,
        ),
      );
    }

    if (cards.isNotEmpty) return cards;

    return [
      const InsightCard(
        emoji: 'growth',
        title: 'Nothing to report yet',
        body: 'Log a few days and your patterns, averages and streaks will appear here.',
        accent: TrackTheme.green,
        accent2: TrackTheme.mint,
      ),
    ];
  }
}

/// Today's commitments, at the top of Today.
///
/// Two buttons per routine — the full target and the minimum — because the honest
/// choice on a hard day is between those two, not between doing it and failing. The
/// recorded state is a real row, and changing it reopens the same sheet.
class _CommitmentQueue extends StatelessWidget {
  const _CommitmentQueue();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final queue = state.todayCommitments;

    if (!state.hasCommitments) {
      return Padding(
        padding: const EdgeInsets.only(bottom: Editorial.s3),
        child: GestureDetector(
          onTap: () => showTemplatePicker(context),
          child: Container(
            decoration: Editorial.card(border: Editorial.accent.withValues(alpha: .4)),
            padding: const EdgeInsets.all(Editorial.s4),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Editorial.accent.withValues(alpha: .16),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.track_changes_outlined, size: 20, color: Editorial.accent),
                ),
                const SizedBox(width: Editorial.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Plan today', style: Editorial.figure.copyWith(fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(
                        'Pick a routine, set its minimum, and today starts counting.',
                        style: Editorial.caption,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: 20, color: Editorial.inkTertiary),
              ],
            ),
          ),
        ),
      );
    }

    final open = queue.where((t) => !t.logged).length;

    return Padding(
      padding: const EdgeInsets.only(bottom: Editorial.s3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: Editorial.s2),
            child: Wrap(
              spacing: Editorial.s2,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('TODAY', style: Editorial.label),
                Text(open == 0 ? 'everything logged' : '$open still open', style: Editorial.caption),
                if (state.overallMomentum?.rate != null)
                  Text(
                    '${state.overallMomentum!.rate!.round()}% momentum',
                    style: Editorial.caption.copyWith(color: Editorial.inkSecondary),
                  ),
              ],
            ),
          ),
          for (final item in queue) ...[_CommitmentTile(item: item), const SizedBox(height: Editorial.s2)],
        ],
      ),
    );
  }
}

class _CommitmentTile extends StatelessWidget {
  const _CommitmentTile({required this.item});

  final TodayCommitment item;

  @override
  Widget build(BuildContext context) {
    final c = item.commitment;
    final snap = item.snapshot;

    return Container(
      decoration: Editorial.card(),
      padding: const EdgeInsets.all(Editorial.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TrackRecordIcon(label: c.name, color: c.color, size: 30, iconSize: 17),
              const SizedBox(width: Editorial.s2),
              Expanded(
                flex: 2,
                child: Text(
                  c.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Editorial.figure.copyWith(fontSize: 15),
                ),
              ),
              if (item.paused) ...[
                const SizedBox(width: Editorial.s2),
                Flexible(
                  child: Text('paused', maxLines: 1, overflow: TextOverflow.ellipsis, style: Editorial.caption),
                ),
              ] else if (snap != null && snap.keepGoingStreak > 0) ...[
                const SizedBox(width: Editorial.s2),
                Flexible(
                  child: Text(
                    '${snap.keepGoingStreak} day${snap.keepGoingStreak == 1 ? '' : 's'} kept',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: Editorial.caption,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: Editorial.s3),
          if (item.logged)
            Row(
              children: [
                _OutcomeChip(outcome: item.outcome!),
                const Spacer(),
                GestureDetector(
                  onTap: () => showOutcomeSheet(context, c),
                  child: Text('Change', style: Editorial.caption.copyWith(color: Editorial.accent)),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: TrackFilledButton(
                    label: 'Full',
                    color: c.color,
                    onTap: () => _log(context, c.id, DayOutcome.full),
                  ),
                ),
                const SizedBox(width: Editorial.s2),
                Expanded(
                  child: TrackTintedButton(
                    label: 'Minimum',
                    color: c.color,
                    onTap: () => _log(context, c.id, DayOutcome.minimum),
                  ),
                ),
                const SizedBox(width: Editorial.s2),
                GestureDetector(
                  onTap: () => showOutcomeSheet(context, c),
                  child: Container(
                    height: 44,
                    width: 44,
                    alignment: Alignment.center,
                    decoration: Editorial.card(fill: Editorial.well),
                    child: Icon(Icons.more_horiz_rounded, size: 20, color: Editorial.inkTertiary),
                  ),
                ),
              ],
            ),
          if (!item.logged) ...[
            const SizedBox(height: Editorial.s2),
            Text('Minimum: ${c.minimumAction}', style: Editorial.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ],
      ),
    );
  }
}

/// One tap on Full or Minimum. The write is awaited so a refusal is reported in the
/// user's words instead of silently leaving the tile unchanged.
Future<void> _log(BuildContext context, String id, DayOutcome outcome) async {
  final saved = await context.read<AppState>().logCommitmentDay(id, outcome);
  if (!saved && context.mounted) {
    showTrackToast(context, 'That did not save. Your previous answer is unchanged.');
  }
}

class _OutcomeChip extends StatelessWidget {
  const _OutcomeChip({required this.outcome});

  final DayOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final tint = switch (outcome) {
      DayOutcome.full => Editorial.full,
      DayOutcome.minimum => Editorial.minimum,
      DayOutcome.missed => Editorial.missed,
      _ => Editorial.rest,
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
        ),
        const SizedBox(width: Editorial.s2),
        Text(outcome.label, style: Editorial.figure.copyWith(fontSize: 14, color: tint)),
      ],
    );
  }
}

class _SeeAll extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.read<AppState>().setTab(3),
      child: const Text(
        'See all',
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: TrackTheme.blue),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Editorial.well,
          border: Border.all(color: Editorial.hairline, width: .5),
        ),
        // The app has no account profile, so this is a destination affordance.
        child: const Icon(Icons.person_outline_rounded, size: 19, color: Editorial.accent),
      ),
    );
  }
}

/// Shown when every tracker has been hidden. Before this, the screen went blank
/// with no way back; now it says what happened and offers the one action that fixes
/// it.
class _NoTrackers extends StatelessWidget {
  const _NoTrackers();

  @override
  Widget build(BuildContext context) {
    final requiredBottomPadding = IosTabBar.scrollClearance(context);
    final scrollBottomPadding = requiredBottomPadding > 130 ? requiredBottomPadding : 130.0;
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
      slivers: [
        LargeTitleHeader(title: greetingFor(DateTime.now()), subtitle: longDate(DateTime.now())),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(Editorial.s5, Editorial.s1, Editorial.s5, scrollBottomPadding),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              Container(
                decoration: Editorial.card(),
                padding: const EdgeInsets.all(Editorial.s6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('All trackers are hidden', style: Editorial.title),
                    const SizedBox(height: Editorial.s3),
                    Text(
                      'Your trackers and history are still here. Turn one back on to see today on '
                      'this screen.',
                      style: Editorial.body,
                    ),
                    const SizedBox(height: Editorial.s5),
                    TrackFilledButton(
                      label: 'Manage trackers',
                      onTap: () =>
                          Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const MeasurementsPage())),
                    ),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

/// The one permission sentence Today is allowed to show.
///
/// Only things the user has already asked for appear here: reminders they switched
/// on, or focus schedules they created. Nothing asks for a grant in order to unlock
/// the habit loop, which needs no permission at all. The action opens the correct
/// Android surface — a runtime prompt for notifications, or Settings for the two
/// special grants — and never grants anything itself.
class _PermissionNotice extends StatelessWidget {
  const _PermissionNotice();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (state.permissionNoticeDismissed) return const SizedBox.shrink();

    final remindersBlocked = state.notifyDaily && !state.notificationsAllowed;
    final focusBlocked = !state.focusPermissions.canBlock && state.focusSchedules.any((s) => s.enabled);
    if (!remindersBlocked && !focusBlocked) return const SizedBox.shrink();

    final title = remindersBlocked ? 'Reminders cannot reach you' : 'Focus sessions cannot cover apps';
    final body = remindersBlocked
        ? 'This phone is blocking Track Pro notifications, so your daily check-in will not '
              'appear. Everything you log is still saved.'
        : 'Usage access and Display over other apps are still off. Sessions time and record '
              'normally; they just cannot cover the apps you pick.';
    final action = remindersBlocked ? 'Allow' : 'Review';

    return Padding(
      padding: const EdgeInsets.only(bottom: Editorial.s3),
      child: Container(
        decoration: Editorial.card(border: Editorial.minimum.withValues(alpha: .45)),
        padding: const EdgeInsets.fromLTRB(Editorial.s4, Editorial.s4, Editorial.s4, Editorial.s2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Editorial.figure),
            const SizedBox(height: Editorial.s1),
            Text(body, style: Editorial.body.copyWith(fontSize: 13.5)),
            const SizedBox(height: Editorial.s1),
            Row(
              children: [
                TrackTintedButton(
                  label: action,
                  onTap: () async {
                    if (!remindersBlocked) {
                      await openFocusPermissionSheet(context);
                      return;
                    }
                    // The card is the explanation; the system dialog is the request.
                    // Android only offers it once, so a refusal falls through to the
                    // app's notification settings rather than asking again.
                    final granted = await state.notifications?.requestPermission() ?? false;
                    if (!context.mounted) return;
                    if (granted) {
                      await state.refreshReminders();
                    } else {
                      await state.openNotificationSettings();
                    }
                  },
                ),
                const Spacer(),
                GestureDetector(
                  onTap: state.dismissPermissionNotice,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Editorial.s3, vertical: Editorial.s3),
                    child: Text('Not now', style: Editorial.caption.copyWith(color: Editorial.inkSecondary)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _quickActions(BuildContext context, Tracker t) async {
  final state = context.read<AppState>();
  final result = await showTrackContextMenu(
    context,
    Offset(MediaQuery.sizeOf(context).width * .25, MediaQuery.sizeOf(context).height * .34),
    // The hide/show line follows the tracker's current state — it said "Hide from
    // dashboard" even for a tracker that was already hidden, so the one control that
    // could bring it back read as a second way to hide it.
    items: [
      const ['Log now', Icons.add_rounded],
      const ['View history & insights', Icons.insights_outlined],
      const ['Change goal', Icons.flag_outlined],
      const ['Pin to top', Icons.vertical_align_top_rounded],
      if (t.hidden)
        const ['Show on dashboard', Icons.visibility_outlined, true]
      else
        const ['Hide from dashboard', Icons.visibility_off_outlined, true],
    ],
  );
  if (result == null || !context.mounted) return;
  switch (result) {
    case 'Log now':
      openLogSheet(context, t);
      break;
    case 'View history & insights':
      openDetail(context, t);
      break;
    case 'Change goal':
      openGoalSheet(context, t);
      break;
    case 'Pin to top':
      state.pinToTop(t.id);
      showTrackToast(context, '${t.name} pinned to top');
      break;
    case 'Hide from dashboard':
    case 'Show on dashboard':
      state.toggleHidden(t.id);
      showTrackToast(
        context,
        t.hidden ? '${t.name} hidden from Today — history kept' : '${t.name} shown on Today again',
      );
      break;
  }
}

/// Focus Lock on Today.
///
/// Three states and no invention between them: a session is running (show it, let
/// them back in), the user has history (offer the next session and the last one's
/// outcome), or there is nothing yet (explain the feature in one sentence and offer
/// to start). The card never reports blocking it cannot prove — that decision belongs
/// to `AppState.focusEnforcement`, which reads the platform.
class _FocusCard extends StatelessWidget {
  const _FocusCard();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    if (!app.hasFocusSupport) return const SizedBox.shrink();

    final live = app.activeFocusSession;
    final dark = Theme.of(context).brightness == Brightness.dark;

    if (live != null) {
      final enforcement = app.focusEnforcement;
      final accent = enforcement.tone == 'full'
          ? TrackTheme.green
          : enforcement.tone == 'danger'
          ? TrackTheme.red
          : enforcement.intendsToBlock
          ? TrackTheme.orange
          : TrackTheme.blue;
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Pressable(
          onTap: () => openFocusSession(context),
          scale: .985,
          child: Container(
            padding: const EdgeInsets.fromLTRB(15, 13, 15, 14),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: dark ? .2 : .12),
              borderRadius: BorderRadius.circular(TrackTheme.radiusCard),
              border: Border.all(color: accent.withValues(alpha: .35), width: .5),
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      live.isPaused ? 'PAUSED' : 'FOCUSING',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1, color: accent),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      focusCountdownLabel(app.focusRemainingMs),
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w300,
                        letterSpacing: -1,
                        color: TrackTheme.label(dark),
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        live.goalLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: TrackTheme.label(dark)),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        live.isPaused ? 'Paused' : enforcement.label,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: accent),
                      ),
                      Text(
                        live.isPaused
                            ? 'Apps are available until you resume.'
                            : enforcement.intendsToBlock && !enforcement.isConfirmed
                            ? enforcement.detail
                            : enforcement.isConfirmed && live.blockedPackages.isNotEmpty
                            ? '${live.mode.label} · coverage verified · ${live.blockedPackages.length} app'
                                  '${live.blockedPackages.length == 1 ? '' : 's'} selected'
                            : live.blockedPackages.isEmpty
                            ? live.mode.label
                            : '${live.mode.label} · ${live.blockedPackages.length} app'
                                  '${live.blockedPackages.length == 1 ? '' : 's'} selected',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                          color: TrackTheme.label2(dark),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded, size: 20, color: accent),
              ],
            ),
          ),
        ),
      );
    }

    final last = app.focusHistory.isEmpty ? null : app.focusHistory.first;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(15, 13, 15, 14),
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
                const Icon(Icons.timer_outlined, size: 19, color: TrackTheme.orange),
                const SizedBox(width: 8),
                Text(
                  'Focus',
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.25,
                    color: TrackTheme.label(dark),
                  ),
                ),
                const Spacer(),
                if (app.focusTodayMinutes > 0)
                  Text(
                    '${app.focusTodayMinutes} min today',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: TrackTheme.label3(dark)),
                  ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              last == null
                  ? 'A timer, or a session that keeps the apps you choose out of reach.'
                  : 'Last session: ${last.goalLabel} · ${focusDurationLabel(last.focusMs)}'
                        '${last.outcome == null ? '' : ' · ${last.outcome!.label.toLowerCase()}'}',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.45,
                fontWeight: FontWeight.w500,
                color: TrackTheme.label2(dark),
              ),
            ),
            const SizedBox(height: 11),
            Row(
              children: [
                Expanded(
                  child: TrackFilledButton(
                    label: app.focusTodayMinutes > 0 ? 'Focus again' : 'Start a focus session',
                    color: TrackTheme.indigo,
                    onTap: () => showFocusStartSheet(context),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 104,
                  child: TrackTintedButton(
                    label: 'History',
                    color: TrackTheme.indigo,
                    onTap: () =>
                        Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const FocusHistoryScreen())),
                  ),
                ),
              ],
            ),
            if (!app.focusPlatformAvailable) ...[
              const SizedBox(height: 8),
              Text(
                'Sessions will time and record here, but this device cannot cover apps.',
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                  color: TrackTheme.label3(dark),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
