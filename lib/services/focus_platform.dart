/// The bridge to the Android side of Focus Lock, plus the honest fallback for
/// every platform that is not Android.
///
/// Everything the feature does that Android has to provide crosses this file:
///
///  * **permission state**, read fresh rather than cached — the user can revoke
///    usage access from system settings while a session is running, and a cached
///    "granted" would turn into a false claim that something was blocked;
///  * **installed apps**, for the picker;
///  * **the enforcement service**, started with the packages to cover and stopped
///    when the session ends;
///  * **the monotonic clock**, `SystemClock.elapsedRealtime()`, which is the only
///    clock a countdown can be trusted to.
///
/// The design rule this file encodes: *absence is not success*. When the channel is
/// missing (a unit test, a non-Android build, a stripped build), every method
/// reports the capability as unavailable and [FocusEnforcer.startSession] returns
/// false. Nothing here ever returns "blocked" because it could not find out.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// What the device has actually granted, right now.
class FocusPermissions {
  const FocusPermissions({
    this.usageAccess = false,
    this.overlay = false,
    this.notifications = false,
    this.batteryOptimised = false,
  });

  /// `PACKAGE_USAGE_STATS` — the user-granted "Usage access" app-op. Without it
  /// the app cannot tell which app came to the front, so there is nothing to
  /// block and nothing to verify.
  final bool usageAccess;

  /// "Display over other apps" (`SYSTEM_ALERT_WINDOW`). Without it there is no way
  /// to cover a blocked app at all.
  final bool overlay;

  /// POST_NOTIFICATIONS. Not required for blocking, but the ongoing notification
  /// is how a foreground service stays visible and stoppable, so a session without
  /// it is offered less often.
  final bool notifications;

  /// True when Android may still throttle Track Pro in the background. Offered as a
  /// suggestion, never as a requirement — and never presented as "you must do
  /// this or blocking will not work", because that would be a claim we cannot back.
  final bool batteryOptimised;

  /// Both permissions that blocking genuinely requires.
  bool get canBlock => usageAccess && overlay;

  /// What is missing, in the order worth fixing — the wire names, for logic.
  List<String> get missingForBlocking => <String>[if (!usageAccess) 'usageAccess', if (!overlay) 'overlay'];

  /// The same list in the words the system settings use, for the UI. The raw
  /// identifiers used to be printed in Settings and in the setup sheet, which is a
  /// sentence written for whoever wrote the channel, not for the person reading it.
  String get missingForBlockingLabel =>
      <String>[if (!usageAccess) 'Usage access', if (!overlay) 'Display over other apps'].join(' and ');

  static const FocusPermissions none = FocusPermissions();
}

/// A snapshot of the native enforcement service.
class FocusNativeState {
  const FocusNativeState({
    this.running = false,
    this.blocking = false,
    this.startedAtRealtimeMs = 0,
    this.endsAtRealtimeMs = 0,
    this.blockedAttempts = 0,
    this.overlayShows = 0,
    this.detectionEvents = 0,
    this.usageAccess = false,
    this.overlay = false,
    this.foregroundPackage,
    this.usageReportingSeen = false,
  });

  final bool running;

  /// Whether the service is *attempting* to block (mode is blocking/deep and both
  /// permissions were granted when it started). Attempting is not achieving: the
  /// evidence lives in [detectionEvents].
  final bool blocking;

  final int startedAtRealtimeMs;
  final int endsAtRealtimeMs;

  /// Times a selected app was brought to the front, and times Android accepted a
  /// coverage-panel launch for it. A selected-app opening is not itself proof that
  /// a panel appeared, so the two counters stay separate.
  final int blockedAttempts;
  final int overlayShows;

  /// Foreground-app events the monitor reported. Together with [overlayShows], this
  /// separates healthy-but-unproven `armed` enforcement from `verified` coverage.
  final int detectionEvents;

  final bool usageAccess;
  final bool overlay;

  /// The last package the monitor saw, for the session screen's honest
  /// "this device reported X" line. Package id only.
  final String? foregroundPackage;

  /// Whether the platform has produced any usage event since the service started.
  /// On devices where usage reporting does not work (there is a known Android 14
  /// behaviour where it returns nothing), this stays false and the session is
  /// reported as unverified rather than quietly counted as blocked.
  final bool usageReportingSeen;

