import 'package:flutter/material.dart';

import '../main.dart' show Pressable, TrackTheme;
import '../services/haptics.dart';

/// The gold treatment. Used identically on the paywall CTA, the Pro chip and the
/// locked overlays, so "this is Pro" is a single visual language with one restrained
/// orange accent.
class ProPalette {
  const ProPalette._();

  static const gold = Color(0xFFFF7A18);
  static const goldDeep = Color(0xFFFF5A1F);
  static const goldText = Color(0xFF17110B);
  static const surface = Color(0xFF27190E);
}

/// Small "PRO" pill. Appears on locked rows, gated sections and the profile card.
class ProChip extends StatelessWidget {
  const ProChip({super.key, this.compact = false, this.label = 'PRO'});

  final bool compact;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8, vertical: compact ? 2 : 3),
      decoration: BoxDecoration(color: ProPalette.gold, borderRadius: BorderRadius.circular(7)),
      child: Text(
        label,
        style: TextStyle(
          fontSize: compact ? 9.5 : 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: .4,
          color: ProPalette.goldText,
        ),
      ),
    );
  }
}

/// A frosted lock overlay for a whole section.
///
/// The content stays *visible* underneath, blurred — you see the rings, the
/// chart, the rows — because a locked feature you can see is aspirational, and a
/// hidden one is just absent. The copy names the specific value, not "upgrade".
class ProGate extends StatelessWidget {
  const ProGate({
    super.key,
    required this.child,
    required this.locked,
    required this.title,
    required this.body,
    this.onUnlock,
    this.height,
    this.blur = 7,
    this.buttonLabel = 'Unlock with Pro',
  });

  final Widget child;
  final bool locked;
  final String title;
  final String body;
  final VoidCallback? onUnlock;
  final double? height;
  final double blur;
  final String buttonLabel;

  @override
  Widget build(BuildContext context) {
    if (!locked) return child;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(TrackTheme.radiusCard),
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // A solid veil keeps the gate readable without blurring content or
          // fabricating a glossy layer behind the lock message.
          IgnorePointer(child: Opacity(opacity: .32, child: child)),
          Positioned.fill(
            child: ColoredBox(color: dark ? Colors.black.withValues(alpha: .72) : Colors.white.withValues(alpha: .82)),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline_rounded, size: 15, color: ProPalette.gold),
                    const SizedBox(width: 6),
                    const ProChip(compact: true),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.4,
                    color: TrackTheme.label(dark),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                    color: TrackTheme.label2(dark),
                  ),
                ),
                const SizedBox(height: 14),
                _ProButton(label: buttonLabel, onTap: onUnlock, fullWidth: false),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A single locked row inside an otherwise-free list (e.g. the live "Add more
/// trackers" list, or history rows beyond day 7).
class ProLockedRow extends StatelessWidget {
  const ProLockedRow({
    super.key,
    required this.title,
    required this.subtitle,
    this.emoji = '🔒',
    this.onTap,
    this.accent = TrackTheme.blue,
  });

  final String title;
  final String subtitle;
  final String emoji;
  final VoidCallback? onTap;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Haptics.light();
        onTap?.call();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 29,
              height: 29,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: ProPalette.gold.withValues(alpha: .16),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(Icons.lock_outline_rounded, size: 16, color: ProPalette.gold),
            ),
            const SizedBox(width: 12),
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
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle,
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
            const ProChip(compact: true),
          ],
        ),
      ),
    );
  }
}

/// The gold CTA. Same component on the paywall, in gates and in Settings.
class _ProButton extends StatefulWidget {
  const _ProButton({required this.label, this.onTap, this.fullWidth = true, this.loading = false});

  final String label;
  final VoidCallback? onTap;
  final bool fullWidth;
  final bool loading;

  @override
  State<_ProButton> createState() => _ProButtonState();
}

class _ProButtonState extends State<_ProButton> {
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
              Haptics.commit();
              widget.onTap!();
            },
      child: AnimatedScale(
        scale: _down ? .97 : 1,
        duration: Duration(milliseconds: _down ? 110 : 300),
        curve: TrackTheme.spring,
        child: Container(
          constraints: BoxConstraints(minHeight: widget.fullWidth ? 54 : 42),
          width: widget.fullWidth ? double.infinity : null,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: ProPalette.gold,
            borderRadius: BorderRadius.circular(widget.fullWidth ? 16 : 12),
          ),
          child: widget.loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: ProPalette.goldText),
                )
              : Text(
                  widget.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: widget.fullWidth ? 17 : 14.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.3,
                    color: ProPalette.goldText,
                  ),
                ),
        ),
      ),
    );
  }
}

/// Public wrapper so screens can use the gold CTA without knowing the private
/// widget name.
class ProCtaButton extends StatelessWidget {
  const ProCtaButton({super.key, required this.label, this.onTap, this.loading = false});

  final String label;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) => _ProButton(label: label, onTap: onTap, loading: loading);
}

/// The "3 tracks left" style nudge. Sits inline in lists rather than interrupting
/// with a sheet: the meter is honest and the CTA is one tap away.
class ProUsageMeter extends StatelessWidget {
  const ProUsageMeter({
    super.key,
    required this.used,
    required this.limit,
    required this.onUpgrade,
    this.unit = 'trackers',
  });

  final int used;
  final int limit;
  final VoidCallback onUpgrade;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final atLimit = used >= limit;
    final progress = limit <= 0 ? 1.0 : (used / limit).clamp(0.0, 1.0).toDouble();

    return Container(
      padding: const EdgeInsets.fromLTRB(15, 13, 15, 14),
      decoration: BoxDecoration(
        color: TrackTheme.surface(dark),
        borderRadius: BorderRadius.circular(TrackTheme.radiusCard),
        boxShadow: TrackTheme.cardShadow(dark),
        border: Border.all(color: atLimit ? ProPalette.gold.withValues(alpha: .5) : Colors.transparent, width: .5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Free plan',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: TrackTheme.label(dark)),
              ),
              const SizedBox(width: 8),
              const ProChip(compact: true, label: 'FREE'),
              const Spacer(),
              Text(
                '$used of $limit $unit',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: atLimit ? ProPalette.goldDeep : TrackTheme.label2(dark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              children: [
                Container(height: 7, color: TrackTheme.fill(dark)),
                FractionallySizedBox(
                  widthFactor: progress,
                  child: Container(
                    height: 7,
                    decoration: BoxDecoration(color: atLimit ? ProPalette.gold : TrackTheme.blue),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              Expanded(
                child: Text(
                  atLimit
                      ? 'You have filled the free plan. Pro removes the ceiling.'
                      : '${limit - used} $unit left on the free plan. Pro makes it unlimited.',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                    color: TrackTheme.label2(dark),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Pressable(
                onTap: onUpgrade,
                child: const ProChip(label: 'UPGRADE'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
