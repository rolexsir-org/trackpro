import 'package:flutter/material.dart';

/// This-week bar chart. Bars grow in with a per-index delay so the whole
/// dashboard "draws itself" on load — the same micro-motion as the prototype.
class MiniChart extends StatelessWidget {
  const MiniChart({
    super.key,
    required this.values,
    required this.color,
    this.height = 34,
    this.barRadius = 3,
    this.todayTint = true,
    this.animate = true,
  });

  final List<double> values;
  final Color color;
  final double height;
  final double barRadius;
  final bool todayTint;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final max = values.fold<double>(0, (p, e) => e > p ? e : p);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i == values.length - 1 ? 0 : 3),
                child: _Bar(
                  fraction: max <= 0 ? .06 : (values[i] / max).clamp(.06, 1.0),
                  color: color,
                  radius: barRadius,
                  dim: !todayTint && i == values.length - 1,
                  dark: dark,
                  delay: Duration(milliseconds: animate ? i * 42 : 0),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.fraction,
    required this.color,
    required this.radius,
    required this.dim,
    required this.dark,
    required this.delay,
  });

  final double fraction;
  final Color color;
  final double radius;
  final bool dim;
  final bool dark;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: .05, end: fraction),
      duration: const Duration(milliseconds: 640) + delay,
      curve: Interval(delay.inMilliseconds / (640 + delay.inMilliseconds), 1, curve: Curves.easeOutCubic),
      builder: (context, v, _) => Align(
        alignment: Alignment.bottomCenter,
        child: FractionallySizedBox(
          heightFactor: v.clamp(.04, 1.0),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: dim
                    ? [Colors.white.withOpacity(.9), color.withOpacity(.4)]
                    : [Color.lerp(color, Colors.white, .18)!, color],
              ),
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

/// Smooth trend line (weight, mood-vs-sleep) with a gradient area fill and a
/// left-to-right reveal.
class TrendLine extends StatelessWidget {
  const TrendLine({
    super.key,
    required this.values,
    required this.colorA,
    required this.colorB,
    this.height = 96,
  });

  final List<double> values;
  final Color colorA;
  final Color colorB;
  final double height;

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).scaffoldBackgroundColor;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 1400),
        curve: Curves.easeOutCubic,
        builder: (context, t, _) => CustomPaint(painter: _LinePainter(values, colorA, colorB, t, bg)),
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter(this.values, this.a, this.b, this.t, this.bg);

  final List<double> values;
  final Color a;
  final Color b;
  final double t;
  final Color bg;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final max = values.reduce((x, y) => x > y ? x : y);
    final min = values.reduce((x, y) => x < y ? x : y);
    final span = (max - min) == 0 ? 1.0 : (max - min);
    final pts = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      pts.add(Offset(
        i / (values.length - 1) * size.width,
        size.height - 10 - ((values[i] - min) / span) * (size.height - 26),
      ));
    }

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width * t, size.height));

    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      final prev = pts[i - 1], cur = pts[i];
      final mid = Offset((prev.dx + cur.dx) / 2, (prev.dy + cur.dy) / 2);
      path.quadraticBezierTo(prev.dx, prev.dy, mid.dx, mid.dy);
      if (i == pts.length - 1) path.lineTo(cur.dx, cur.dy);
    }

    final area = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [a.withOpacity(.32), a.withOpacity(0)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..shader = LinearGradient(colors: [a, b]).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );
    canvas.restore();

    canvas.drawCircle(pts.last, 5, Paint()..color = b);
    canvas.drawCircle(pts.last, 5, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = bg);
  }

  @override
  bool shouldRepaint(_LinePainter old) => old.t != t || old.values != values;
}
