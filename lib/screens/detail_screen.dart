import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/pro_config.dart';
import '../data/entry_repository.dart';
import '../main.dart' show TrackTheme;
import '../widgets/glass.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../util/day_key.dart';
import '../util/format.dart';
import '../widgets/large_title_header.dart';
import '../widgets/mini_chart.dart';
import '../widgets/pro_gate.dart';
import 'paywall_screen.dart';
import '../widgets/progress_ring.dart';
import 'log_sheets.dart';
// `showTrackDialog` is defined in settings_screen.dart; importing the screen for
// one shared dialog helper is uglier than a widgets/ home, but it keeps this
// change small. (A follow-up should move both dialog helpers to widgets/.)
import 'settings_screen.dart';

Future<void> openDetail(BuildContext context, Tracker t) {
  return Navigator.of(context).push(
    CupertinoPageRoute<void>(
      builder: (_) => DetailScreen(trackerId: t.id),
      title: t.name,
    ),
  );
}

/// Tap-to-expand view for a single tracker: big ring, 28-day context, the
/// tracker-specific breakdown, history and a personal insight.
class DetailScreen extends StatelessWidget {
  const DetailScreen({super.key, required this.trackerId});

  final String trackerId;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final t = state.byId(trackerId);
    // `historyOf` returns an empty list for a tracker the projection does not carry.
    // The previous `history[trackerId]!` threw on exactly that case, and the four
    // screens that used the pattern shared the bug: a tracker added from a widget or a
    // restored database could take the screen down before anything opened.
    final hist = state.historyOf(trackerId);
    final v = hist.isEmpty ? 0.0 : hist.last;
    final pct = ringPct(t, v);
    final week = state.week(trackerId);
    final d = deltaOf(t, hist);
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          AmbientBackground(accent: t.accent, accent2: t.accent2),
          CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              LargeTitleHeader(
                title: '${t.emoji} ${t.name}',
                subtitle: '${t.blurb} · goal ${fmtGoalLong(t)}',
                leading: _BackButton(onTap: () => Navigator.of(context).maybePop()),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 60),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    Center(
                      child: ProgressRing(
                        pct: pct,
                        size: 186,
                        stroke: 17,
                        colorA: t.accent,
                        colorB: t.accent2,
                        center: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(fmtValue(t, v),
                                style: TextStyle(
                                    fontSize: 40, fontWeight: FontWeight.w700, letterSpacing: -1.6, color: TrackTheme.label(dark))),
                            const SizedBox(height: 4),
                            Text('${(pct * 100).round()}% of ${fmtGoalLong(t)}',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: TrackTheme.label3(dark))),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: TrackFilledButton(
                            label: '＋ Log today',
                            color: t.accent,
                            onTap: () => openLogSheet(context, t),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 108,
                          child: TrackTintedButton(label: 'Goal', color: t.accent, onTap: () => openGoalSheet(context, t)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(child: StatTile(value: _avgText(t, state.avg(trackerId, 7)), label: '7-day avg')),
                        const SizedBox(width: 10),
                        Expanded(child: StatTile(value: '${state.streak(trackerId)} days', label: 'Streak')),
                        const SizedBox(width: 10),
                        Expanded(child: StatTile(value: _avgText(t, state.best(trackerId)), label: 'Best 28d')),
                      ],
                    ),
                    SectionLabel(
                      'This week',
                      trailing: Text(
                        '${d.direction > 0 ? '▲' : d.direction < 0 ? '▼' : ''} ${d.text}',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: d.goodness > 0 ? TrackTheme.green : d.goodness < 0 ? TrackTheme.orange : TrackTheme.label3(dark),
                        ),
                      ),
                    ),
                    _Card(
                      child: Column(
                        children: [
                          MiniChart(values: week, color: t.accent, height: 120, barRadius: 6),
                          const SizedBox(height: 9),
                          Row(
                            children: [
                              for (var i = 0; i < week.length; i++)
                                Expanded(
                                  child: Center(
                                    child: Text(
                                      weekdayShort(DateTime.now().subtract(Duration(days: 6 - i))),
                                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: TrackTheme.label3(dark)),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    ..._extra(context, state, t),
                    SectionLabel(
                      'History',
                      trailing: state.isPro
                          ? Text('${state.historyWindow} days',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: TrackTheme.label3(dark)))
                          : const ProChip(compact: true),
                    ),
                    _HistorySection(
                      tracker: t,
                      // Free sees the last 7 days — the window that carries the habit.
                      // Pro sees everything back to the first logged day.
                      limit: state.isPro ? state.historyWindow : ProConfig.freeHistoryDays,
                      isPro: state.isPro,
                      onLockedTap: () {
                        state.analytics?.log('pro_gate_tapped', {'gate': 'history', 'tracker': t.id});
                        showPaywall(context, trigger: PaywallTrigger.historyLock);
                      },
                    ),
                    const SizedBox(height: 12),
                    InsightCard(
                      emoji: '✨',
                      title: t.insight,
                      // The count is the number of days with something logged, not
                      // the size of the window: "built from 90 days of your own
                      // data" on a one-day-old install is a fabrication.
                      body: switch (state.loggedDaysInWindow(state.days)) {
                        0 => 'Nothing logged against this tracker yet, so there is nothing to read into. '
                            'The line above is what it measures.',
                        1 => 'Built from 1 logged day — the longer you log, the sharper this gets.',
                        final logged => 'Built from $logged logged days — the longer you log, the sharper this gets.',
                      },
                      accent: t.accent,
                      accent2: t.accent2,
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _avgText(Tracker t, double v) {
    switch (t.kind) {
      case MetricKind.volume:
        return '${(v / 1000).toStringAsFixed(1)}L';
      case MetricKind.money:
        return '₹${v.round()}';
      case MetricKind.minutes:
        return fmtValue(t, v);
      case MetricKind.hours:
        return '${v.toStringAsFixed(1)}h';
      case MetricKind.weight:
        return '${v.toStringAsFixed(1)}kg';
      case MetricKind.mood:
        return v.toStringAsFixed(1);
      default:
        return v.round().toString();
    }
  }

  /// Per-tracker breakdown, computed from stored rows.
  ///
  /// Rules for everything in here:
  /// - a bar exists only if the underlying row exists;
  /// - an empty section renders [_NoData] naming what is missing and how it gets
  ///   filled, rather than a plausible-looking chart;
  /// - percentages and streaks are recomputed from history, never stored.
  List<Widget> _extra(BuildContext context, AppState state, Tracker t) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    switch (t.id) {
      case 'water':
        return [
          const SectionLabel('When you drink'),
          _RhythmList(state: state, tracker: t, buckets: 6, bucketHours: 3),
        ];

      case 'mood':
        final moodHistory = state.historyOf('mood');
        // Only the days the user actually rated: a zero in the cache means "not
        // logged", and counting those would invent a mood of zero.
        final logged = <double>[for (final m in moodHistory) if (m > 0) m];
        return [
          SectionLabel(
            state.isPro ? '5-week heatmap' : 'This week\'s heatmap',
            trailing: state.isPro ? null : const ProChip(compact: true),
          ),
          _Card(
            child: Column(
              children: [
                Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  children: [
                    for (final m in moodHistory.reversed.take(state.isPro ? 35 : state.historyWindow).toList().reversed)
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(5),
                          // A blank square means "not logged", which is why it is
                          // neutral grey and not the palest mood colour.
                          color: m == 0 ? TrackTheme.fill(dark) : t.accent.withOpacity((.35 + m * .13).clamp(0.0, 1.0)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(state.isPro ? '5 weeks ago' : '${state.historyWindow} days ago',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: TrackTheme.label3(dark))),
                    Text('Today', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: TrackTheme.label3(dark))),
                  ],
                ),
                const SizedBox(height: 6),
                Text('Grey squares are days you did not log — they are not low moods.',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: TrackTheme.label3(dark))),
              ],
            ),
          ),
          if (!state.isPro) ...[
            const SizedBox(height: 10),
            ProCtaButton(
              label: 'Unlock 5 weeks of mood',
              onTap: () {
                state.analytics?.log('pro_gate_tapped', {'gate': 'mood_heatmap'});
                showPaywall(context, trigger: PaywallTrigger.historyLock);
              },
            ),
          ],
          const SectionLabel('Distribution'),
          if (logged.isEmpty)
            const _NoData(
              emoji: '😊',
              title: 'No mood logged yet',
              body: 'Tap a face on the Today screen. After a week this becomes a distribution of your own days.',
            )
          else
            GlassList(children: [
              for (final row in const [
                ['😄 Great', 5],
                ['🙂 Good', 4],
                ['😐 Okay', 3],
                ['🙁 Low', 2],
                ['😖 Awful', 1],
              ])
                _Bar(
                  label: row[0] as String,
                  value: logged.where((m) => m.round() == row[1]).length,
                  max: logged.length,
                  color: t.accent,
                  suffix: 'days',
                ),
            ]),
        ];

      case 'expenses':
        final maxSpend = state.categories.isEmpty
            ? 1
            : state.categories.map((c) => c.amount).reduce((a, b) => a > b ? a : b).round();
        return [
          const SectionLabel('This week by category'),
          if (state.categories.isEmpty)
            const _NoData(
              emoji: '🧾',
              title: 'No spending logged yet',
              body: 'Add an expense and the category breakdown builds itself — this chart is a GROUP BY on your own entries.',
            )
          else
            GlassList(children: [
              for (final c in state.categories)
                _Bar(label: c.name, value: c.amount.round(), max: maxSpend, color: c.color, money: true, width: 104),
            ]),
          const SectionLabel('Recent'),
          if (state.transactions.isEmpty)
            const _NoData(emoji: '📭', title: 'Nothing here yet', body: 'Your logged expenses will appear in this list, newest first.')
          else
            GlassList(children: [
              for (final x in state.transactions.take(5))
                GlassRow(
                  title: x.title,
                  subtitle: '${x.category} · ${x.when}',
                  leading: const Text('🧾', style: TextStyle(fontSize: 15)),
                  accent: TrackTheme.green,
                  showChevron: false,
                  trailing: Text('₹${x.amount.round()}',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: TrackTheme.label2(dark))),
                ),
            ]),
        ];

      case 'sleep':
        final sleepLogged = [for (final v in state.historyOf('sleep')) if (v > 0) v];
        final nightsBelow = sleepLogged.where((v) => v < state.byId('sleep').goal * .85).length;
        return [
          const SectionLabel('Last 7 nights'),
          if (sleepLogged.isEmpty)
            const _NoData(
              emoji: '😴',
              title: 'No nights logged',
              body: 'Log hours slept, or connect Health Connect in Settings and this fills in from your phone or watch.',
            )
          else ...[
            _Card(
              child: MiniChart(values: state.week('sleep'), color: t.accent, height: 110, barRadius: 5),
            ),
            GlassList(children: [
              _Bar(
                label: 'Nights at goal',
                value: state.week('sleep').where((v) => v >= t.goal * .95).length,
                max: 7,
                color: TrackTheme.green,
                suffix: 'of 7',
              ),
              _Bar(
                label: 'Nights under ${(t.goal * .85).toStringAsFixed(1)}h',
                value: nightsBelow,
                max: sleepLogged.length,
                color: TrackTheme.orange,
                suffix: 'total',
              ),
            ]),
          ],
        ];

      case 'habits':
        final doneToday = state.habits.where((h) => h.done).length;
        return [
          SectionLabel('Today\'s checklist',
              trailing: Text('$doneToday/${state.habits.length}',
                  style: TextStyle(fontSize: 13, color: TrackTheme.label3(dark)))),
          if (state.habits.isEmpty)
            const _NoData(
              emoji: '✅',
              title: 'No habits yet',
              body: 'Add a habit and it gets its own streak, counted from the days you actually tick it.',
            )
          else
            GlassList(children: [
              for (var i = 0; i < state.habits.length; i++)
                GlassRow(
                  title: state.habits[i].name,
                  // Real streak, and a 30-day rate computed from the stored
                  // checklist rather than derived from the streak.
                  subtitle: '🔥 ${state.habits[i].streak}-day streak · '
                      '${state.habitRate(i, 30)}% of the last 30 days',
                  leading: Text(state.habits[i].emoji, style: const TextStyle(fontSize: 15)),
                  accent: state.habits[i].color,
                  showChevron: false,
                  trailing: Icon(
                    state.habits[i].done ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.circle,
                    color: state.habits[i].done ? TrackTheme.green : TrackTheme.label3(dark),
                  ),
                  onTap: () => state.toggleHabit(i),
                ),
            ]),
        ];

      case 'calories':
        final entries = state.foodEntries;
        return [
          const SectionLabel('Logged today'),
          if (entries.isEmpty)
            const _NoData(
              emoji: '🍽️',
              title: 'Nothing eaten yet today',
              body: 'Use quick-add or type a number. The day total is the sum of what you logged — nothing is estimated for you.',
            )
          else
            GlassList(children: [
              for (final f in entries.take(6))
                GlassRow(
                  title: f.title,
                  subtitle: '${f.when} · ${f.source == 'manual' ? 'added by you' : f.source}',
                  leading: Text(f.emoji, style: const TextStyle(fontSize: 15)),
                  accent: TrackTheme.orange,
                  showChevron: false,
                  trailing: Text('${f.kcal.round()} kcal',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: TrackTheme.label2(dark))),
                ),
            ]),
          const SectionLabel('7-day intake'),
          if ([for (final v in state.week('calories')) if (v > 0) v].isEmpty)
            const _NoData(emoji: '🔥', title: 'No intake to chart', body: 'Log a meal and this becomes your real weekly intake.')
          else
            _Card(child: MiniChart(values: state.week('calories'), color: t.accent, height: 110, barRadius: 5)),
        ];

      case 'steps':
        final steps7 = [for (final v in state.week('steps')) if (v > 0) v];
        return [
          const SectionLabel('This week'),
          if (steps7.isEmpty)
            const _NoData(
              emoji: '👣',
              title: 'No step data',
              body: 'Android does not let an app read step counts on its own. Connect Health Connect in Settings, '
                  'or log a number by hand — both land in the same history.',
            )
          else
            _Card(child: MiniChart(values: state.week('steps'), color: t.accent, height: 110, barRadius: 5)),
          const SectionLabel('Summary'),
          Row(children: [
            Expanded(child: StatTile(value: '${state.avg('steps', 7).round()}', label: '7-day avg')),
            const SizedBox(width: 10),
            Expanded(child: StatTile(value: '${state.best('steps').round()}', label: 'Best day')),
            const SizedBox(width: 10),
            Expanded(
              child: StatTile(
                value: '${(state.week('steps').where((v) => v >= t.goal).length)}',
                label: 'Days at goal',
              ),
            ),
          ]),
          // Distance and active calories are deliberately absent: converting
          // steps to calories needs a weight and a stride model, and Health
          // Connect already reports those separately. Showing a made-up number
          // here would be worse than showing none.
        ];

      case 'period':
        final cycle = state.cycle;
        return [
          const SectionLabel('Cycle'),
          if (!cycle.hasAnyData)
            const _NoData(
              emoji: '🌸',
              title: 'No period logged yet',
              body: 'Log the first day of your period. Predictions only appear once you have two cycles to measure — '
                  'before that, any date would be invented.',
            )
          else ...[
            Row(children: [
              Expanded(child: StatTile(value: cycle.hasPrediction ? '${cycle.averageLength.round()}' : '—', label: 'Avg cycle')),
              const SizedBox(width: 10),
              Expanded(
                child: StatTile(
                  value: cycle.periodLengthAvg > 0 ? cycle.periodLengthAvg.toStringAsFixed(1) : '—',
                  label: 'Avg period',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatTile(
                  value: cycle.hasPrediction ? (cycle.isIrregular ? 'varies' : 'steady') : '—',
                  label: 'Regularity',
                ),
              ),
            ]),
            const SizedBox(height: 12),
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(cycle.summary,
                      style: TextStyle(fontSize: 13.5, height: 1.45, fontWeight: FontWeight.w500, color: TrackTheme.label2(dark))),
                  if (cycle.nextWindow != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Next period likely ${_dayLabel(cycle.nextWindow!.$1)} – ${_dayLabel(cycle.nextWindow!.$2)}'
                      '${cycle.variability > 1 ? ' (±${cycle.variability} days in your data)' : ''}',
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: TrackTheme.label(dark)),
                    ),
                    const SizedBox(height: 4),
                    Text('An estimate from your own logged starts, not medical advice or birth control.',
                        style: TextStyle(fontSize: 11.5, height: 1.4, fontWeight: FontWeight.w500, color: TrackTheme.label3(dark))),
                  ],
                ],
              ),
            ),
            if (cycle.starts.length > 1) ...[
              const SectionLabel('Cycle history'),
              GlassList(children: [
                for (var i = cycle.starts.length - 1; i >= 0; i--)
                  GlassRow(
                    title: _dayLabel(cycle.starts[i], withYear: true),
                    subtitle: i == 0
                        ? 'First logged cycle'
                        : '${cycle.starts[i] - cycle.starts[i - 1]}-day cycle',
                    leading: const Text('🌸', style: TextStyle(fontSize: 15)),
                    accent: t.accent,
                    showChevron: false,
                    trailing: Text(i == cycle.starts.length - 1 ? 'latest' : '',
                        style: TextStyle(fontSize: 13, color: TrackTheme.label3(dark))),
                  ),
              ]),
            ],
          ],
        ];

      case 'screen':
        final hasScreenData = [for (final v in state.historyOf('screen')) if (v > 0)].isNotEmpty;
        return [
          const SectionLabel('Today by app'),
          // Per-app screen time requires Android's Usage Access, which this build
          // does not request. Rather than print a plausible app list, the section
          // states the limitation.
          const _NoData(
            emoji: '📱',
            title: 'Per-app breakdown is unavailable',
            body: 'Reading which apps you use needs Android Usage Access, which Track Pro does not request. '
                'The daily total you log is real and charted above.',
          ),
          if (hasScreenData) ...[
            const SectionLabel('7-day screen time'),
            _Card(child: MiniChart(values: state.week('screen'), color: t.accent, height: 110, barRadius: 5)),
          ],
        ];

      case 'weight':
      default:
        final full = state.historyOf('weight');
        // Free draws the same chart over the free window only. The line is the
        // Pro axis here (history), so the *values* are never hidden — the depth is.
        // Through `series()`: on a shorter-than-expected cache the free window is
        // simply shorter, instead of a RangeError out of `sublist`.
        final series = state.isPro ? full : state.series('weight', ProConfig.freeHistoryDays);
        final weights = [for (final v in series) if (v > 0) v];
        final change = weights.length >= 2 ? weights.last - weights.first : null;
        final firstIndex = series.indexWhere((v) => v > 0);
        final spanDays = firstIndex < 0 ? 0 : series.length - 1 - firstIndex;
        return [
          SectionLabel(
            state.isPro
                ? (change == null ? 'Trend' : 'Trend over ${weights.length} weigh-ins')
                : 'Last ${ProConfig.freeHistoryDays} days',
            trailing: change == null
                ? null
                : Text(
                    '${change <= 0 ? '▼' : '▲'} ${change.abs().toStringAsFixed(1)} kg in $spanDays days',
                    style: TextStyle(fontSize: 12.5, color: change <= 0 ? TrackTheme.green : TrackTheme.orange),
                  ),
          ),
          if (weights.isEmpty)
            const _NoData(
              emoji: '⚖️',
              title: 'No weigh-ins yet',
              body: 'Weight moves daily, so this chart is built from the days you actually logged — '
                  'and it will not draw a line through the gaps.',
            )
          else
            _Card(
              child: TrendLine(values: series, colorA: t.accent, colorB: t.accent2),
            ),
          if (!state.isPro)
            ProLockedRow(
              title: 'Trends need history',
              subtitle: 'Every weigh-in you have ever logged, drawn end to end',
              emoji: '📈',
              accent: t.accent,
              onTap: () {
                state.analytics?.log('pro_gate_tapped', {'gate': 'weight_trend'});
                showPaywall(context, trigger: PaywallTrigger.historyLock);
              },
            ),
          const SectionLabel('Latest'),
          Row(children: [
            Expanded(
              child: StatTile(
                value: weights.isEmpty ? '—' : weights.last.toStringAsFixed(1),
                label: 'Latest (kg)',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatTile(
                value: change == null ? '—' : '${change <= 0 ? '−' : '+'}${change.abs().toStringAsFixed(1)}',
                label: 'Change (kg)',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                // BMI needs a height. It is not invented — and now the tile that
                // says "set height" is the thing that lets you set it, instead of
                // pointing at a setting that did not exist anywhere in the app.
                onTap: () => _promptHeight(context, state),
                child: StatTile(
                  value: state.bmi?.toStringAsFixed(1) ?? '—',
                  label: state.bmi == null ? 'BMI · tap to set height' : 'BMI',
                ),
              ),
            ),
          ]),
        ];
    }
  }

  /// Cycle indices point into the 90-day projection the repository hydrates, so
  /// they can also be in the *future* (a predicted window). Negative offsets are
  /// past days, positive are predicted ones.
  static String _dayLabel(int seriesIndex, {bool withYear = false}) {
    final offset = seriesIndex - (EntryRepository.cacheDays - 1);
    final date = DateTime.now().add(Duration(days: offset));
    final label = '${date.day} ${_months[date.month - 1]}';
    return withYear || date.year != DateTime.now().year ? '$label ${date.year}' : label;
  }

  static const List<String> _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
}

