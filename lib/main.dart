import 'dart:async';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'config/app_environment.dart';
import 'config/design_system.dart';
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
import 'services/screen_time_service.dart';
import 'services/widget_bridge.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Draw edge-to-edge while leaving content responsible for SafeArea/insets.
  // Light system icons retain contrast against the dark default canvas.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
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

  // --- services that make steps/sleep/screen time zero-effort and keep the habit loop
  final notifications = NotificationService();
  final health = HealthService();
  final screenTime = ScreenTimeService();
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
    screenTime: screenTime,
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
  // Order matters, and this used to be the other way round. Loading the state is
  // what re-arms reminders — `recoverFocus()`, `syncFocusSchedules()` and the
  // tier/preference sync all call into `NotificationService`, and every one of its
  // methods returns early until `init()` has run. With `init()` last, a cold start
  // armed the three general reminders from the post-frame callback below but left
  // the user's *scheduled focus sessions* unarmed until they happened to edit one:
  // silently no reminder after every reboot, update, or reinstall.
  await notifications.init();
  await state.load();

  // A release build that is misconfigured (no verification backend, non-HTTPS
  // policy URLs) is a build-time problem, and the app's job here is only to not be
  // silent about it: the list is logged, and Settings → Diagnostics shows the same
  // list to whoever is looking. What this is NOT is a hard failure — a build with
  // no `TRACK_VERIFY_URL` is a legitimate free build, and crashing on a user's
  // phone for the operator's omission would be the worse bug. The gate that does
  // fail a build is `tools/release_gate.py` (structure/consistency rules, no
  // knowledge of these flags) plus the CI release job's guard on the defines.
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
      await state.refreshHealthPermission();
      // Only merges what the user has already granted; the permission sheet is
      // opened from Settings > Health Connect, deliberately. Pro-only: free users
      // see the gate rather than a silent no-op.
      if (state.canUseHealthSync && state.healthConnected) {
        await state.syncHealth();
        await notifications.syncStreakSaver(state);
      }
    } catch (_) {
      // No Health Connect, no problem.
    }

    // Usage Access screen-time sync: same silent, read-only pull for users who
    // granted Usage Access from the Screen time detail screen or Focus Lock.
    try {
      await state.refreshScreenTimePermission();
      if (state.screenTimeConnected) {
        await state.syncScreenTime();
      }
    } catch (_) {
      // No Usage Access or unsupported platform — manual logging stays unchanged.
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
        final icons = state.isDark ? Brightness.light : Brightness.dark;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
            statusBarIconBrightness: icons,
            systemNavigationBarIconBrightness: icons,
            statusBarBrightness: state.isDark ? Brightness.dark : Brightness.light,
          ),
          child: ChangeNotifierProvider<AppState>.value(
            value: state,
            child: MaterialApp(
              title: 'Track Pro',
              debugShowCheckedModeBanner: false,
              themeMode: state.isDark ? ThemeMode.dark : ThemeMode.light,
              theme: TrackTheme.light(),
              darkTheme: TrackTheme.dark(),
              // Keep scrolling quiet and platform-appropriate without overriding
              // Android's native physics or route transitions.
              scrollBehavior: const TrackScrollBehavior(),
              home: const HomeShell(),
            ),
          ),
        );
      },
    );
  }
}

/// Keeps edge effects restrained without overriding Android scrolling physics.
class TrackScrollBehavior extends MaterialScrollBehavior {
  const TrackScrollBehavior();

  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) => child;
}

/// ---------------------------------------------------------------------------
/// DESIGN TOKENS — solid Android-first dark surfaces and restrained orange accents.
/// ---------------------------------------------------------------------------
class TrackTheme {
  const TrackTheme._();

  // Compatibility names used by the established widgets. They all resolve to the
  // one orange product palette defined in `Editorial`; no screen carries its own
  // private blue platform colour system anymore.
  static const blue = Editorial.accent;
  static const indigo = Editorial.accentStrong;
  static const purple = Color(0xFFB77735);
  static const pink = Editorial.accentStrong;
  static const red = Editorial.danger;
  static const orange = Editorial.accent;
  static const yellow = Color(0xFFE0A44A);
  static const green = Editorial.full;
  static const mint = Editorial.full;
  static const teal = Editorial.full;
  static const cyan = Color(0xFF63A7C8);

