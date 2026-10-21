import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/pro_config.dart';
import '../data/focus_engine.dart';
import '../main.dart' show Pressable, TrackTheme;
import '../models/focus_models.dart';
import '../state/app_state.dart';
import '../util/format.dart';
import '../widgets/glass.dart';
import '../widgets/large_title_header.dart';
import '../widgets/pro_gate.dart';
import 'focus_profiles_screen.dart';
import 'focus_screen.dart';
import 'focus_setup_sheets.dart';
import 'paywall_screen.dart';

/// Focus history: what actually happened, session by session.
///
/// The figures on this screen obey the same rule as the rest of the app: nothing is
/// averaged into meaninglessness, and nothing is shown before the sample supports it.
/// `FocusStats.minSessionsForShare` sessions are needed before a *share* is printed
/// (one clean session out of one is not a rate), and `minSessionsForPattern` before a
/// typical start time is claimed. Below those thresholds the screen says what it is
/// waiting for instead of printing a plausible-looking number.
///
/// Free keeps the last [ProConfig.freeFocusHistorySessions] sessions. That is a
/// reading limit, never a storage limit: every session is kept, exported and shown
/// again the moment the tier changes. (And the session that just finished is always
/// shown immediately to whoever ran it.)
IconData _historyModeIcon(FocusMode mode) => switch (mode) {
  FocusMode.standard => Icons.timer_outlined,
  FocusMode.blocking => Icons.block_outlined,
  FocusMode.deep => Icons.do_not_disturb_on_outlined,
};