/// The honest empty state: names what is missing and what fills it.
/// Asks for a height (needed for BMI) and stores it. Optional by design: the app
/// works fine without it and simply reports BMI as unavailable.
Future<void> _promptHeight(BuildContext context, AppState state) async {
  final controller = TextEditingController(
    text: state.heightCm == null ? '' : state.heightCm!.toStringAsFixed(0),
  );
  final result = await showCupertinoDialog<double>(
    context: context,
    builder: (context) => CupertinoAlertDialog(
      title: const Text('Your height'),
      content: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Column(
          children: [
            const Text('Used only to compute BMI on this device. It is never uploaded.'),
            const SizedBox(height: 12),
            CupertinoTextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              placeholder: 'cm',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      actions: [
        CupertinoDialogAction(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(context, double.tryParse(controller.text.trim())),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  if (result == null) return;
  // Out-of-range input is refused rather than stored: the setter validates and
  // the caller reports the outcome instead of silently keeping a bad number.
  final ok = await state.setHeightCm(result);
  if (!ok && context.mounted) {
    showTrackDialog(
      context,
      title: 'That height looks wrong',
      body: 'Enter a height between 50 and 300 cm. Nothing was saved.',
    );
  }
}

class _NoData extends StatelessWidget {
  const _NoData({required this.emoji, required this.title, required this.body});

  final String emoji;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 15),
      decoration: BoxDecoration(
        color: TrackTheme.surface(dark),
        borderRadius: BorderRadius.circular(TrackTheme.radiusCard),
        boxShadow: TrackTheme.cardShadow(dark),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: -.2, color: TrackTheme.label(dark))),
                const SizedBox(height: 3),
                Text(body,
                    style: TextStyle(fontSize: 12.5, height: 1.4, fontWeight: FontWeight.w500, color: TrackTheme.label2(dark))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Real per-bucket activity for one tracker, from its event rows.
///
/// Reads through `AppState`'s cached buckets rather than firing a query during
/// layout, and renders an empty state when the buckets are all zero.
class _RhythmList extends StatelessWidget {
  const _RhythmList({required this.state, required this.tracker, required this.buckets, required this.bucketHours});

  final AppState state;
  final Tracker tracker;
  final int buckets;
  final int bucketHours;

  @override
  Widget build(BuildContext context) {
    final rhythm = state.rhythmFor(tracker.id);
    if (rhythm == null || !rhythm.hasData) {
      return const _NoData(
        emoji: '💧',
        title: 'Nothing logged today yet',
        body: 'Each entry is timestamped, so once you log a few the app can show when in the day you drink.',
      );
    }
    final maxValue = rhythm.values.reduce((a, b) => a > b ? a : b);
    return GlassList(children: [
      for (var i = 0; i < rhythm.values.length; i++)
        _Bar(
          label: rhythm.labels[i],
          value: rhythm.values[i].round(),
          max: maxValue <= 0 ? 1 : maxValue.round(),
          color: tracker.accent,
        ),
    ]);
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 16, 15, 12),
      decoration: BoxDecoration(
        color: TrackTheme.surface(dark),
        borderRadius: BorderRadius.circular(TrackTheme.radiusCard),
        boxShadow: TrackTheme.cardShadow(dark),
        border: Border.all(color: dark ? Colors.white.withOpacity(.05) : Colors.black.withOpacity(.03), width: .5),
      ),
      child: child,
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.label,
    required this.value,
    required this.max,
    required this.color,
    this.suffix = '',
    this.money = false,
    this.width = 104,
  }) : duration = false;

  final String label;
  final int value;
  final int max;
  final Color color;
  final String suffix;
  final bool money;
  final bool duration;
  final double width;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final text = money
        ? '₹$value'
        : duration
            ? '${value ~/ 60}h ${value % 60}m'
            : '$value${suffix.isEmpty ? '' : ' $suffix'}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
      child: Row(
        children: [
          SizedBox(
            width: width,
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: TrackTheme.label(dark))),
          ),
          Expanded(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: (value / max).clamp(0.0, 1.0)),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Stack(
                  children: [
                    Container(height: 8, color: TrackTheme.fill(dark)),
                    FractionallySizedBox(
                      widthFactor: v,
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [Color.lerp(color, Colors.white, .12)!, color]),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 62,
            child: Text(text,
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: TrackTheme.label2(dark))),
          ),
        ],
      ),
    );
  }
}