  static Color bg(bool dark) => dark ? Editorial.canvas : const Color(0xFFF6F5F3);
  static Color surface(bool dark) => dark ? Editorial.surface : Colors.white;

  /// Kept for source compatibility with existing callers. It is intentionally an
  /// opaque surface now: frosted translucent layers made content and contrast
  /// depend on whatever happened to sit behind it.
  static Color surfaceGlass(bool dark) => surface(dark);

  static Color label(bool dark) => dark ? Editorial.ink : const Color(0xFF16120F);
  static Color label2(bool dark) => dark ? Editorial.inkSecondary : const Color(0xFF5D5650);
  static Color label3(bool dark) => dark ? Editorial.inkTertiary : const Color(0xFF817A73);
  static Color separator(bool dark) => dark ? Editorial.hairline : const Color(0xFFD7D1CA);
  static Color fill(bool dark) => dark ? Editorial.well : const Color(0xFFECE9E5);

  /// Surfaces are separated by a border, not decorative elevation. A low shadow
  /// remains only in light mode where otherwise adjacent white cards disappear.
  static List<BoxShadow> cardShadow(bool dark) => dark
      ? const <BoxShadow>[]
      : <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF101010).withOpacity(.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ];

  static const sheetShadow = <BoxShadow>[
    BoxShadow(color: Color(0x44000000), blurRadius: 22, offset: Offset(0, -4)),
  ];

  // Geometry follows the 20px-gutter / 16px-card-padding product rhythm.
  static const radiusCard = Editorial.rCard;
  static const radiusSheet = Editorial.rSheet;
  static const radiusPill = Editorial.rPill;

  static const spring = Cubic(.2, .8, .2, 1);
  static const easeOut = Cubic(.2, 0, 0, 1);
  static const sheetCurve = Cubic(.2, .8, .2, 1);

  static const _family = 'Inter';
  static const _fallbacks = <String>['Roboto', 'Noto Sans', 'sans-serif'];

  static ThemeData _base(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    TextStyle t(double size, FontWeight w, {double ls = 0, Color? color, double? height}) => TextStyle(
          fontFamily: _family,
          fontFamilyFallback: _fallbacks,
          fontSize: size,
          fontWeight: w,
          letterSpacing: ls,
          height: height,
          color: color ?? label(dark),
          decoration: TextDecoration.none,
        );

    final scheme = ColorScheme.fromSeed(
      seedColor: blue,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      platform: TargetPlatform.android,
      splashFactory: InkRipple.splashFactory,
      scaffoldBackgroundColor: bg(dark),
      colorScheme: scheme.copyWith(
        primary: blue,
        onPrimary: Colors.black,
        surface: surface(dark),
        onSurface: label(dark),
        outline: separator(dark),
      ),
      textTheme: TextTheme(
        displayLarge: t(34, FontWeight.w700, ls: -1.0, height: 1.1),
        titleLarge: t(22, FontWeight.w700, ls: -.5, height: 1.2),
        titleMedium: t(17, FontWeight.w600, ls: -.25, height: 1.25),
        bodyLarge: t(16, FontWeight.w400, ls: -.15, height: 1.4),
        bodyMedium: t(14, FontWeight.w400, ls: -.1, color: label2(dark), height: 1.4),
        labelLarge: t(15, FontWeight.w600, ls: -.1),
        labelSmall: t(11, FontWeight.w600, ls: .5, color: label3(dark)),
      ),
      dividerColor: separator(dark),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface(dark),
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusSheet)),
        ),
      ),
    );
  }

  static ThemeData light() => _base(Brightness.light);
  static ThemeData dark() => _base(Brightness.dark);

  /// Legacy helper retained for callers while rendering a solid, bordered card.
  /// The `blur` argument is purposely ignored so no backdrop blur leaks back into
  /// product surfaces through old call sites.
  static Widget frosted({
    required Widget child,
    required bool dark,
    double blur = 0,
    double radius = radiusCard,
    EdgeInsets? padding,
    bool strong = false,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
    BoxShadow? shadow,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: strong ? fill(dark) : surface(dark),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: separator(dark), width: .5),
            boxShadow: shadow == null ? cardShadow(dark) : <BoxShadow>[shadow],
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
