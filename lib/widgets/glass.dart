import 'dart:async';
import 'package:flutter/material.dart';

import '../services/haptics.dart';

import '../main.dart' show TrackTheme;

/// Shared page canvas retained for existing routes. Its accent parameters are
/// intentionally ignored: the previous ambient colour bloom made every tab look
/// like a different product and lowered contrast behind scroll content.
class AmbientBackground extends StatelessWidget {
  const AmbientBackground({super.key, required this.accent, required this.accent2});

  final Color accent;
  final Color accent2;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: TrackTheme.bg(Theme.of(context).brightness == Brightness.dark),
      );
}

/// A stable vector mark for stored routines and trackers. Historical emoji values
/// remain in the data model and exports for compatibility, but product UI no longer
/// renders platform-dependent emoji glyphs as navigation or status icons.
class TrackRecordIcon extends StatelessWidget {
  const TrackRecordIcon({
    super.key,
    required this.label,
    required this.color,
    this.size = 42,
    this.iconSize = 21,
  });

  final String label;
  final Color color;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withOpacity(.15),
          borderRadius: BorderRadius.circular(size * .32),
        ),
        child: Icon(_recordIcon(label), size: iconSize, color: color),
      );
}

IconData _recordIcon(String label) {
  final value = label.toLowerCase();
  if (value.contains('water')) return Icons.water_drop_outlined;
  if (value.contains('mood')) return Icons.sentiment_satisfied_alt_outlined;
  if (value.contains('money') || value.contains('expense') || value.contains('spend')) return Icons.account_balance_wallet_outlined;
  if (value.contains('sleep')) return Icons.bedtime_outlined;
  if (value.contains('calor') || value.contains('food')) return Icons.restaurant_outlined;
  if (value.contains('step') || value.contains('walk')) return Icons.directions_walk_outlined;
  if (value.contains('run')) return Icons.directions_run_outlined;
  if (value.contains('workout') || value.contains('train') || value.contains('lift')) return Icons.fitness_center_outlined;
  if (value.contains('read') || value.contains('book')) return Icons.menu_book_outlined;
  if (value.contains('meditat') || value.contains('breath')) return Icons.self_improvement_outlined;
  if (value.contains('write') || value.contains('journal')) return Icons.edit_note_outlined;
  if (value.contains('screen')) return Icons.phone_android_outlined;
  if (value.contains('weight')) return Icons.monitor_weight_outlined;
  return Icons.check_circle_outline_rounded;
}

/// ---------------------------------------------------------------------------
/// Bottom sheet — a solid Android-style modal surface with a visible drag handle.
/// It keeps the content in a bounded, scrollable region and can be dismissed by
/// dragging down or using the system back gesture.
/// ---------------------------------------------------------------------------
Future<T?> showGlassSheet<T>(
  BuildContext context, {
  required String title,
  String? subtitle,
  required Widget body,
  List<Widget> actions = const [],
  Color accent = TrackTheme.blue,
  bool scrollable = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.black.withOpacity(.62),
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (_, __, ___) => const SizedBox.shrink(),
    transitionBuilder: (context, anim, secondary, _) {
      final curved = CurvedAnimation(parent: anim, curve: TrackTheme.sheetCurve, reverseCurve: Curves.easeInCubic);
      return SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: FractionalTranslation(
            translation: Offset(0, 1 - curved.value),
            child: _SheetSurface(
              accent: accent,
              title: title,
              subtitle: subtitle,
              body: body,
              actions: actions,
              scrollable: scrollable,
            ),
          ),
        ),
      );
    },
  );
}

class _SheetSurface extends StatefulWidget {
  const _SheetSurface({
    required this.title,
    required this.subtitle,
    required this.body,
    required this.actions,
    required this.accent,
    required this.scrollable,
  });

  final String title;
  final String? subtitle;
  final Widget body;
  final List<Widget> actions;
  final Color accent;
  final bool scrollable;

  @override
  State<_SheetSurface> createState() => _SheetSurfaceState();
}