/// One stored day, tappable to correct or remove it.
///
/// The subtitle is the entry's **provenance**, not the tracker's marketing line. Every
/// row used to be captioned with the blurb ("Hydration keeps your skin, joints and
/// focus in good shape") as if it were a note about that entry, which said nothing about
/// the day and read as a note the user had written.
class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.tracker,
    required this.value,
    required this.date,
    required this.isToday,
    required this.source,
    required this.onTap,
  });

  final Tracker tracker;
  final double value;
  final DateTime date;
  final bool isToday;
  final String source;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final provenance = switch (source) {
      'health' => 'Health Connect',
      'widget' => 'Widget',
      'import' => 'Imported',
      'demo' => 'Sample data',
      _ => 'You',
    };
    return GlassRow(
      title: isToday ? 'Today' : longDate(date).split(',').first,
      subtitle: '${shortDate(date)} · $provenance',
      leading: isToday
          ? Text(tracker.emoji, style: const TextStyle(fontSize: 15))
          : Text('${date.day}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: TrackTheme.label2(dark))),
      accent: tracker.accent,
      onTap: onTap,
      trailing: Text(fmtValue(tracker, value),
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: TrackTheme.label2(dark))),
    );
  }
}

/// The history list, read from the store.
///
/// Three things this fixes at once:
///
/// 1. The list was the gap-filled projection — a day the user had never logged appeared
///    as `0`, indistinguishable from a logged zero. Rows now come from the days that
///    actually have a record (`AppState.recordedDays`).
/// 2. Nothing could be corrected. Every write path wrote today, so a wrong day or a
///    wrong value was permanent. Each row opens the day sheet.
/// 3. A read failure was invisible: the list simply looked empty. The empty state and the
///    failure state are now different, and only one of them says "nothing logged yet".
class _HistorySection extends StatefulWidget {
  const _HistorySection({
    required this.tracker,
    required this.limit,
    required this.isPro,
    required this.onLockedTap,
  });

