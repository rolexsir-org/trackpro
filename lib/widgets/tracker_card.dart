import 'package:flutter/material.dart';

import '../services/haptics.dart';

import '../main.dart' show Pressable, TrackTheme;
import '../models/models.dart';
import '../util/format.dart';
import 'glass.dart';
import 'mini_chart.dart';
import 'progress_ring.dart';

/// Grid card: ring + value + this-week mini chart + delta + quick log.
/// Everything is live off [AppState], so logging on the dashboard also updates
/// the detail screen, insights and streaks.
class TrackerCard extends StatelessWidget {
  const TrackerCard({
    super.key,
    required this.tracker,
    required this.values,
    required this.onTap,
    required this.onLog,
    this.onLongPress,
    this.chartValues,
  });

  final Tracker tracker;
  final List<double> values;

  /// Drawn by the sparkline; defaults to `values`. Kept separate so the free
  /// tier's 7-day history window never truncates a streak (streaks are free).
  final List<double>? chartValues;
  final VoidCallback onTap;
  final VoidCallback onLog;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    // A tracker with no series yet is a real state (a newly added tracker, or one whose
    // rows only exist on the widget). It reads as 0 with an empty chart — the previous
    // `values.last` threw on it.
    final v = values.isEmpty ? 0.0 : values.last;
    final pct = ringPct(tracker, v);
    final d = deltaOf(tracker, values);
    final streak = streakOf(tracker, values);
    final showStreak = !(tracker.id == 'period' || tracker.id == 'weight' || tracker.id == 'screen') && streak >= 2;

    return Pressable(
      onTap: onTap,
      onLongPress: onLongPress,
      child: TrackTheme.frosted(
        dark: dark,
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                TrackRecordIcon(label: tracker.name, color: tracker.accent, size: 28, iconSize: 16),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    tracker.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -.1,
                      color: TrackTheme.label2(dark),
                    ),
                  ),
                ),
                if (showStreak)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: tracker.accent.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.local_fire_department_outlined, size: 12, color: tracker.accent),
                        const SizedBox(width: 2),
                        Text(
                          '${streak}d',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: tracker.accent),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 11),
            Row(
              children: [
                ProgressRing(
                  pct: pct,
                  size: 72,
                  stroke: 7.5,
                  colorA: tracker.accent,
                  colorB: tracker.accent2,
                  center: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        fmtCompact(tracker, v),
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -.4,
                          color: TrackTheme.label(dark),
                        ),
                      ),
                      Text(
                        fmtGoalShort(tracker),
                        maxLines: 1,
                        style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w600, color: TrackTheme.label3(dark)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // The chart shows "this week"; the streak and delta above
                      // are computed over the full series, because the free
                      // tier's 7-day window must never shorten a streak.
                      MiniChart(values: chartValues ?? values, color: tracker.accent),
                      const SizedBox(height: 6),
                      Text(
                        'THIS WEEK',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: .5,
                          color: TrackTheme.label3(dark).withValues(alpha: .7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                Icon(
                  d.direction > 0
                      ? Icons.arrow_upward_rounded
                      : d.direction < 0
                      ? Icons.arrow_downward_rounded
                      : Icons.remove_rounded,
                  size: 10,
                  color: d.goodness > 0
                      ? TrackTheme.green
                      : d.goodness < 0
                      ? TrackTheme.orange
                      : TrackTheme.label3(dark),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    d.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: d.goodness > 0
                          ? TrackTheme.green
                          : d.goodness < 0
                          ? TrackTheme.orange
                          : TrackTheme.label3(dark),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 11),
            Row(
              children: [
                Expanded(
                  child: _LogButton(label: 'Log today', color: tracker.accent, onTap: onLog),
                ),
                const SizedBox(width: 7),
                _ChevronButton(color: tracker.accent, onTap: onTap),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LogButton extends StatefulWidget {
  const _LogButton({required this.label, required this.color, required this.onTap});

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_LogButton> createState() => _LogButtonState();
}

class _LogButtonState extends State<_LogButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: () {
        Haptics.light();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _down ? .93 : 1,
        duration: Duration(milliseconds: _down ? 110 : 300),
        curve: TrackTheme.spring,
        child: Container(
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: widget.color),
          child: Text(
            widget.label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: -.08, color: Colors.black),
          ),
        ),
      ),
    );
  }
}

class _ChevronButton extends StatelessWidget {
  const _ChevronButton({required this.color, required this.onTap});

  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: TrackTheme.fill(dark), borderRadius: BorderRadius.circular(10)),
        child: Icon(Icons.chevron_right_rounded, size: 19, color: color),
      ),
    );
  }
}