  static const FocusNativeState idle = FocusNativeState();
}

/// One launchable app, for the picker.
class FocusAppInfo {
  const FocusAppInfo({required this.packageName, required this.label, this.protectedFromBlocking = false});

  final String packageName;
  final String label;

  /// True for apps Track Pro will never cover (dialer, launcher, system UI, keyboards,
  /// itself) — shown greyed in the picker with the reason, rather than hidden.
  final bool protectedFromBlocking;
}

/// The contract the repository and the state layer depend on.
///
/// Abstract so the whole feature can be exercised in a plain `flutter test` with a
/// fake, and so a non-Android build degrades to a timer instead of a crash.
abstract class FocusEnforcer {
  /// Whether a real native implementation is present. False on iOS, in unit
  /// tests, and in any build where the overlay is unavailable — in which case the
  /// app offers Standard focus only and says why.
  Future<bool> get isAvailable;

  Future<FocusPermissions> permissions();

  /// The platform's monotonic clock in milliseconds, or null when it cannot be
  /// read. Null is meaningful: the caller records `timingVerified = false` rather
  /// than pretending the wall clock is a stopwatch.
  Future<int?> monotonicMs();

  Future<FocusNativeState> state();

  /// Starts enforcement. Returns false when the service refused or could not be
  /// started — never true "because the call did not throw".
  Future<bool> startSession({
    required String sessionId,
    required String mode,
    required int plannedMinutes,
    required int endsAtRealtimeMs,
    required List<String> packages,
    required bool block,
    required String label,
    required int accentArgb,
  });

  Future<void> stopSession();

  Future<List<FocusAppInfo>> installedApps();

  /// Packages that must never be blocked on this device, resolved from the
  /// system's own defaults (launcher, dialer, SMS, assist) rather than guessed.
  Future<Set<String>> protectedPackages();

  Future<void> openUsageAccessSettings();
  Future<void> openOverlaySettings();
  Future<void> openNotificationSettings();
  Future<void> openBatterySettings();
}

/// The real implementation: one method channel, no assumptions.
class MethodChannelFocusEnforcer implements FocusEnforcer {
  MethodChannelFocusEnforcer({MethodChannel? channel}) : _channel = channel ?? const MethodChannel('track/focus');

  final MethodChannel _channel;
  bool? _present;
  bool _warned = false;

  @override
  Future<bool> get isAvailable async {
    final cached = _present;
    if (cached != null) return cached;
    try {
      final result = await _channel.invokeMethod<Object?>('probe');
      _present = result is Map && result['android'] == true && result['focusChannel'] == true;
    } on MissingPluginException {
      _present = false;
    } on PlatformException {
      _present = false;
    } catch (_) {
      _present = false;
    }
    if (_present == false && !_warned) {
      _warned = true;
      debugPrint(
        'FocusEnforcer: the track/focus channel is not present on this build. '
        'Focus Lock will offer timer sessions only and will not claim any blocking.',
      );
    }
    return _present!;
  }

  @override
  Future<FocusPermissions> permissions() async {
    final map = await _method<Map<Object?, Object?>>('permissions');
    if (map == null) return FocusPermissions.none;
    return FocusPermissions(
      usageAccess: map['usageAccess'] == true,
      overlay: map['overlay'] == true,
      notifications: map['notifications'] == true,
      batteryOptimised: map['batteryOptimised'] == true,
    );
  }

  @override
  Future<int?> monotonicMs() async {
    final value = await _method<Object?>('elapsedRealtime');
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }

  @override
  Future<FocusNativeState> state() async {
    final map = await _method<Map<Object?, Object?>>('state');
    if (map == null) return FocusNativeState.idle;
    return FocusNativeState(
      running: map['running'] == true,
      blocking: map['blocking'] == true,
      startedAtRealtimeMs: _int(map['startedAtRealtimeMs']),
      endsAtRealtimeMs: _int(map['endsAtRealtimeMs']),
      blockedAttempts: _int(map['blockedAttempts']),
      overlayShows: _int(map['overlayShows']),
      detectionEvents: _int(map['detectionEvents']),
      usageAccess: map['usageAccess'] == true,
      overlay: map['overlay'] == true,
      foregroundPackage: map['foregroundPackage'] as String?,
      usageReportingSeen: map['usageReportingSeen'] == true,
    );
  }