class _SheetSurfaceState extends State<_SheetSurface> {
  double _drag = 0;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final maxHeight = MediaQuery.sizeOf(context).height * .86;

    return GestureDetector(
      onVerticalDragUpdate: (d) => setState(() => _drag = (_drag + d.delta.dy).clamp(0, 400).toDouble()),
      onVerticalDragEnd: (d) {
        if (_drag > 90 || d.velocity.pixelsPerSecond.dy > 700) {
          Navigator.of(context).maybePop();
        } else {
          setState(() => _drag = 0);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: TrackTheme.easeOut,
        transform: Matrix4.translationValues(0, _drag, 0),
        constraints: BoxConstraints(maxHeight: maxHeight),
        decoration: BoxDecoration(
          color: TrackTheme.surface(dark),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(TrackTheme.radiusSheet)),
          border: Border.all(color: TrackTheme.separator(dark), width: .5),
          boxShadow: TrackTheme.sheetShadow,
        ),
        child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 9),
                Container(width: 38, height: 5, decoration: BoxDecoration(color: TrackTheme.label3(dark), borderRadius: BorderRadius.circular(3))),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -.4,
                                color: TrackTheme.label(dark),
                              ),
                            ),
                            if (widget.subtitle != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: Text(
                                  widget.subtitle!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.35,
                                    fontWeight: FontWeight.w500,
                                    color: TrackTheme.label3(dark),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
                    child: widget.body,
                  ),
                ),
                if (widget.actions.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    child: Column(
                      children: [
                        for (var i = 0; i < widget.actions.length; i++) ...[
                          widget.actions[i],
                          if (i < widget.actions.length - 1) const SizedBox(height: 9),
                        ],
                      ],
                    ),
                  )
                else
                  const SizedBox(height: 26),
              ],
            ),
      ),
    );
  }
}

/// Primary and secondary product buttons.
class TrackFilledButton extends StatelessWidget {
  const TrackFilledButton({super.key, required this.label, this.onTap, this.color = TrackTheme.blue});

  final String label;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return _Btn(
      label: label,
      onTap: onTap,
      bg: color,
      fg: Colors.black,
    );
  }
}

class TrackTintedButton extends StatelessWidget {
  const TrackTintedButton({super.key, required this.label, this.onTap, this.color = TrackTheme.blue});

  final String label;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return _Btn(label: label, onTap: onTap, bg: null, fg: dark ? color : color, flatColor: TrackTheme.fill(dark));
  }
}

class _Btn extends StatefulWidget {
  const _Btn({required this.label, this.onTap, this.bg, required this.fg, this.flatColor});

  final String label;
  final VoidCallback? onTap;
  final Color? bg;
  final Color fg;
  final Color? flatColor;

  @override
  State<_Btn> createState() => _BtnState();
}