  final Tracker tracker;
  final int limit;
  final bool isPro;
  final VoidCallback onLockedTap;

  @override
  State<_HistorySection> createState() => _HistorySectionState();
}

class _HistorySectionState extends State<_HistorySection> {
  List<RecordedDay>? _days;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final state = context.read<AppState>();
    try {
      final rows = await state.recordedDays(widget.tracker.id, limit: widget.limit);
      if (!mounted) return;
      setState(() {
        _days = rows;
        _failed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  Future<void> _open(RecordedDay row) async {
    await openDaySheet(
      context,
      widget.tracker,
      day: row.day,
      value: row.value,
      source: row.source,
      // Re-read after an edit or a delete: the ring, the streak tiles and this list all
      // have to agree, and the surest way is to ask the store again.
      onChanged: _load,
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tracker;
    final dark = Theme.of(context).brightness == Brightness.dark;

    if (_failed) {
      return _NoData(
        emoji: '⚠️',
        title: 'History could not be read',
        body: 'The entries are still in the database, but this screen could not load them. '
            'Reopening this tracker usually clears it.',
      );
    }

    if (_days == null) {
      // Deliberately quiet: a spinner over a short database read is noise, but an empty
      // list *before* the read finishes would be a claim about the data.
      return GlassList(children: [
        GlassRow(
          title: 'Reading history…',
          subtitle: 'From the database on this device',
          accent: t.accent,
          showChevron: false,
          trailing: Text('—', style: TextStyle(fontSize: 15, color: TrackTheme.label3(dark))),
        ),
      ]);
    }

    final days = _days!;
    if (days.isEmpty) {
      return _NoData(
        emoji: '🗓️',
        title: 'No entries yet',
        body: 'Days you log appear here, one row each. Nothing is filled in for you: a day '
            'with no entry stays empty rather than showing a 0.',
      );
    }

    return GlassList(
      children: [
        for (final row in days)
          _HistoryRow(
            tracker: t,
            value: row.value,
            date: dateOfDayKey(row.day),
            isToday: row.day == dayKey(DateTime.now()),
            source: row.source,
            onTap: () => _open(row),
          ),
        if (!widget.isPro)
          ProLockedRow(
            title: 'Older entries are kept, not deleted',
            subtitle: 'Pro reveals your whole history plus 90-day trends',
            emoji: '🗓️',
            accent: t.accent,
            onTap: widget.onLockedTap,
          ),
      ],
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: TrackTheme.fill(dark), shape: BoxShape.circle),
        child: const Icon(CupertinoIcons.chevron_back, size: 17, color: TrackTheme.blue),
      ),
    );
  }
}