  @override
  Future<bool> startSession({
    required String sessionId,
    required String mode,
    required int plannedMinutes,
    required int endsAtRealtimeMs,
    required List<String> packages,
    required bool block,
    required String label,
    required int accentArgb,
  }) async {
    final started = await _method<bool>('start', <String, Object?>{
      'sessionId': sessionId,
      'mode': mode,
      'plannedMinutes': plannedMinutes,
      'endsAtRealtimeMs': endsAtRealtimeMs,
      'packages': packages,
      'block': block,
      'label': label,
      'accent': accentArgb,
    });
    return started ?? false;
  }

  @override
  Future<void> stopSession() async {
    await _method<void>('stop');
  }

  @override
  Future<List<FocusAppInfo>> installedApps() async {
    final list = await _method<List<Object?>>('apps');
    if (list == null) return const <FocusAppInfo>[];
    final out = <FocusAppInfo>[];
    for (final raw in list) {
      if (raw is Map) {
        final pkg = raw['package'] as String?;
        if (pkg == null || pkg.isEmpty) continue;
        out.add(
          FocusAppInfo(
            packageName: pkg,
            label: (raw['label'] as String?)?.trim().isNotEmpty == true ? raw['label'] as String : pkg,
            protectedFromBlocking: raw['protected'] == true,
          ),
        );
      }
    }
    return out;
  }

  @override
  Future<Set<String>> protectedPackages() async {
    final list = await _method<List<Object?>>('protected');
    if (list == null) return const <String>{};
    return {
      for (final value in list)
        if (value is String && value.isNotEmpty) value,
    };
  }

  @override
  Future<void> openUsageAccessSettings() => _open('openUsageAccess');

  @override
  Future<void> openOverlaySettings() => _open('openOverlay');

  @override
  Future<void> openNotificationSettings() => _open('openNotifications');

  @override
  Future<void> openBatterySettings() => _open('openBattery');

  Future<void> _open(String method) async {
    try {
      await _channel.invokeMethod<void>(method);
    } catch (e) {
      // A settings screen that cannot be opened must not break the app: the user
      // can always reach it from system Settings, and the sheet says so.
      debugPrint('FocusEnforcer.$method failed: $e');
    }
  }

  Future<T?> _method<T>(String name, [Map<String, Object?>? args]) async {
    try {
      return await _channel.invokeMethod<T>(name, args);
    } on MissingPluginException {
      return null;
    } on PlatformException catch (e) {
      debugPrint('FocusEnforcer.$name platform error: ${e.code}');
      return null;
    } catch (e) {
      debugPrint('FocusEnforcer.$name failed: $e');
      return null;
    }
  }

  static int _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }
}

/// Used off Android and in tests. Reports every capability as absent and refuses to
/// start enforcement, so a build without the native side offers exactly what it can
/// honestly deliver: a timer, with no claim about other apps.
class NoFocusEnforcer implements FocusEnforcer {
  const NoFocusEnforcer();

  @override
  Future<bool> get isAvailable async => false;

  @override
  Future<FocusPermissions> permissions() async => FocusPermissions.none;

  @override
  Future<int?> monotonicMs() async => null;

  @override
  Future<FocusNativeState> state() async => FocusNativeState.idle;

  @override
  Future<bool> startSession({
    required String sessionId,
    required String mode,
    required int plannedMinutes,
    required int endsAtRealtimeMs,
    required List<String> packages,
    required bool block,
    required String label,
    required int accentArgb,
  }) async => false;

  @override
  Future<void> stopSession() async {}

  @override
  Future<List<FocusAppInfo>> installedApps() async => const <FocusAppInfo>[];

  @override
  Future<Set<String>> protectedPackages() async => const <String>{};

  @override
  Future<void> openUsageAccessSettings() async {}

  @override
  Future<void> openOverlaySettings() async {}

  @override
  Future<void> openNotificationSettings() async {}

  @override
  Future<void> openBatterySettings() async {}
}
