import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../services/haptics.dart';

import '../main.dart' show TrackTheme;

/// ---------------------------------------------------------------------------
/// Bottom sheet — slides up with Apple's sheet curve over a blurred backdrop
/// and can be dragged down to dismiss.
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
    barrierColor: Colors.black.withOpacity(.32),
    transitionDuration: const Duration(milliseconds: 440),
    pageBuilder: (_, __, ___) => const SizedBox.shrink(),
    transitionBuilder: (context, anim, secondary, _) {
      final curved = CurvedAnimation(parent: anim, curve: TrackTheme.sheetCurve, reverseCurve: Curves.easeInCubic);
      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10 * anim.value, sigmaY: 10 * anim.value),
        child: SafeArea(
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
      onVerticalDragUpdate: (d) => setState(() => _drag = (_drag + d.delta.dy).clamp(0, 400)),
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
          color: dark ? const Color(0xFF1C1C1E).withOpacity(.94) : Colors.white.withOpacity(.94),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(TrackTheme.radiusSheet)),
          boxShadow: TrackTheme.sheetShadow,
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(TrackTheme.radiusSheet)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 34, sigmaY: 34),
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
                            Text(widget.title,
                                style: TextStyle(
                                    fontSize: 19, fontWeight: FontWeight.w700, letterSpacing: -.4, color: TrackTheme.label(dark))),
                            if (widget.subtitle != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: Text(widget.subtitle!,
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: TrackTheme.label3(dark))),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
                    child: widget.body,
                  ),
                ),
                if (widget.actions.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    child: Column(children: [
                      for (final a in widget.actions) ...[a, const SizedBox(height: 9)],
                    ]),
                  )
                else
                  const SizedBox(height: 26),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// iOS-filled and iOS-tinted buttons.
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
      bg: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [color, Color.lerp(color, Colors.black, .12)!]),
      fg: Colors.white,
      glow: color.withOpacity(.85),
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
  const _Btn({required this.label, this.onTap, this.bg, required this.fg, this.flatColor, this.glow});

  final String label;
  final VoidCallback? onTap;
  final Gradient? bg;
  final Color fg;
  final Color? flatColor;
  final Color? glow;

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
            height: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: widget.bg,
              color: widget.flatColor,
              borderRadius: BorderRadius.circular(14),
              boxShadow: widget.glow == null
                  ? null
                  : [BoxShadow(color: widget.glow!, blurRadius: 22, offset: const Offset(0, 10), spreadRadius: -10)],
            ),
            child: Text(widget.label,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -.3, color: widget.fg)),
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
        child: const Icon(CupertinoIcons.chevron_back, size: 17, color: TrackTheme.blue),
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
        children: [
          Expanded(
            child: Text(text.toUpperCase(),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: .4, color: TrackTheme.label3(dark))),
          ),
          if (trailing != null) trailing!,
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
        boxShadow: TrackTheme.cardShadow(dark),
        border: Border.all(color: dark ? Colors.white.withOpacity(.05) : Colors.black.withOpacity(.03), width: .5),
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
                  Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, letterSpacing: -.32, color: TrackTheme.label(dark))),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: TrackTheme.label3(dark))),
                    ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
            if (showChevron && onTap != null)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(CupertinoIcons.chevron_forward, size: 13, color: TrackTheme.label3(dark).withOpacity(.6)),
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
        boxShadow: TrackTheme.cardShadow(dark),
        border: Border.all(color: dark ? Colors.white.withOpacity(.05) : Colors.black.withOpacity(.03), width: .5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -.5, color: TrackTheme.label(dark))),
          const SizedBox(height: 3),
          Text(label.toUpperCase(),
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, letterSpacing: .1, color: TrackTheme.label3(dark))),
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
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent.withOpacity(dark ? .3 : .18), accent2.withOpacity(dark ? .22 : .12)],
        ),
        border: Border.all(color: accent.withOpacity(.18), width: .5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
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

/// ---------------------------------------------------------------------------
/// Long-press quick actions (iOS context menu, blurred + spring-scaled).
/// ---------------------------------------------------------------------------
Future<String?> showTrackContextMenu(
  BuildContext context,
  Offset globalPosition, {
  required List<List<Object>> items, // [label, IconData, isDestructive?]
}) {
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
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
      final dx = globalPosition.dx.clamp(12.0, size.width - 240);
      final dy = globalPosition.dy.clamp(70.0, size.height - 300);
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
                      borderRadius: BorderRadius.circular(14),
                      color: dark ? const Color(0xFF2C2C2E).withOpacity(.92) : Colors.white.withOpacity(.9),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(.28), blurRadius: 40, offset: const Offset(0, 16), spreadRadius: -8)],
                      border: Border.all(color: dark ? Colors.white.withOpacity(.07) : Colors.black.withOpacity(.05), width: .5),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
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
            ),
          ),
        ],
      );
    },
  );
}
