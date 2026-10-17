import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../services/haptics.dart';

import '../main.dart' show Pressable, TrackTheme;
import '../models/models.dart';
import '../state/app_state.dart';
import '../util/format.dart';
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
                Text(tracker.emoji, style: const TextStyle(fontSize: 15)),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(tracker.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: -.1, color: TrackTheme.label2(dark))),
                ),
                if (showStreak)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: tracker.accent.withOpacity(.14), borderRadius: BorderRadius.circular(6)),
                    child: Text('🔥 ${streak}d',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: tracker.accent)),
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
                            fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: -.4, color: TrackTheme.label(dark)),
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
                      Text('THIS WEEK',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: .5, color: TrackTheme.label3(dark).withOpacity(.7))),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                Icon(
                  d.direction > 0 ? CupertinoIcons.arrow_up : d.direction < 0 ? CupertinoIcons.arrow_down : CupertinoIcons.minus,
                  size: 10,
                  color: d.goodness > 0 ? TrackTheme.green : d.goodness < 0 ? TrackTheme.orange : TrackTheme.label3(dark),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(d.text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: d.goodness > 0 ? TrackTheme.green : d.goodness < 0 ? TrackTheme.orange : TrackTheme.label3(dark),
                      )),
                ),
              ],
            ),
            const SizedBox(height: 11),
            Row(
              children: [
                Expanded(
                  child: _LogButton(label: '＋ Log today', color: tracker.accent, onTap: onLog),
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
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color.lerp(widget.color, Colors.white, .06)!, widget.color],
            ),
            boxShadow: [BoxShadow(color: widget.color.withOpacity(.55), blurRadius: 14, offset: const Offset(0, 6), spreadRadius: -8)],
          ),
          child: Text(widget.label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: -.08, color: Colors.white)),
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
        child: Icon(CupertinoIcons.chevron_forward, size: 14, color: color),
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
    final cups = (v / 250).round().clamp(0, 10);
    final step = t.step;

    return ClipRRect(
      borderRadius: BorderRadius.circular(TrackTheme.radiusCard),
      child: Stack(
        children: [
          // Reveal layer behind the card, exposed as you drag.
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [TrackTheme.green, Color(0xFF2AA049), Color(0x00FFFFFF), TrackTheme.orange]),
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('− 250 ml', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                    Text('+ 250 ml', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
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
              onHorizontalDragUpdate: (d) => setState(() => _dx = (_dx + d.delta.dx).clamp(-120, 120)),
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
                                    Text(t.emoji, style: const TextStyle(fontSize: 15)),
                                    const SizedBox(width: 7),
                                    Text(t.name,
                                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: TrackTheme.label2(dark))),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text((v / 1000).toStringAsFixed(2).replaceAll(RegExp(r'0$'), ''),
                                        style: TextStyle(
                                            fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -1.1, color: TrackTheme.label(dark))),
                                    const SizedBox(width: 4),
                                    Text('L', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: TrackTheme.label3(dark))),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text('$cups of 10 cups · ${(pct * 100).round()}% of ${fmtGoalLong(t)}',
                                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: TrackTheme.label2(dark))),
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
                                Text('${(pct * 100).round()}%',
                                    style: TextStyle(
                                        fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -1, color: TrackTheme.label(dark))),
                                Text(fmtGoalLong(t),
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: TrackTheme.label3(dark))),
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
                                color: i < cups ? null : TrackTheme.fill(dark),
                                gradient: i < cups && dark == false
                                    ? const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF5AC8FA), Color(0xFF0A84FF)])
                                    : i < cups
                                        ? const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF5AC8FA), Color(0xFF0A84FF)])
                                        : null,
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
                          Icon(CupertinoIcons.arrow_left_right, size: 11, color: TrackTheme.label3(dark).withOpacity(.8)),
                          const SizedBox(width: 5),
                          Text('swipe the card to log a cup',
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: TrackTheme.label3(dark).withOpacity(.8))),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _LogButton(label: '＋ Add 250 ml', color: t.accent, onTap: () => widget.onStep(250))),
                          const SizedBox(width: 7),
                          _LogButton(label: '＋ 500', color: Color.lerp(t.accent, Colors.black, .05)!, onTap: () => widget.onStep(500)),
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
