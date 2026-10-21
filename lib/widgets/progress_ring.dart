import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Progress ring with a single readable semantic color and a draw-on-load animation.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.pct,
    this.size = 78,
    this.stroke = 8,
    this.colorA = const Color(0xFFFF7A18),
    this.colorB = const Color(0xFFFF5A1F),
    this.trackColor,
    this.center,
    this.duration = const Duration(milliseconds: 1250),
    this.animate = true,
  });

  final double pct;
  final double size;
  final double stroke;
  final Color colorA;
  final Color colorB;
  final Color? trackColor;
  final Widget? center;
  final Duration duration;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final target = pct.clamp(0.0, 1.0).toDouble();
    final ring = TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: animate ? 0 : target, end: target),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => CustomPaint(
        size: Size.square(size),
        painter: _RingPainter(
          value: v,
          stroke: stroke,
          a: colorA,
          b: colorB,
          track: trackColor ?? Theme.of(context).dividerColor.withValues(alpha: .5),
        ),
      ),
    );

    if (center == null) return SizedBox(width: size, height: size, child: ring);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ring,
          Padding(padding: EdgeInsets.all(stroke + 4), child: center),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.value, required this.stroke, required this.a, required this.b, required this.track});

  final double value;
  final double stroke;
  final Color a;
  final Color b;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = track;
    canvas.drawArc(rect, 0, math.pi * 2, false, trackPaint);
    if (value <= 0) return;

    // Start at 12 o'clock and use one solid semantic color. The older gradient and
    // halo were decorative rather than information-bearing and competed with data.
    final sweep = math.pi * 2 * value;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = a,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.a != a || old.b != b || old.stroke != stroke || old.track != track;
}