class _BtnState extends State<_Btn> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap == null
          ? null
          : () {
              Haptics.light();
              widget.onTap!();
            },
      child: Semantics(
        button: true,
        enabled: widget.onTap != null,
        label: widget.label,
        child: AnimatedScale(
          scale: _down ? .97 : 1,
          duration: Duration(milliseconds: _down ? 120 : 300),
          curve: TrackTheme.spring,
          // A button with no handler is drawn as unavailable. Before this, `onTap: null`
          // removed the handler but kept the fill and the label exactly as they were, so a
          // button that had already done its job still invited a tap.
          child: AnimatedOpacity(
            opacity: widget.onTap == null ? .55 : 1,
            duration: const Duration(milliseconds: 200),
            child: Container(
              constraints: const BoxConstraints(minHeight: 50),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: widget.bg ?? widget.flatColor,
                borderRadius: BorderRadius.circular(TrackTheme.radiusCard),
                border: Border.all(
                  color: widget.bg == null ? TrackTheme.separator(Theme.of(context).brightness == Brightness.dark) : Colors.transparent,
                  width: .5,
                ),
              ),
              child: Text(
                widget.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -.3, color: widget.fg),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// List primitives shared by Today / Trackers / Settings.
/// ---------------------------------------------------------------------------
/// The round chevron-back button used by every pushed screen.
///
/// Promoted out of `detail_screen.dart`, where it was private, so the Focus Lock
/// screens (which are pushed, not tabbed) do not each grow their own copy. Same
/// shape and colour as before — this is a move, not a restyle.
/// Runs an action **once**, and stays inert afterwards.
///
/// Why this exists: every sheet in the app acted like
/// `onTap: () { Navigator.of(context).pop(); await save(); }` — the route closes
/// immediately, so nothing on screen is left to absorb a second tap that arrives
/// before the removal is painted. Two taps, two writes: a calorie delta counted
/// twice, an expense recorded twice, a delete applied to a day that was already
/// cleared. The guard is set **synchronously** before the first `await`, which is the
/// only version of this that actually closes the window.
///
/// The builder receives `submit` — non-null when the action can run, null while it is
/// running *and after it has succeeded*, so the button the user is looking at goes
/// inert instead of silently ignoring them.
///
/// Success latches the button off for the rest of the widget's life, which is what
/// closes the second window: the route is still on screen during its dismiss
/// animation, so a tap that arrives 150 ms after the first one would otherwise land on
/// a live button. A **failure** leaves it live on purpose — the user needs to be able
/// to try again.
class SubmitOnce extends StatefulWidget {
  const SubmitOnce({super.key, required this.onSubmit, required this.builder});

  /// The work. Everything the tap should do lives here, including the pop. Returns
  /// whether it completed; `false` re-arms the button.
  final Future<bool> Function() onSubmit;

  /// Builds the button. Wire `submit` straight to `onTap`.
  final Widget Function(BuildContext context, VoidCallback? submit) builder;

  @override
  State<SubmitOnce> createState() => _SubmitOnceState();
}

class _SubmitOnceState extends State<SubmitOnce> {
  bool _busy = false;
  bool _done = false;

  Future<void> _run() async {
    if (_busy || _done) return;
    // Set before the first await, not after: a guard set inside the async body is a
    // guard that arrives too late to stop the second tap.
    setState(() => _busy = true);
    var ok = false;
    try {
      ok = await widget.onSubmit();
    } finally {
      // The sheet has usually been popped by now; setting state on a disposed
      // element is the classic crash in this pattern, so it is guarded.
      if (mounted) {
        setState(() {
          _busy = false;
          _done = ok;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, (_busy || _done) ? null : () => unawaited(_run()));
}

class TrackBackButton extends StatelessWidget {
  const TrackBackButton({super.key, this.onTap});

  /// Defaults to popping the current route.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap ?? () => Navigator.of(context).maybePop(),
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: TrackTheme.fill(dark), shape: BoxShape.circle),
        child: const Icon(Icons.arrow_back_rounded, size: 19, color: TrackTheme.blue),
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 26, 4, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Text(
              text.toUpperCase(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                height: 1.25,
                fontWeight: FontWeight.w600,
                letterSpacing: .4,
                color: TrackTheme.label3(dark),
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            Flexible(fit: FlexFit.loose, child: trailing!),
          ],
        ],
      ),
    );
  }
}

class GlassList extends StatelessWidget {
  const GlassList({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: TrackTheme.surface(dark),
        borderRadius: BorderRadius.circular(TrackTheme.radiusCard),
        border: Border.all(color: TrackTheme.separator(dark), width: .5),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.only(left: 15),
                child: Container(height: .5, color: TrackTheme.separator(dark)),
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

class GlassRow extends StatelessWidget {
  const GlassRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.accent = TrackTheme.blue,
    this.showChevron = true,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color accent;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap == null
          ? null
          : () {
              Haptics.selection();
              onTap!();
            },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (leading != null) ...[
              Container(
                width: 29,
                height: 29,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: accent.withOpacity(.15), borderRadius: BorderRadius.circular(9)),
                child: leading,
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.25,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -.32,
                      color: TrackTheme.label(dark),
                    ),
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                          color: TrackTheme.label3(dark),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
            if (showChevron && onTap != null)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(Icons.chevron_right_rounded, size: 18, color: TrackTheme.label3(dark)),
              ),
          ],
        ),
      ),
    );
  }
}

