import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../main.dart' show TrackTheme;

/// The signature iOS navigation pattern, hand-built so we get real frosted glass
/// in *both* the collapsed and expanded states (Cupertino's own sliver bar goes
/// opaque on collapse, which breaks the look).
///
/// - Large title: 34pt bold, tight tracking, left-aligned at 16pt gutter.
/// - Collapses into a 56pt bar that blurs + saturates whatever scrolls under it.
/// - Title crossfades and translates instead of snapping.
class LargeTitleHeader extends StatelessWidget {
  const LargeTitleHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.leading,
    this.largeHeight = 96,
    this.onCollapsedChanged,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? leading;
  final double largeHeight;
  final ValueChanged<bool>? onCollapsedChanged;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return SliverPersistentHeader(
      pinned: true,
      delegate: _HeaderDelegate(
        title: title,
        subtitle: subtitle,
        trailing: trailing,
        leading: leading,
        topInset: topInset,
        largeHeight: largeHeight,
        onCollapsedChanged: onCollapsedChanged,
      ),
    );
  }
}

class _HeaderDelegate extends SliverPersistentHeaderDelegate {
  _HeaderDelegate({
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.leading,
    required this.topInset,
    required this.largeHeight,
    this.onCollapsedChanged,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? leading;
  final double topInset;
  final double largeHeight;
  final ValueChanged<bool>? onCollapsedChanged;

  bool _wasCollapsed = false;

  static const double compactBar = 56;

  @override
  double get minExtent => compactBar + topInset;

  @override
  double get maxExtent => largeHeight + topInset;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final collapsed = shrinkOffset > (maxExtent - minExtent) * .55;
    if (collapsed != _wasCollapsed) {
      _wasCollapsed = collapsed;
      final cb = onCollapsedChanged;
      if (cb != null) WidgetsBinding.instance.addPostFrameCallback((_) => cb(collapsed));
    }

    final t = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);
    final glassOpacity = Curves.easeOut.transform(((t - .45) / .4).clamp(0.0, 1.0));

    return Stack(
      children: [
        // Frosted bar — only visible once content scrolls underneath.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: minExtent,
          child: Opacity(
            opacity: glassOpacity,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  decoration: BoxDecoration(
                    color: TrackTheme.surfaceGlass(dark),
                    border: Border(bottom: BorderSide(color: TrackTheme.separator(dark), width: .5)),
                  ),
                ),
              ),
            ),
          ),
        ),
        // Compact title + actions.
        Positioned(
          top: topInset,
          left: 0,
          right: 0,
          height: compactBar,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 12)],
                Expanded(
                  child: Opacity(
                    opacity: glassOpacity,
                    child: Center(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -.41,
                          color: TrackTheme.label(dark),
                        ),
                      ),
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
        ),
        // Large title block.
        Positioned(
          left: 16,
          right: 16,
          top: topInset + compactBar,
          bottom: 0,
          child: Opacity(
            opacity: (1 - t * 1.6).clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, -t * 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 34,
                      height: 1.12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -.7,
                      color: TrackTheme.label(dark),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -.1,
                        color: TrackTheme.label2(dark),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  bool shouldRebuild(_HeaderDelegate old) =>
      old.title != title ||
      old.subtitle != subtitle ||
      old.topInset != topInset ||
      old.largeHeight != largeHeight ||
      old.leading != leading;
}

/// Soft ambient colour field behind every screen — this is what makes the
/// frosted surfaces read as glass instead of grey.
class AmbientBackground extends StatelessWidget {
  const AmbientBackground({super.key, required this.accent, this.accent2 = const Color(0xFF5856D6)});

  final Color accent;
  final Color accent2;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned.fill(child: ColoredBox(color: TrackTheme.bg(dark))),
          _blob(top: -120, left: -80, size: 300, color: const Color(0xFF007AFF), opacity: dark ? .28 : .34),
          _blob(top: -70, right: -100, size: 290, color: accent, opacity: dark ? .26 : .32),
          _blob(top: 300, left: -140, size: 340, color: accent2, opacity: dark ? .18 : .22),
          _blob(bottom: -120, right: -80, size: 280, color: const Color(0xFF34C759), opacity: dark ? .12 : .16),
        ],
      ),
    );
  }

  Widget _blob({double? top, double? left, double? right, double? bottom, required double size, required Color color, required double opacity}) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: Opacity(
        opacity: opacity,
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 46, sigmaY: 46),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [color, color.withOpacity(0)]),
            ),
          ),
        ),
      ),
    );
  }
}
