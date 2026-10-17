import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'config/app_environment.dart';
import 'data/db/database.dart';
import 'data/commitment_repository.dart';
import 'data/entry_repository.dart';
import 'data/focus_repository.dart';
import 'screens/home_shell.dart';
import 'services/billing_service.dart';
import 'services/haptics.dart';
import 'services/focus_platform.dart';
import 'services/health_service.dart';
import 'services/notification_service.dart';
import 'services/pro_analytics.dart';
import 'services/widget_bridge.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Edge-to-edge with transparent system bars — the iOS look depends on the app
  // owning the full canvas and drawing its own status-bar safe areas.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
  ));

  // --- storage: SQLite via Drift, one connection for the app's lifetime ------
  final database = TrackDatabase();
  final repo = EntryRepository(database);
  // Habits live in their own repository: a tracker answers "how much", a commitment
  // answers "did you", and mixing the two would make both harder to reason about.
  final commitmentRepo = CommitmentRepository(database);

  // Focus Lock. The enforcer is the ONLY door to the platform: `MethodChannelFocus-
  // Enforcer` returns null/false for every call the device cannot answer, and the
  // repository treats "no answer" as "no enforcement" — never as success. Nothing in
  // this feature can report an app as blocked on the strength of an absent channel.
  final focusRepo = FocusRepository(
    db: database,
    enforcer: MethodChannelFocusEnforcer(),
  );

  // --- services that make steps/sleep zero-effort and keep the habit loop ----
  final notifications = NotificationService();
  final health = HealthService();
  final widgetBridge = WidgetBridge();

  // --- monetisation: Play Billing + the funnel it feeds ----------------------
  // Nothing here can grant Pro on its own. `HttpPurchaseVerifier` asks the
  // deployed `/billing/verify` backend, which validates the token with the Play
  // Developer API; without a configured endpoint there is no verifier at all and
  // purchases stay pending. See MONETIZATION.md §4.1 and ../billing_server/OPERATIONS.md.
  final analytics = ProAnalytics(database);

  // Verification is the only thing that can grant Pro. Production points at the
  // deployed backend (`--dart-define=TRACK_VERIFY_URL=…`); with no URL
  // configured, purchases are verified nowhere and Pro stays locked — which is
  // the honest outcome, and the reason `HttpPurchaseVerifier` fails closed.
  final billing = BillingService(
    analytics: analytics,
    // Null verifier when no endpoint is configured: `BillingService` then reports
    // "nothing to ask" and Pro is not granted. A dev build may inject
    // `LocalOnlyVerifier()` explicitly; it throws in release builds.
    verifier: AppEnvironment.hasVerifyBackend
        ? HttpPurchaseVerifier(
            endpoint: Uri.parse(AppEnvironment.verifyUrl),
            timeout: AppEnvironment.verifyTimeout,
          )
        : null,
    packageName: _packageName,
    environmentLabel: kReleaseMode ? 'production' : 'debug',
  );

  // Probe the native haptics channel off the critical path, so the very first
  // tap is instant instead of paying for the probe.
  unawaited(Haptics.warmUp());

  final state = AppState(
    repo: repo,
    commitmentRepo: commitmentRepo,
    focusRepo: focusRepo,
    health: health,
    notifications: notifications,
    widgetBridge: widgetBridge,
    billing: billing,
    analytics: analytics,
    packageName: _packageName,
  );

  // A fresh install writes tracker DEFINITIONS and nothing else: the entry
  // tables stay empty until the user (or Health Connect) records something.
  //
  // There is no seeder seam here any more, and that is the point. The previous
  // build could inject `DemoSeed.install` behind a `--dart-define`; a single
  // mis-set flag would have shipped 28 days of invented history to real users.
  // `EntryRepository.bootstrap()` now takes no seeder at all, so the production
  // start-up path has nothing to inject and nothing to forget. Synthetic rows
  // exist only as fixtures under `test/`.
  await state.load();
  await notifications.init();

  // A release build that is misconfigured (demo data compiled in, no verification
  // backend, non-HTTPS legal URLs) is a build-time problem, but the app should be
  // able to tell you so rather than silently misbehaving. `AppEnvironment.validate()`
  // is also enforced by `tools/release_gate.py`, which fails the build.
  if (kReleaseMode) {
    final problems = AppEnvironment.validate();
    if (problems.isNotEmpty) {
      debugPrint('Track Pro release configuration problems: ${problems.join(' | ')}');
    }
  }

  // Resume hook: a subscription can expire, be refunded or be cancelled while the
  // app is backgrounded, so entitlement is re-evaluated on every foreground.
  final lifecycle = _TrackLifecycle(state);
  WidgetsBinding.instance.addObserver(lifecycle);

  runApp(TrackApp(state: state));

  // Post-first-frame work, deliberately off the critical path.
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    // Billing last, and never blocking the first frame: the cached entitlement
    // has already painted the correct tier.
    await billing.init(cached: state.entitlement);
    await state.reconcileEntitlement();

    // One scheduler for all three reminders, honouring tier *and* the switches
    // in Settings — scheduling straight from here would ignore a user who turned
    // the daily check-in off.
    await state.syncReminders();
    await widgetBridge.writeSnapshot(state);

    // Health Connect sync: silent, read-only, and it never overwrites anything
    // the user typed. Steps/Sleep/Weight wake up populated instead of blank.
    try {
      // Only merges what the user has already granted; the permission sheet is
      // opened from Settings > Health Connect, deliberately. Pro-only: free users
      // see the gate rather than a silent no-op.
      if (state.canUseHealthSync && await health.isAvailable() && await health.hasPermissions()) {
        await state.syncHealth();
        await notifications.syncStreakSaver(state);
      }
    } catch (_) {
      // No Health Connect, no problem.
    }
  });
}