class FocusHistoryScreen extends StatelessWidget {
  const FocusHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final dark = Theme.of(context).brightness == Brightness.dark;
    final stats = app.focusStats;
    final visible = app.visibleFocusHistory;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          AmbientBackground(accent: TrackTheme.indigo, accent2: TrackTheme.purple),
          CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
            slivers: [
              LargeTitleHeader(
                title: 'Focus history',
                subtitle: stats.endedSessions == 0
                    ? 'No sessions yet'
                    : '${stats.endedSessions} session${stats.endedSessions == 1 ? '' : 's'} · '
                          '${stats.minutesTotal} minutes recorded',
                leading: const TrackBackButton(),
                trailing: app.hasFocusSupport ? _HeaderAction(onTap: () => showFocusStartSheet(context)) : null,
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 60),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    if (!app.hasFocusSupport) ...[
                      const InsightCard(
                        emoji: 'timer',
                        title: 'Focus sessions are not available in this build.',
                        body:
                            'The timer, the goal and the reflection all live in the app, but this build has '
                            'no platform channel behind them, so no session can be started here.',
                        accent: TrackTheme.orange,
                        accent2: TrackTheme.yellow,
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: StatTile(value: '${stats.minutesLast7Days}', label: 'Min last 7 days'),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: StatTile(value: '${stats.cleanStreak}', label: 'Clean run'),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: StatTile(
                              value: stats.typicalStartMinute == null
                                  ? '—'
                                  : FocusEngine.clockLabel(stats.typicalStartMinute!),
                              label: 'Typical start',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _Interpretation(stats: stats, sessions: app.focusHistory),
                      const SizedBox(height: 4),
                      SectionLabel(
                        'Sessions',
                        trailing: _CountPill(count: visible.length, total: app.focusHistory.length),
                      ),
                      if (app.focusHistory.isEmpty)
                        const InsightCard(
                          emoji: 'focus',
                          title: 'Nothing to look back on yet.',
                          body:
                              'Start a session from Today or from inside a routine. When it ends, what '
                              'actually happened is recorded here — including the sessions that did not go '
                              'to plan, which are the interesting ones.',
                          accent: TrackTheme.blue,
                          accent2: TrackTheme.indigo,
                        )
                      else ...[
                        for (final session in visible) _SessionRow(session: session),
                        if (app.hiddenFocusSessions > 0)
                          ProLockedRow(
                            title:
                                '${app.hiddenFocusSessions} older session'
                                '${app.hiddenFocusSessions == 1 ? '' : 's'} kept, not hidden',
                            subtitle:
                                'Your history is stored in full — free shows the last '
                                '${ProConfig.freeFocusHistorySessions}. Pro reads the whole record and the '
                                'patterns in it.',
                            emoji: 'history',
                            accent: TrackTheme.indigo,
                            onTap: () => showPaywall(context, trigger: PaywallTrigger.focusAnalytics),
                          ),
                      ],
                      const SizedBox(height: 18),
                      GlassList(
                        children: [
                          GlassRow(
                            title: 'Profiles and schedules',
                            subtitle: 'Set a rule set up once, or put deep focus on a schedule',
                            leading: const Icon(Icons.settings_outlined, size: 18, color: TrackTheme.orange),
                            accent: TrackTheme.purple,
                            onTap: () => Navigator.of(
                              context,
                            ).push(MaterialPageRoute<void>(builder: (_) => const FocusProfilesScreen())),
                          ),
                          GlassRow(
                            title: 'How covering works, and where it stops',
                            subtitle: 'Permissions, limits, and what Track Pro cannot see',
                            leading: const Icon(Icons.security_outlined, size: 18, color: TrackTheme.orange),
                            accent: TrackTheme.orange,
                            onTap: () => openFocusPermissionSheet(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Time is measured from when the session started, so changing the phone\'s clock or '
                        'crossing a time zone cannot lengthen or shorten it. A session that was interrupted '
                        'by a restart or a lost permission is saved as interrupted, never as a completion.',
                        style: TextStyle(
                          fontSize: 11.8,
                          height: 1.5,
                          fontWeight: FontWeight.w500,
                          color: TrackTheme.label3(dark),
                        ),
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
}

/// The sentence under the figures — or the honest reason there isn't one.
class _Interpretation extends StatelessWidget {
  const _Interpretation({required this.stats, required this.sessions});

  final FocusStats stats;
  final List<FocusSession> sessions;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ended = stats.endedSessions;
    final String body;

    if (ended == 0) {
      body = 'Figures appear once there is something to compute them from.';
    } else if (ended < FocusStats.minSessionsForShare) {
      body =
          '${FocusStats.minSessionsForShare - ended} more finished '
          'session${FocusStats.minSessionsForShare - ended == 1 ? '' : 's'} before this screen will quote a '
          'clean rate. One clean session out of one is not a rate, so none is shown.';
    } else {
      // `cleanShare` and `servedShare` are already percentages, and both are null
      // below `minSessionsForShare`, which the branch above has ruled out.
      final share = stats.cleanShare;
      final served = stats.servedShare;
      body =
          '${share!.round()}% of your $ended finished sessions ran clean — the timer reached zero with '
          'enforcement intact throughout. ${served!.round()}% ran to the end of their timer at all; the rest '
          'were ended early or interrupted, and are stored exactly as they happened.';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
      decoration: BoxDecoration(
        color: TrackTheme.fill(dark),
        borderRadius: BorderRadius.circular(TrackTheme.radiusCard),
      ),
      child: Text(
        body,
        style: TextStyle(fontSize: 12.8, height: 1.5, fontWeight: FontWeight.w500, color: TrackTheme.label2(dark)),
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session});

  final FocusSession session;

  static Color _tone(String? tone) => switch (tone) {
    'full' => TrackTheme.green,
    'minimum' => TrackTheme.orange,
    'danger' => TrackTheme.red,
    _ => TrackTheme.blue,
  };

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final outcome = session.outcome;
    final accent = _tone(outcome?.tone);
    final live = session.isLive;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Pressable(
        onTap: () => showFocusSummary(context, session.id),
        scale: .99,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
          decoration: BoxDecoration(
            color: TrackTheme.surface(dark),
            borderRadius: BorderRadius.circular(TrackTheme.radiusCard),
            boxShadow: TrackTheme.cardShadow(dark),
            border: Border.all(
              color: dark ? Colors.white.withValues(alpha: .05) : Colors.black.withValues(alpha: .03),
              width: .5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_historyModeIcon(session.mode), size: 18, color: accent),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      session.goalLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -.25,
                        color: TrackTheme.label(dark),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: .16),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      live ? 'Running' : (outcome?.label ?? 'Unrecorded'),
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: .2, color: accent),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                '${shortDate(DateTime.fromMillisecondsSinceEpoch(session.startedAtWallMs))} · '
                '${focusDurationLabel(session.focusMs)} of ${focusDurationLabel(session.plannedMs)}'
                '${session.pausedMs > 0 ? ' · ${focusDurationLabel(session.pausedMs)} paused' : ''}',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: TrackTheme.label3(dark)),
              ),
              if (session.blockedPackages.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  session.enforcement.isConfirmed
                      ? 'Coverage verified · ${session.blockedPackages.length} app${session.blockedPackages.length == 1 ? '' : 's'} selected · '
                            '${session.overlayShows} panel launch${session.overlayShows == 1 ? '' : 'es'} accepted'
                      : '${session.blockedPackages.length} app${session.blockedPackages.length == 1 ? '' : 's'} selected · '
                            'enforcement not confirmed (${session.enforcement.label.toLowerCase()})',
                  style: TextStyle(fontSize: 11.8, fontWeight: FontWeight.w500, color: accent.withValues(alpha: .95)),
                ),
              ],
              if ((session.reflection ?? '').isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  '“${session.reflection}”',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    fontStyle: FontStyle.italic,
                    color: TrackTheme.label2(dark),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: TrackTheme.fill(dark),
          borderRadius: BorderRadius.circular(TrackTheme.radiusPill),
        ),
        child: Row(
          children: [
            const Icon(Icons.play_arrow_rounded, size: 16, color: TrackTheme.blue),
            const SizedBox(width: 6),
            Text(
              'Focus',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: TrackTheme.label(dark)),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.count, required this.total});

  final int count;
  final int total;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      count == total ? '$total' : '$count of $total',
      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: TrackTheme.label3(dark)),
    );
  }
}
