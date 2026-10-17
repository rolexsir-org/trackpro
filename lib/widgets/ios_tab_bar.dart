import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../services/haptics.dart';

import '../main.dart' show TrackTheme;

/// iOS bottom tab bar: 10pt labels, 4pt gap, blue tint on the active tab,
/// 28pt blur behind, hairline top border, home-indicator safe area.
class IosTabBar extends StatelessWidget {
  const IosTabBar({super.key, required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  /// Five sections, in the order the product thinks in: what you do today, what
  /// you have committed to, how consistently you have kept it, what the record
  /// shows, and your own settings. Measurements (water, mood, money…) live under
  /// Profile: they are a companion feature, not the spine of the app.
  static const _items = <List<Object>>[
    ['Today', CupertinoIcons.house_fill, CupertinoIcons.house],
    ['Routines', CupertinoIcons.repeat, CupertinoIcons.repeat],
    ['Momentum', CupertinoIcons.bolt_fill, CupertinoIcons.bolt],
    ['Insights', CupertinoIcons.chart_bar_square_fill, CupertinoIcons.chart_bar_square],
    ['Profile', CupertinoIcons.person_crop_circle_fill, CupertinoIcons.person_crop_circle],
  ];

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: Container(
          padding: EdgeInsets.only(bottom: bottom),
          decoration: BoxDecoration(
            color: dark ? const Color(0xFF1C1C1E).withOpacity(.78) : Colors.white.withOpacity(.78),
            border: Border(top: BorderSide(color: TrackTheme.separator(dark), width: .5)),
          ),
          child: SizedBox(
            height: 52,
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
                        Haptics.selection();
                        onChanged(i);
                      },
                    ),
                  ),
              ],
            ),
          ),
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
    final color = active ? TrackTheme.blue : TrackTheme.label3(Theme.of(context).brightness == Brightness.dark);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedScale(
            scale: active ? 1.06 : 1,
            duration: const Duration(milliseconds: 320),
            curve: TrackTheme.spring,
            child: Icon(active ? activeIcon : icon, size: 25, color: color),
          ),
          const SizedBox(height: 2),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 220),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              letterSpacing: .06,
              color: color,
            ),
            child: Text(label),
          ),
        ],
      ),
    );
  }
}

/// Floating quick-add button — iOS-blue gradient, blue-tinted shadow, springs
/// into a close state while the sheet is open.
class QuickAddFab extends StatelessWidget {
  const QuickAddFab({super.key, required this.onTap, this.open = false, this.visible = true});

  final VoidCallback onTap;
  final bool open;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: open ? .9 : 1,
      duration: const Duration(milliseconds: 340),
      curve: TrackTheme.spring,
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 220),
          child: GestureDetector(
            onTap: () {
              Haptics.commit();
              onTap();
            },
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF0A84FF), Color(0xFF0071E3)]),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF0A84FF).withOpacity(.85), blurRadius: 30, offset: const Offset(0, 14), spreadRadius: -10),
                  BoxShadow(color: Colors.black.withOpacity(.16), blurRadius: 10, offset: const Offset(0, 3)),
                ],
              ),
              child: AnimatedRotation(
                turns: open ? .125 : 0,
                duration: const Duration(milliseconds: 340),
                curve: TrackTheme.spring,
                child: const Icon(CupertinoIcons.plus, color: Colors.white, size: 26),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