/// Application id, used for Play Billing queries and the manage-subscription
/// deep link. Kept in one place so the overlay's `build.gradle` and the Dart side
/// cannot drift apart.
const String _packageName = 'com.track.app';

/// Foreground transitions are the only reliable moment to re-check a
/// subscription: Android can suspend the process mid-trial and Play will not
/// push anything until the app asks.
class _TrackLifecycle with WidgetsBindingObserver {
  _TrackLifecycle(this.state);

  final AppState state;

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.resumed) {
      unawaited(state.onResumed());
    }
  }
}

class TrackApp extends StatelessWidget {
  const TrackApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        // `AppState` is provided here, once, above the whole app: every screen reads
        // it with `context.watch<AppState>()`. (This was missing — `provider` was a
        // declared dependency and eleven screens called `context.watch`, but nothing
        // ever put an AppState into the tree. The release gate now checks for it,
        // see P-20 in tools/release_gate.py.)
        return ChangeNotifierProvider<AppState>.value(
          value: state,
          child: MaterialApp(
            title: 'Track Pro',
            debugShowCheckedModeBanner: false,
            themeMode: state.isDark ? ThemeMode.dark : ThemeMode.light,
            theme: TrackTheme.light(),
            darkTheme: TrackTheme.dark(),
            // iOS page transitions (parallax push + edge-swipe back) on Android too.
            scrollBehavior: const IosScrollBehavior(),
            home: const HomeShell(),
          ),
        );
      },
    );
  }
}

/// Kills Android's Material overscroll glow/ripple and swaps in iOS-style
/// rubber-band physics. Without this the app instantly reads as "an Android app
/// wearing iOS clothes".
class IosScrollBehavior extends MaterialScrollBehavior {
  const IosScrollBehavior();

  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) => child;

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
}

/// ---------------------------------------------------------------------------
/// DESIGN TOKENS — Apple HIG values, translated 1:1.
/// ---------------------------------------------------------------------------
class TrackTheme {
  // iOS system palette
  static const blue = Color(0xFF007AFF);
  static const indigo = Color(0xFF5856D6);
  static const purple = Color(0xFFAF52DE);
  static const pink = Color(0xFFFF2D55);
  static const red = Color(0xFFFF3B30);
  static const orange = Color(0xFFFF9500);
  static const yellow = Color(0xFFFFCC00);
  static const green = Color(0xFF34C759);
  static const mint = Color(0xFF00C7BE);
  static const teal = Color(0xFF30B0C7);
  static const cyan = Color(0xFF32ADE6);

  static Color bg(bool dark) => dark ? const Color(0xFF000000) : const Color(0xFFF2F2F7);
  static Color surface(bool dark) => dark ? const Color(0xFF1C1C1E) : Colors.white;
  static Color surfaceGlass(bool dark) =>
      dark ? const Color(0xFF1C1C1E).withOpacity(.72) : Colors.white.withOpacity(.72);
  static Color label(bool dark) => dark ? Colors.white : Colors.black;
  static Color label2(bool dark) => dark ? const Color(0xFFEBEBF5).withOpacity(.6) : const Color(0xFF3C3C43).withOpacity(.6);
  static Color label3(bool dark) => dark ? const Color(0xFFEBEBF5).withOpacity(.3) : const Color(0xFF3C3C43).withOpacity(.3);
  static Color separator(bool dark) =>
      dark ? const Color(0xFF545458).withOpacity(.65) : const Color(0xFF3C3C43).withOpacity(.13);
  static Color fill(bool dark) =>
      dark ? const Color(0xFF787880).withOpacity(.24) : const Color(0xFF787880).withOpacity(.12);