class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      decoration: BoxDecoration(
        color: TrackTheme.surface(dark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TrackTheme.separator(dark), width: .5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Counts may be wider than a third of a narrow Android screen.
          // Scale just the numeric glyphs down when necessary instead of clipping
          // or letting a text-scale setting push the three-card row out of bounds.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -.5,
                color: TrackTheme.label(dark),
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label.toUpperCase(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              height: 1.25,
              fontWeight: FontWeight.w600,
              letterSpacing: .1,
              color: TrackTheme.label3(dark),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tinted insight card — the "pattern we found" surface.
class InsightCard extends StatelessWidget {
  const InsightCard({super.key, required this.emoji, required this.title, required this.body, required this.accent, this.accent2 = TrackTheme.indigo});

  final String emoji;
  final String title;
  final String body;
  final Color accent;
  final Color accent2;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(TrackTheme.radiusCard),
        color: Color.lerp(TrackTheme.surface(dark), accent, dark ? .13 : .08),
        border: Border.all(color: Color.lerp(TrackTheme.separator(dark), accent, .35)!, width: .5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_insightIcon(emoji), size: 20, color: Color.lerp(accent, accent2, .25)),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, letterSpacing: -.24, height: 1.35, color: TrackTheme.label(dark))),
                const SizedBox(height: 3),
                Text(body,
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, height: 1.45, color: TrackTheme.label2(dark))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

IconData _insightIcon(String hint) {
  if (hint.contains('↗') || hint.contains('↘')) return Icons.trending_up_rounded;
  if (hint.contains('📅')) return Icons.calendar_today_outlined;
  if (hint.contains('🎯')) return Icons.track_changes_outlined;
  if (hint.contains('⚖')) return Icons.monitor_weight_outlined;
  return Icons.insights_outlined;
}

/// ---------------------------------------------------------------------------
/// Long-press quick actions presented as a solid, accessible menu.
/// ---------------------------------------------------------------------------
Future<String?> showTrackContextMenu(
  BuildContext context,
  Offset globalPosition, {
  required List<List<Object>> items, // [label, IconData, isDestructive?]
}) {
  return showGeneralDialog<String>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Menu',
    barrierColor: Colors.black.withOpacity(.18),
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (_, __, ___) => const SizedBox.shrink(),
    transitionBuilder: (context, anim, _, __) {
      final curved = CurvedAnimation(parent: anim, curve: TrackTheme.spring, reverseCurve: Curves.easeIn);
      final dark = Theme.of(context).brightness == Brightness.dark;
      final size = MediaQuery.sizeOf(context);
      final dx = globalPosition.dx.clamp(12.0, size.width - 240).toDouble();
      final dy = globalPosition.dy.clamp(70.0, size.height - 300).toDouble();
      return Stack(
        children: [
          Positioned(
            left: dx,
            top: dy,
            child: FadeTransition(
              opacity: anim,
              child: ScaleTransition(
                scale: curved,
                alignment: Alignment.topLeft,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    width: 232,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(TrackTheme.radiusCard),
                      color: TrackTheme.surface(dark),
                      border: Border.all(color: TrackTheme.separator(dark), width: .5),
                    ),
                    child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final item in items)
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  Haptics.selection();
                                  Navigator.of(context).pop(item[0] as String);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(color: TrackTheme.separator(dark), width: .5),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(item[0] as String,
                                            style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w400,
                                                letterSpacing: -.3,
                                                color: item.length > 2 && item[2] == true ? TrackTheme.red : TrackTheme.label(dark))),
                                      ),
                                      Icon(item[1] as IconData, size: 17, color: TrackTheme.label3(dark)),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}
