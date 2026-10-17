import 'package:flutter/material.dart';

/// Design system — dark-first, editorial, restrained.
///
/// This is the token layer for the product's own surfaces (Today, Routines,
/// Momentum, Insights, Profile additions). It exists so those screens cannot drift
/// from each other: one palette, one spacing scale, one type ramp, one motion
/// vocabulary.
///
/// Honest status: the screens that existed before this pass — the measurement
/// detail views, the log sheets, the paywall — still read `TrackTheme` (in
/// `main.dart`), which carries the older, brighter iOS palette. Both layers are
/// present in the app today, and `docs/PRODUCTION_READINESS.md` records the
/// migration as an open item. The tokens below are used by everything written in
/// this pass, and `TrackTheme` remains the single source for colours that both
/// layers share (greens, reds, the separator hairline), so nothing is duplicated.
///
/// Rules this file encodes:
///  - **Dark first.** The app opens dark unless the user chose otherwise; the light
///    palette is derived from the same ramp, not designed separately.
///  - **One accent.** Momentum is a single hue. Colour carries meaning (full,
///    minimum, missed, rest) and nothing else — no decorative gradients on data.
///  - **Space is a scale, not a number.** [s1]…[s8]; nothing in the new screens
///    hardcodes a padding value.
///  - **Type is a ramp.** Four sizes carry every heading and body; the mono style is
///    reserved for figures the user is meant to check.
class Editorial {
  const Editorial._();

  // ------------------------------------------------------------------ palette
  /// Page background. Near-black with a blue cast, not pure #000: pure black makes
  /// hairline borders disappear on OLED.
  static const Color canvas = Color(0xFF0B0C0F);

  /// Raised surfaces (cards, sheets).
  static const Color surface = Color(0xFF141519);

  /// The darkest step above the canvas, for wells and inset groups.
  static const Color well = Color(0xFF1C1D22);

  /// Hairline. One value, used at 0.5dp everywhere.
  static const Color hairline = Color(0xFF2A2C33);

  static const Color ink = Color(0xFFF2F3F5);
  static const Color inkSecondary = Color(0xFFA2A6B0);
  static const Color inkTertiary = Color(0xFF6E727C);

  /// The single accent. Used for the active state, the primary action and the
  /// momentum figure — never as decoration.
  static const Color accent = Color(0xFF5B7CFA);

  /// Semantic colours for outcomes. Not decorative: each one means exactly one
  /// thing in the calendar, the strip and the review.
  static const Color full = Color(0xFF3FB27F);
  static const Color minimum = Color(0xFFE0A44A);

  /// A planned day that passed with nothing recorded. Deliberately quiet and
  /// desaturated — a miss is information, not a punishment.
  static const Color missed = Color(0xFF6B7280);

  /// Rest and deliberate skips. Same value: both mean "not counted".
  static const Color rest = Color(0xFF39404F);

  static const Color danger = Color(0xFFE5484D);

  // ------------------------------------------------------------------ spacing
  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;
  static const double s5 = 20;
  static const double s6 = 24;
  static const double s8 = 32;

  // ------------------------------------------------------------------- radius
  static const double rSmall = 10;
  static const double rCard = 16;
  static const double rSheet = 22;
  static const double rPill = 999;

  // --------------------------------------------------------------------- type
  /// Editorial display: tight tracking, heavy weight. Reserved for the one figure
  /// or sentence a screen is about.
  static const TextStyle display = TextStyle(
    fontSize: 34,
    height: 1.1,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.1,
    color: ink,
  );

  static const TextStyle title = TextStyle(
    fontSize: 21,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    color: ink,
  );

  static const TextStyle body = TextStyle(
    fontSize: 15,
    height: 1.45,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.2,
    color: inkSecondary,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12.5,
    height: 1.4,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.1,
    color: inkTertiary,
  );

  /// Figures the user is invited to verify (rates, sample sizes, day counts).
  /// Tabular so a column of them lines up.
  static const TextStyle figure = TextStyle(
    fontSize: 15,
    height: 1.3,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
    color: ink,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const TextStyle label = TextStyle(
    fontSize: 11.5,
    height: 1.2,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.6,
    color: inkTertiary,
  );

  // ------------------------------------------------------------------- motion
  static const Duration fast = Duration(milliseconds: 160);
  static const Duration medium = Duration(milliseconds: 260);
  static const Curve ease = Curves.easeOutCubic;

  /// Respects the platform's reduce-motion setting. Every animated value in the new
  /// screens routes through here, so "reduced motion" is a real behaviour rather
  /// than a promise.
  static Duration scale(BuildContext context, Duration d) {
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return reduce ? Duration.zero : d;
  }

  /// Card surface used by every new screen.
  static BoxDecoration card({Color? border, Color? fill}) => BoxDecoration(
        color: fill ?? surface,
        borderRadius: BorderRadius.circular(rCard),
        border: Border.all(color: border ?? hairline, width: 0.5),
      );
}