  // iOS light shadow: barely-there, wide, low opacity — never Material elevation.
  static List<BoxShadow> cardShadow(bool dark) => dark
      ? [BoxShadow(color: Colors.black.withOpacity(.55), blurRadius: 26, offset: const Offset(0, 12))]
      : [
          BoxShadow(color: const Color(0xFF101828).withOpacity(.05), blurRadius: 22, offset: const Offset(0, 8)),
          BoxShadow(color: const Color(0xFF101828).withOpacity(.03), blurRadius: 2, offset: const Offset(0, 1)),
        ];

  static const sheetShadow = [
    BoxShadow(color: Color(0x33000000), blurRadius: 60, offset: Offset(0, -12)),
  ];

  // Geometry
  static const radiusCard = 16.0;
  static const radiusSheet = 22.0;
  static const radiusPill = 999.0;

  // Motion — Apple's own curves
  static const spring = Cubic(.34, 1.56, .64, 1);
  static const easeOut = Cubic(.22, 1, .36, 1);
  static const sheetCurve = Cubic(.32, .72, 0, 1);

  /// SF Pro first (if you hold an Apple licence and uncomment it in
  /// pubspec.yaml), then the bundled Inter, then whatever the device ships.
  static const _family = 'Inter';
  static const _fallbacks = <String>['SFProDisplay', 'SF Pro Display', 'Roboto', '.SF Pro Display'];

  static ThemeData _base(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    TextStyle t(double size, FontWeight w, {double ls = 0, Color? color, double? height}) => TextStyle(
          fontFamily: _family,
          fontFamilyFallback: _fallbacks,
          fontSize: size,
          fontWeight: w,
          letterSpacing: ls,
          height: height,
          color: color ?? TrackTheme.label(dark),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      // Force iOS platform so every Material widget we do use falls back to
      // Cupertino behaviour + motion.
      platform: TargetPlatform.iOS,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      scaffoldBackgroundColor: bg(dark),
      colorScheme: ColorScheme.fromSeed(seedColor: blue, brightness: brightness),
      textTheme: TextTheme(
        displayLarge: t(34, FontWeight.w700, ls: -.7),
        titleLarge: t(22, FontWeight.w700, ls: -.5),
        titleMedium: t(17, FontWeight.w600, ls: -.41),
        bodyLarge: t(16, FontWeight.w400, ls: -.32),
        bodyMedium: t(14, FontWeight.w400, ls: -.15, color: label2(dark)),
        labelLarge: t(15, FontWeight.w600, ls: -.2),
        labelSmall: t(11, FontWeight.w600, ls: .4, color: label3(dark)),
      ),
      dividerColor: separator(dark),
      cupertinoOverrideTheme: CupertinoThemeData(brightness: brightness, applyThemeToAll: true),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      }),
    );
  }

  static ThemeData light() => _base(Brightness.light);
  static ThemeData dark() => _base(Brightness.dark);

  /// The signature frosted-glass surface: blurred backdrop + saturated tint.
  static Widget frosted({
    required Widget child,
    required bool dark,
    double blur = 24,
    double radius = radiusCard,
    EdgeInsets? padding,
    bool strong = false,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
    BoxShadow? shadow,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: strong ? surfaceGlass(dark) : (dark ? surface(dark).withOpacity(.86) : Colors.white.withOpacity(.8)),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withOpacity(dark ? .06 : .5), width: .5),
            boxShadow: shadow == null ? cardShadow(dark) : [shadow],
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Spring-y press feedback: scale down on press, overshoot on release, with the
/// shared haptic vocabulary attached so nothing in the app feels inert.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = .962,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (!mounted) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        _set(true);
        Haptics.light();
      },
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress == null
          ? null
          : () {
              Haptics.hold();
              widget.onLongPress!();
            },
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: Duration(milliseconds: _down ? 120 : 340),
        curve: TrackTheme.spring,
        child: widget.child,
      ),
    );
  }
}
