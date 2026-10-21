import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/pro_config.dart';
import '../data/insights_engine.dart';
import '../main.dart' show TrackTheme;
import '../models/models.dart';
import '../state/app_state.dart';
import '../util/format.dart';
import '../widgets/glass.dart';
import '../widgets/large_title_header.dart';
import '../widgets/ios_tab_bar.dart';
import '../widgets/mini_chart.dart';
import '../widgets/pro_gate.dart';
import 'paywall_screen.dart';

/// The retention engine: streaks, milestones, and cross-tracker patterns that
/// only exist because everything lives in one app.
class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final dark = Theme.of(context).brightness == Brightness.dark;
    // Keep the final card clear of both the floating tab bar and Android's
    // variable navigation inset; fixed-only padding caused the reported bottom
    // overflow on devices with a larger system gesture/navigation area.
    final requiredBottomPadding = IosTabBar.scrollClearance(context);
    final scrollBottomPadding = requiredBottomPadding > 130 ? requiredBottomPadding : 130.0;
    // Requested window from the segmented control; the series in memory is the
    // ceiling. `range` is already clamped to 'week' for free users by AppState, so
    // this cannot expose paid depth.
    final requested = switch (state.range) {
      'month' => 28,
      'quarter' => 90,
      _ => 7,
    };
    final available = state.loadedDays;
    final days = requested < available ? requested : available;
    final start = available - days;
    final scores = [for (var i = start; i < available; i++) activityScore(state.trackers, state.history, i)];
    final avgScore = scores.isEmpty ? 0.0 : scores.reduce((a, b) => a + b) / scores.length;

    // Cross-tracker chart input: only days where both mood and sleep were logged.
    // A missing day leaves a gap; it is never read as zero and never invented.
    final moodSleep = state.paired('mood', 'sleep', 14, (m, s) => m * 2 + s);

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
      slivers: [
        LargeTitleHeader(
          title: 'Insights',
          subtitle: state.entryCount == 0
              ? 'Nothing logged yet'
              : '${state.trackedDays} days tracked · ${state.entryCount} entries',
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(20, 4, 20, scrollBottomPadding),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _StreakCard(state: state),
              const SizedBox(height: 12),
              Row(
                children: [
                  // Every tile is a live SQL count. On a fresh install they read
                  // zero, which is the truth, not a placeholder.
                  Expanded(
                    child: StatTile(value: '${state.trackedDays}', label: 'Days tracked'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatTile(value: _count(state.entryCount), label: 'Entries total'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: StatTile(value: '${state.visibleTrackers.length}', label: 'Trackers live'),
                  ),
                ],
              ),
              SectionLabel(
                'Consistency',
                trailing: Text(
                  '${(avgScore * 100).round()}% avg',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: TrackTheme.label3(dark)),
                ),
              ),
              _RangeSegmented(state: state),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.fromLTRB(15, 16, 15, 12),
                decoration: BoxDecoration(
                  color: TrackTheme.surface(dark),
                  borderRadius: BorderRadius.circular(TrackTheme.radiusCard),
                  border: Border.all(color: TrackTheme.separator(dark), width: .5),
                ),
                child: Column(
                  children: [
                    MiniChart(values: scores, color: TrackTheme.indigo, height: 120, barRadius: 6, todayTint: false),
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '$days days ago',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: TrackTheme.label3(dark),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Today',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: TrackTheme.label3(dark),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SectionLabel('Last 7 days'),
              if (state.loggedDaysInWindow(7) == 0)
                GlassList(children: [_EmptyRow(text: 'No averages yet. Log a few days and they will appear here.')])
              else
                GlassList(
                  children: [
                    // One row per tracker that actually has data in the window.
                    for (final t in state.visibleTrackers)
                      if (state.series(t.id, 7).any((v) => v > 0))
                        _AvgRow(
                          label: t.name,
                          name: '${t.name} (7-day)',
                          color: t.accent,
                          value: _avgText(t, state.avg(t.id, 7)),
                        ),
                  ],
                ),
              SectionLabel('Patterns we found', trailing: state.isPro ? null : const ProChip(compact: true)),
              // Computed from the user's own rows by InsightsEngine. With too
              // little history this renders a progress line and stops — the app
              // does not fabricate a finding to fill the section.
              if (state.insights.isEmpty || state.insights.first.sampleDays == 0)
                _InsufficientData(trackedDays: state.trackedDays, needed: InsightsEngine.minLoggedDaysForPatterns)
              else ...[
                for (final i in state.insights.where((x) => !x.advanced).take(state.isPro ? 4 : 2))
                  InsightCard(
                    emoji: i.emoji,
                    title: i.title,
                    body: i.body,
                    accent: TrackTheme.indigo,
                    accent2: TrackTheme.purple,
                  ),
                if (!state.isPro)
                  ProGate(
                    locked: true,
                    title: 'Cross-tracker patterns',
                    body:
                        'Pro compares sleep, mood, spending and steps against each other, '
                        'and only where your own days support it.',
                    onUnlock: () {
                      state.analytics?.log('pro_gate_tapped', {'gate': 'insights_patterns'});
                      showPaywall(context, trigger: PaywallTrigger.insightsLock);
                    },
                    child: Column(
                      children: [
                        for (final i in state.insights.where((x) => x.advanced).take(3))
                          InsightCard(
                            emoji: i.emoji,
                            title: i.title,
                            body: i.body,
                            accent: TrackTheme.indigo,
                            accent2: TrackTheme.purple,
                          ),
                      ],
                    ),
                  )
                else
                  for (final i in state.insights.where((x) => x.advanced).take(5))
                    InsightCard(
                      emoji: i.emoji,
                      title: i.title,
                      body: i.body,
                      accent: TrackTheme.indigo,
                      accent2: TrackTheme.purple,
                    ),
              ],
              const SectionLabel('Mood vs sleep'),
              if (moodSleep.length < 4)
                GlassList(
                  children: [
                    _EmptyRow(
                      text:
                          'Log sleep and mood on at least 4 days to see them together. '
                          'So far there ${moodSleep.length == 1 ? 'is 1 day' : 'are ${moodSleep.length} days'}.',
                    ),
                  ],
                )
              else if (state.isPro)
                _MoodSleepChart(points: moodSleep, dark: dark)
              else
                ProGate(
                  locked: true,
                  title: 'Sleep and mood, day by day',
                  body:
                      'How your sleep and mood moved together across the ${moodSleep.length} days you logged both. '
                      'Pro unlocks every cross-tracker chart.',
                  onUnlock: () {
                    state.analytics?.log('pro_gate_tapped', {'gate': 'correlation'});
                    showPaywall(context, trigger: PaywallTrigger.insightsLock);
                  },
                  child: _MoodSleepChart(points: moodSleep, dark: dark, flat: true),
                ),
              const SectionLabel('Milestones'),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final b in Milestones.compute(
                    trackedDays: state.trackedDays,
                    bestStreak: state.bestStreak,
                    entryCount: state.entryCount,
                    cycleCount: state.cycle.cycleCount,
                    hasHealthData: state.healthSyncedDays > 0,
                  ))
                    Opacity(
                      opacity: b.unlocked ? 1 : .45,
                      child: SizedBox(
                        // The content already has 20px gutters on both sides and
                        // 10px gaps between three cards. Account for both so this
                        // row cannot overrun on narrow Android devices.
                        width: (MediaQuery.sizeOf(context).width - 40 - 20) / 3,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                          decoration: BoxDecoration(
                            color: TrackTheme.surface(dark),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: TrackTheme.cardShadow(dark),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                b.unlocked ? Icons.workspace_premium_outlined : Icons.lock_outline_rounded,
                                size: 24,
                                color: b.unlocked ? TrackTheme.orange : TrackTheme.label3(dark),
                              ),
                              const SizedBox(height: 7),
                              Text(
                                b.title,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -.1,
                                  color: TrackTheme.label(dark),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                b.subtitle,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w500,
                                  color: TrackTheme.label3(dark),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              InsightCard(
                emoji: 'trend',
                title: state.bestStreak > 0
                    ? 'Your longest current streak is ${state.bestStreak} days.'
                    : 'No streak running yet — log today to start one.',
                body: state.trackedDays == 0
                    ? 'Nothing logged yet, so there is no streak to count.'
                    : 'Counted from ${state.trackedDays} days you logged.',
                accent: TrackTheme.green,
                accent2: TrackTheme.mint,
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

/// Groups thousands so an entry count stays readable without pulling in intl.
String _count(int n) {
  final s = n.toString();
  if (s.length <= 3) return s;
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

/// Shown instead of patterns when the history cannot support any.
///
/// This is the honest state the product needs: it tells the user exactly what is
/// missing and how long it takes, rather than showing a plausible-looking
/// correlation computed from four days.
class _InsufficientData extends StatelessWidget {
  const _InsufficientData({required this.trackedDays, required this.needed});

  final int trackedDays;
  final int needed;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final remaining = needed - trackedDays;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
      decoration: BoxDecoration(
        color: TrackTheme.surface(dark),
        borderRadius: BorderRadius.circular(TrackTheme.radiusCard),
        boxShadow: TrackTheme.cardShadow(dark),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.science_outlined, size: 21, color: TrackTheme.orange),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trackedDays == 0 ? 'No patterns yet — no data' : '$remaining more logged days needed',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -.2,
                    color: TrackTheme.label(dark),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Patterns appear after about $needed days of your own history.',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                    color: TrackTheme.label2(dark),
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

class _RangeSegmented extends StatelessWidget {
  const _RangeSegmented({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    // 90 days is the Pro range: it needs the deep history that Pro unlocks, so
    // offering it to free users would be a broken promise anyway.
    final options = [
      ['week', 'Week'],
      ['month', 'Month'],
      ['quarter', '90 days'],
    ];
    // Month and 90 days are Pro windows: tapping them for a free user opens the
    // paywall instead of quietly drawing 28 days of history that free should not
    // see. The lock glyph warns before the tap, so it never feels like a trap.
    const lockedRanges = {'month': 'range_month', 'quarter': 'range_quarter'};
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(color: TrackTheme.fill(dark), borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          for (final o in options)
            Expanded(
              child: GestureDetector(
                onTap: () {
                  final gate = lockedRanges[o[0]];
                  if (gate != null && !state.isPro) {
                    state.analytics?.log('pro_gate_tapped', {'gate': gate});
                    showPaywall(context, trigger: PaywallTrigger.insightsLock);
                    return;
                  }
                  state.setRange(o[0]);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: TrackTheme.easeOut,
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: BoxDecoration(
                    color: state.range == o[0] ? TrackTheme.surface(dark) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: state.range == o[0]
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: .12),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  // Keep each third of the control independently bounded. A
                  // lock beside a scaled "90 days" label used to overflow on
                  // narrow Android devices; the icon now sits in its own slot
                  // and the label can grow to two centered lines.
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: lockedRanges.containsKey(o[0]) && !state.isPro ? 14 : 5,
                        ),
                        child: Text(
                          o[1],
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.15,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -.1,
                            color: TrackTheme.label(dark),
                          ),
                        ),
                      ),
                      if (lockedRanges.containsKey(o[0]) && !state.isPro)
                        Positioned(left: 5, child: Icon(Icons.lock, size: 10, color: TrackTheme.label3(dark))),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: TrackTheme.surface(Theme.of(context).brightness == Brightness.dark),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: TrackTheme.separator(Theme.of(context).brightness == Brightness.dark), width: .5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${state.bestStreak}',
            style: const TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.w700,
              letterSpacing: -1.6,
              height: 1,
              color: TrackTheme.orange,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            state.bestStreak == 0
                ? 'No streak running. Log anything today and this starts at 1.'
                : 'day streak on your most consistent tracker. '
                      '${state.loggedFlags(7).last ? 'Today is logged.' : 'Log today to extend it.'}',
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w500,
              color: TrackTheme.label2(Theme.of(context).brightness == Brightness.dark),
            ),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              // One dot per day, filled only where something was actually logged.
              for (final logged in state.loggedFlags(state.days))
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 3),
                    child: Container(
                      height: 11,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: logged
                            ? TrackTheme.orange
                            : TrackTheme.fill(Theme.of(context).brightness == Brightness.dark),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Shown where a chart or average would be, when there is nothing honest to put
/// there yet.
class _EmptyRow extends StatelessWidget {
  const _EmptyRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      child: Text(
        text,
        style: TextStyle(fontSize: 13, height: 1.4, fontWeight: FontWeight.w500, color: TrackTheme.label2(dark)),
      ),
    );
  }
}

String _avgText(Tracker t, double v) => switch (t.kind) {
  MetricKind.volume => '${(v / 1000).toStringAsFixed(1)} L',
  MetricKind.money => '₹${v.round()}',
  MetricKind.hours => '${v.toStringAsFixed(1)} h',
  MetricKind.weight => '${v.toStringAsFixed(1)} kg',
  MetricKind.mood => '${v.toStringAsFixed(1)} / 5',
  MetricKind.minutes => '${v.round()} min',
  _ => '${v.round()}',
};

class _AvgRow extends StatelessWidget {
  const _AvgRow({required this.label, required this.name, required this.color, required this.value});

  final String label;
  final String name;
  final Color color;
  final String value;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return GlassRow(
      title: name,
      leading: Icon(_insightAverageIcon(label), size: 17, color: color),
      accent: color,
      showChevron: false,
      trailing: Text(
        value,
        style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w500, color: TrackTheme.label2(dark)),
      ),
    );
  }
}

IconData _insightAverageIcon(String label) {
  final value = label.toLowerCase();
  if (value.contains('water')) return Icons.water_drop_outlined;
  if (value.contains('mood')) return Icons.sentiment_satisfied_alt_outlined;
  if (value.contains('sleep')) return Icons.bedtime_outlined;
  if (value.contains('step')) return Icons.directions_walk_outlined;
  if (value.contains('screen')) return Icons.phone_android_outlined;
  if (value.contains('weight')) return Icons.monitor_weight_outlined;
  return Icons.bar_chart_rounded;
}

/// One composite line: mood (scaled) plus sleep hours, drawn only over days that
/// have both. The legend says what the number is, so nobody reads it as two
/// separate series.
class _MoodSleepChart extends StatelessWidget {
  const _MoodSleepChart({required this.points, required this.dark, this.flat = false});

  final List<double> points;
  final bool dark;
  final bool flat;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 16, 15, 12),
      decoration: BoxDecoration(
        color: TrackTheme.surface(dark),
        borderRadius: BorderRadius.circular(TrackTheme.radiusCard),
        boxShadow: flat ? null : TrackTheme.cardShadow(dark),
        border: flat
            ? null
            : Border.all(
                color: dark ? Colors.white.withValues(alpha: .05) : Colors.black.withValues(alpha: .03),
                width: .5,
              ),
      ),
      child: Column(
        children: [
          TrendLine(values: points, colorA: TrackTheme.orange, colorB: TrackTheme.indigo),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'mood ×2 + sleep h',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: TrackTheme.orange),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${points.length} paired day${points.length == 1 ? '' : 's'}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: TrackTheme.label3(dark)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