/// Full-width hero tracker (water by default): big ring, cups, live swipe-to-log.
class HeroTrackerCard extends StatefulWidget {
  const HeroTrackerCard({
    super.key,
    required this.tracker,
    required this.values,
    required this.onTap,
    required this.onStep,
    this.onLog,
    this.onLongPress,
  });

  final Tracker tracker;
  final List<double> values;
  final VoidCallback onTap;

  /// Swipe / button increments: +1 serving, -1 serving.
  final void Function(double delta) onStep;
  final VoidCallback? onLog;
  final VoidCallback? onLongPress;

  @override
  State<HeroTrackerCard> createState() => _HeroTrackerCardState();
}

class _HeroTrackerCardState extends State<HeroTrackerCard> {
  double _dx = 0;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final t = widget.tracker;
    final v = widget.values.isEmpty ? 0.0 : widget.values.last;
    final pct = ringPct(t, v);
    final units = (t.kind == MetricKind.volume ? v / 250 : pct * 10).round().clamp(0, 10).toInt();
    final step = t.step;
    final stepLabel = fmtValue(t, step);

    return ClipRRect(
      borderRadius: BorderRadius.circular(TrackTheme.radiusCard),
      child: Stack(
        children: [
          // Reveal layer behind the card, exposed as you drag.
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(color: TrackTheme.fill(dark)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '− $stepLabel',
                      style: TextStyle(color: TrackTheme.label(dark), fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    Text(
                      '+ $stepLabel',
                      style: TextStyle(color: TrackTheme.label(dark), fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: TrackTheme.spring,
            transform: Matrix4.translationValues(_dx, 0, 0),
            child: GestureDetector(
              onHorizontalDragUpdate: (d) => setState(() => _dx = (_dx + d.delta.dx).clamp(-120, 120).toDouble()),
              onHorizontalDragEnd: (d) {
                final dx = _dx;
                setState(() => _dx = 0);
                if (dx.abs() > 68) {
                  Haptics.commit();
                  widget.onStep(dx > 0 ? step : -step);
                }
              },
              child: Pressable(
                onTap: widget.onTap,
                onLongPress: widget.onLongPress,
                child: TrackTheme.frosted(
                  dark: dark,
                  padding: const EdgeInsets.all(17),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    TrackRecordIcon(label: t.name, color: t.accent, size: 28, iconSize: 16),
                                    const SizedBox(width: 7),
                                    Text(
                                      t.name,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: TrackTheme.label2(dark),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  fmtValue(t, v),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 30,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -1.0,
                                    color: TrackTheme.label(dark),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '$units of 10 steps · ${(pct * 100).round()}% of ${fmtGoalLong(t)}',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w500,
                                    color: TrackTheme.label2(dark),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ProgressRing(
                            pct: pct,
                            size: 112,
                            stroke: 12,
                            colorA: t.accent,
                            colorB: t.accent2,
                            center: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${(pct * 100).round()}%',
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -1,
                                    color: TrackTheme.label(dark),
                                  ),
                                ),
                                Text(
                                  fmtGoalLong(t),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: TrackTheme.label3(dark),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 5,
                        runSpacing: 5,
                        children: [
                          for (var i = 0; i < 10; i++)
                            Container(
                              width: 17,
                              height: 23,
                              decoration: BoxDecoration(
                                color: i < units ? t.accent : TrackTheme.fill(dark),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(3),
                                  topRight: Radius.circular(3),
                                  bottomLeft: Radius.circular(6),
                                  bottomRight: Radius.circular(6),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 9),
                      Row(
                        children: [
                          Icon(Icons.swipe_rounded, size: 15, color: TrackTheme.label3(dark)),
                          const SizedBox(width: 5),
                          Text(
                            'Swipe to log one step',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: TrackTheme.label3(dark).withValues(alpha: .8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _LogButton(label: '+ $stepLabel', color: t.accent, onTap: () => widget.onStep(step)),
                          ),
                          const SizedBox(width: 7),
                          _LogButton(
                            label: '+ 2×',
                            color: Color.lerp(t.accent, Colors.black, .05)!,
                            onTap: () => widget.onStep(step * 2),
                          ),
                          const SizedBox(width: 7),
                          _ChevronButton(color: t.accent, onTap: widget.onTap),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
