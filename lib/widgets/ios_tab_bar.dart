import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../main.dart' show TrackTheme;
import '../services/haptics.dart';

/// Persistent five-destination navigation. The historical class name is retained
/// so routes do not churn, but the presentation is intentionally Android-appropriate:
/// a solid surface, outlined icons, labels, and a warm selected state.
class IosTabBar extends StatelessWidget {
  const IosTabBar({super.key, required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  static const _items = <List<Object>>[
    ['Today', Icons.home_rounded, Icons.home_outlined],
    ['Routines', Icons.repeat_rounded, Icons.repeat_rounded],
    ['Momentum', Icons.bolt_rounded, Icons.bolt_outlined],
    ['Insights', Icons.insights_rounded, Icons.insights_outlined],
    ['Profile', Icons.person_rounded, Icons.person_outline_rounded],
  ];

  /// The label may use two lines at larger accessibility scales. Every scroll
  /// screen reads this measured value for its bottom clearance, preventing content
  /// from being hidden behind either the nav bar or the Android gesture inset.
  static double contentHeight(BuildContext context) {
    final scaledLabelSize = MediaQuery.textScalerOf(context).scale(11);
    final labelLines = scaledLabelSize > 13.5 ? 2 : 1;
    return math.max(60, 31 + 3 + (scaledLabelSize * 1.15 * labelLines) + 8);
  }

  static double totalHeight(BuildContext context) => contentHeight(context) + MediaQuery.paddingOf(context).bottom;

  static double scrollClearance(BuildContext context) => totalHeight(context) + 24;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.only(bottom: bottom),
      decoration: BoxDecoration(
        color: TrackTheme.surface(dark),
        border: Border(top: BorderSide(color: TrackTheme.separator(dark), width: .5)),
      ),
      child: SizedBox(
        height: contentHeight(context),
        child: Row(
          children: [
            for (var i = 0; i < _items.length; i++)
              Expanded(
                child: _TabItem(
                  label: _items[i][0] as String,
                  activeIcon: _items[i][1] as IconData,
                  icon: _items[i][2] as IconData,
                  active: i == index,
                  onTap: () {
                    if (i != index) Haptics.selection();
                    onChanged(i);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.active,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = active ? TrackTheme.orange : TrackTheme.label2(dark);
    return Semantics(
      button: true,
      selected: active,
      label: label,
      child: InkResponse(
        onTap: onTap,
        radius: 32,
        highlightShape: BoxShape.rectangle,
        containedInkWell: true,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: active ? 1.04 : 1,
              duration: const Duration(milliseconds: 160),
              curve: TrackTheme.easeOut,
              child: Icon(active ? activeIcon : icon, size: 24, color: color),
            ),
            const SizedBox(height: 3),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 160),
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.15,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    letterSpacing: 0,
                    color: color,
                  ),
                  child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact contextual add action. It uses the same solid orange treatment as the
/// rest of the app instead of a floating blue gradient.
class QuickAddFab extends StatelessWidget {
  const QuickAddFab({super.key, required this.onTap, this.open = false, this.visible = true});

  final VoidCallback onTap;
  final bool open;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: open ? .94 : 1,
      duration: const Duration(milliseconds: 160),
      curve: TrackTheme.easeOut,
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 160),
          child: Material(
            color: TrackTheme.orange,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: () {
                Haptics.commit();
                onTap();
              },
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: 52,
                height: 52,
                child: AnimatedRotation(
                  turns: open ? .125 : 0,
                  duration: const Duration(milliseconds: 160),
                  curve: TrackTheme.easeOut,
                  child: const Icon(Icons.add_rounded, color: Colors.black, size: 27),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
