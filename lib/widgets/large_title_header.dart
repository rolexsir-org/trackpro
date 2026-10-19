import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../main.dart' show TrackTheme;

/// The shared pinned header used at the root of each scroll surface.
///
/// This widget deliberately returns a sliver. It must therefore be placed directly
/// in a [CustomScrollView.slivers] list (never inside [SliverToBoxAdapter]). Keeping
/// that contract here makes a RenderBox/RenderSliver mismatch fail in code review,
/// rather than on an Android device.
class LargeTitleHeader extends StatelessWidget {
  const LargeTitleHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.leading,
    this.largeHeight = 96,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? leading;

  /// Minimum expanded height excluding the status-bar inset. The delegate grows
  /// beyond this when the title/subtitle need more room at the user's text scale.
  final double largeHeight;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final size = MediaQuery.sizeOf(context);
    final scaler = MediaQuery.textScalerOf(context);
    final textDirection = Directionality.of(context);
    final largeTitleStyle = const TextStyle(fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -.8, height: 1.05);
    final subtitleStyle = const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, height: 1.3);

    // A fixed 96px header left only 40px below the compact bar. That was less
    // than the title + subtitle column at the default scale, causing the confirmed
    // 35px overflow on Today and Insights. Measure the same text the header renders
    // so expanded height is sufficient at narrow widths and Android font scales too.
    final titlePainter = TextPainter(
      text: TextSpan(text: title, style: largeTitleStyle),
      textDirection: textDirection,
      textScaler: scaler,
      maxLines: 2,
      ellipsis: '…',
    )..layout(maxWidth: math.max(0.0, size.width - 40.0));
    final subtitlePainter = subtitle == null
        ? null
        : (TextPainter(
            text: TextSpan(text: subtitle, style: subtitleStyle),
            textDirection: textDirection,
            textScaler: scaler,
            maxLines: 2,
            ellipsis: '…',
          )..layout(maxWidth: math.max(0.0, size.width - 40.0)));

    const compactHeight = 56.0;
    const largeVerticalPadding = 22.0;
    final measuredLargeContent = largeVerticalPadding + titlePainter.height + (subtitlePainter == null ? 0 : 4 + subtitlePainter.height);
    final expandedHeight = math.max(largeHeight, compactHeight + measuredLargeContent);

    return SliverPersistentHeader(
      pinned: true,
      delegate: _LargeTitleDelegate(
        title: title,
        subtitle: subtitle,
        trailing: trailing,
        leading: leading,
        topInset: topInset,
        expandedHeight: expandedHeight,
      ),
    );
  }
}

class _LargeTitleDelegate extends SliverPersistentHeaderDelegate {
  const _LargeTitleDelegate({
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.leading,
    required this.topInset,
    required this.expandedHeight,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? leading;
  final double topInset;
  final double expandedHeight;

  static const _compactHeight = 56.0;

  @override
  double get minExtent => topInset + _compactHeight;

  @override
  double get maxExtent => topInset + math.max(expandedHeight, _compactHeight);

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final range = math.max(1.0, maxExtent - minExtent);
    final progress = (shrinkOffset / range).clamp(0.0, 1.0).toDouble();
    final largeOpacity = (1 - progress * 1.5).clamp(0.0, 1.0).toDouble();
    final compactOpacity = ((progress - .35) / .65).clamp(0.0, 1.0).toDouble();

    return Container(
      color: TrackTheme.bg(dark).withOpacity(progress > .03 ? .98 : 0),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: topInset,
            left: 20,
            right: 20,
            height: _compactHeight,
            child: Opacity(
              opacity: compactOpacity,
              child: Row(
                children: [
                  if (leading != null) ...[
                    leading!,
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -.45,
                        color: TrackTheme.label(dark),
                      ),
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 10),
                    trailing!,
                  ],
                ],
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            top: topInset + _compactHeight + 11,
            bottom: 11,
            child: Opacity(
              opacity: largeOpacity,
              child: ExcludeSemantics(
                excluding: compactOpacity > .5,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 34,
                        height: 1.05,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -.8,
                        color: TrackTheme.label(dark),
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.3,
                          fontWeight: FontWeight.w500,
                          color: TrackTheme.label3(dark),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _LargeTitleDelegate oldDelegate) =>
      title != oldDelegate.title ||
      subtitle != oldDelegate.subtitle ||
      trailing != oldDelegate.trailing ||
      leading != oldDelegate.leading ||
      topInset != oldDelegate.topInset ||
      expandedHeight != oldDelegate.expandedHeight;
}
