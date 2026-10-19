import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/pro_config.dart';
import '../data/default_trackers.dart';
import '../main.dart' show TrackTheme;
import '../models/models.dart';
import '../state/app_state.dart';
import '../util/format.dart';
import '../widgets/glass.dart';
import '../widgets/large_title_header.dart';
import '../widgets/pro_gate.dart';
import '../widgets/progress_ring.dart';
import 'detail_screen.dart';
import 'log_sheets.dart';
import 'paywall_screen.dart';

/// Tracker management: reorder, hide, show and add trackers.
///
/// "Hide" is the word everywhere in the UI (the switch, the long-press menu, the
/// toasts). The code and one toast used to call it retiring, which made the same
/// switch look like two different features.
/// Adding a tracker is the cheapest possible expansion of the user's lock-in.
class TrackersScreen extends StatelessWidget {
  const TrackersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final dark = Theme.of(context).brightness == Brightness.dark;
    final list = state.trackers.toList()..sort((a, b) => a.order.compareTo(b.order));

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
      slivers: [
        LargeTitleHeader(
          // This screen is never a tab (the tab bar is the habit loop), so it is always
          // reached by a push — and the way back belongs in its own header rather than in
          // a second bar stacked above it. That second bar was what Measurements rendered,
          // which left two titles and two back affordances on one screen.
          leading: const TrackBackButton(),
          title: 'Trackers',
          subtitle: state.isPro
              ? '${state.visibleTrackers.length} active · unlimited on Pro'
              : '${state.visibleTrackers.length} of ${ProConfig.freeTrackerLimit} free · unlimited on Pro',
          trailing: GestureDetector(
            onTap: state.toggleEditing,
            child: Padding(
              padding: const EdgeInsets.only(left: 8, right: 4),
              child: Text(state.editing ? 'Done' : 'Edit',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: TrackTheme.blue)),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 130),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              GlassList(children: [
                for (var i = 0; i < list.length; i++)
                  _TrackerRow(
                    tracker: list[i],
                    index: i,
                    total: list.length,
                    editing: state.editing,
                    values: state.historyOf(list[i].id),
                  ),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                // "Reorder / remove" is gone: the header's Edit toggle is the same action,
                // and two controls for one mode read as two different modes. Edit stays in
                // the header, where the Android editing action remains easy to reach.
                GestureDetector(
                  onTap: () => openGoalsSheet(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                    decoration: BoxDecoration(color: TrackTheme.fill(dark), borderRadius: BorderRadius.circular(11)),
                    child: Text('Goal settings',
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: TrackTheme.label(dark))),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  state.editing ? 'Editing · tap Done to finish' : 'Tap Edit to reorder or hide',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: TrackTheme.label3(dark)),
                ),
              ]),
              SectionLabel(
                'Add more · one app, ten more habits',
                trailing: state.isPro ? null : const ProChip(compact: true),
              ),
              if (!state.isPro) ...[
                ProUsageMeter(
                  used: state.visibleTrackers.length,
                  limit: ProConfig.freeTrackerLimit,
                  onUpgrade: () => showPaywall(context, trigger: PaywallTrigger.trackerLimit),
                ),
                const SizedBox(height: 12),
              ],
              GlassList(children: [
                for (final e in DefaultTrackers.addable)
                  GlassRow(
                    title: e.name,
                    subtitle: e.blurb,
                    leading: Icon(Icons.add_circle_outline_rounded, size: 18, color: Color(e.accent)),
                    accent: Color(e.accent),
                    showChevron: false,
                    onTap: () {
                      final app = context.read<AppState>();
                      // The free ceiling: adding beyond it is the single most
                      // honest moment to ask, because the user is mid-action and
                      // the value is concrete.
                      if (!app.canAddTracker() && !state.added.contains(e.id)) {
                        app.analytics?.log('pro_gate_tapped', {'gate': 'tracker_limit', 'target': e.id});
                        showPaywall(context, trigger: PaywallTrigger.trackerLimit);
                        return;
                      }
                      app.toggleAdded(e.id);
                      showTrackToast(
                        context,
                        state.added.contains(e.id) ? '${e.name} tracker added' : '${e.name} tracker removed',
                      );
                    },
                    trailing: state.added.contains(e.id)
                        ? Text('Added',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: TrackTheme.green))
                        : state.canAddTracker()
                            ? Text('Add',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: TrackTheme.blue))
                            : const Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.lock_outline_rounded, size: 14, color: ProPalette.goldDeep),
                                SizedBox(width: 5),
                                ProChip(compact: true),
                              ]),
                  ),
              ]),
              const SizedBox(height: 14),
              InsightCard(
                emoji: 'trackers',
                // Real counts and a real start date, or an honest "nothing yet".
                // The previous line, "1,284 entries … since 17 Sep.", was typed
                // into the source: every user saw the same invented history.
                title: state.entryCount == 0
                    ? 'Nothing logged yet — ${state.visibleTrackers.length} trackers ready'
                    : '${state.entryCount} ${state.entryCount == 1 ? 'entry' : 'entries'} across '
                        '${state.visibleTrackers.length} trackers'
                        '${state.trackingSince == null ? '' : ' since ${shortDate(state.trackingSince!)}'}',
                body: state.entryCount == 0
                    ? 'Log anything — a glass of water counts. Your history stays on this device, '
                        'and export is always free.'
                    : 'Your history lives here permanently — export it any time, and the longer you '
                        'track, the sharper the insights get.',
                accent: TrackTheme.blue,
                accent2: TrackTheme.indigo,
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

class _TrackerRow extends StatelessWidget {
  const _TrackerRow({
    required this.tracker,
    required this.index,
    required this.total,
    required this.editing,
    required this.values,
  });

  final Tracker tracker;
  final int index;
  final int total;
  final bool editing;
  final List<double> values;

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final dark = Theme.of(context).brightness == Brightness.dark;
    final v = values.isEmpty ? 0.0 : values.last;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
      child: Row(
        children: [
          TrackRecordIcon(label: tracker.name, color: tracker.accent, size: 29, iconSize: 16),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => openDetail(context, tracker),
              onLongPress: () => openGoalSheet(context, tracker),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tracker.name,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, letterSpacing: -.32, color: TrackTheme.label(dark))),
                  Text('${fmtGoalLong(tracker)} · ${fmtValue(tracker, v)} today · ${streakOf(tracker, values)}-day streak',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: TrackTheme.label3(dark))),
                ],
              ),
            ),
          ),
          if (editing)
            Row(children: [
              _RowBtn(icon: Icons.arrow_upward_rounded, enabled: index > 0, onTap: () => state.move(tracker.id, -1)),
              const SizedBox(width: 4),
              _RowBtn(icon: Icons.arrow_downward_rounded, enabled: index < total - 1, onTap: () => state.move(tracker.id, 1)),
              const SizedBox(width: 4),
              _RowBtn(
                icon: Icons.visibility_off_outlined,
                color: TrackTheme.red,
                onTap: () {
                  state.toggleHidden(tracker.id);
                  // The button toggles, so the message has to follow what happened
                  // rather than what the icon suggests. "retired — history kept" over a
                  // tracker that had just been *shown again* was one of three words this
                  // screen used for one state (hide / retire / dashboard).
                  showTrackToast(
                    context,
                    tracker.hidden
                        ? '${tracker.name} hidden from Today — history kept'
                        : '${tracker.name} shown on Today again',
                  );
                },
              ),
            ])
          else ...[
            ProgressRing(pct: ringPct(tracker, v), size: 30, stroke: 4, colorA: tracker.accent, colorB: tracker.accent2, duration: const Duration(milliseconds: 900)),
            const SizedBox(width: 8),
            _MiniSwitch(
              value: !tracker.hidden,
              onTap: () {
                if (tracker.hidden && !state.canAddTracker()) {
                  showPaywall(context, trigger: PaywallTrigger.trackerLimit);
                  return;
                }
                state.toggleHidden(tracker.id);
                showTrackToast(
                  context,
                  tracker.hidden
                      ? '${tracker.name} hidden from Today — history kept'
                      : '${tracker.name} shown on Today again',
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _RowBtn extends StatelessWidget {
  const _RowBtn({required this.icon, required this.onTap, this.enabled = true, this.color = TrackTheme.blue});

  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1 : .3,
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: TrackTheme.fill(dark), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 13, color: color),
        ),
      ),
    );
  }
}

class _MiniSwitch extends StatelessWidget {
  const _MiniSwitch({required this.value, required this.onTap});

  final bool value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: TrackTheme.easeOut,
        width: 51,
        height: 31,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: value ? TrackTheme.green : TrackTheme.fill(Theme.of(context).brightness == Brightness.dark),
          borderRadius: BorderRadius.circular(16),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 280),
          curve: TrackTheme.spring,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 27,
            height: 27,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(.15), blurRadius: 8, offset: const Offset(0, 3))],
            ),
          ),
        ),
      ),
    );
  }
}
