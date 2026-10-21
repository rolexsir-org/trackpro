import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../util/day_key.dart';

/// Usage Access screen-time readings, and the honest shape of "not available".
///
/// The Screen time tracker has always accepted typed values; this service is the
/// optional auto-fill behind Android's "Usage access" grant. The design rule is
/// the same one `focus_platform.dart` encodes: **absence is never success.**
/// A missing channel, a revoked grant, an OEM that reports nothing — all of them
/// come back as "no reading", and the tracker behaves exactly as it did before
/// (manual entry), rather than charting zeros that would claim the user never
/// touched their phone.
///
/// What crosses the channel is two facts, and only two: how many minutes the
/// screen was in the foreground per local day, and (for today) which packages
/// those minutes belonged to. No usage *events*, no launch times, no content —
/// and nothing is stored beyond the user's own tracker rows, which carry
/// `source: 'usage'` so a typed value always wins.
enum ScreenTimePermissionState {
  /// The channel has not been asked yet (or the platform is not Android).
  unknown,

  /// No Android usage-stats capability in this build — Linux desktop, tests.
  unavailable,

  /// Android is present but "Usage access" is not granted (or was revoked).
  denied,

  /// The grant is held right now. Re-read on every resume; grants get revoked.
  granted,
}

/// One app's share of today's screen time.
class ScreenTimeAppUsage {
  const ScreenTimeAppUsage({required this.packageName, required this.label, required this.minutes});

  final String packageName;
  final String label;
  final double minutes;

  @override
  String toString() => 'ScreenTimeAppUsage($packageName, $minutes min)';
}

class ScreenTimeService {
  ScreenTimeService({MethodChannel? channel}) : _channel = channel ?? const MethodChannel('track/screen_time');

  final MethodChannel _channel;

  /// Bounded on purpose: 14 days is what the tracker's chart shows, and a wider
  /// window is not worth a bigger query on a cold device.
  static const int defaultLookbackDays = 14;

  static const int maxLookbackDays = 90;

  /// True when a native implementation answered the probe. Cached after the
  /// first call, like the focus enforcer.
  Future<bool> get isAvailable async {
    final cached = _present;
    if (cached != null) return cached;
    final result = await _method<Object?>('probe');
    _present = result is Map && result['android'] == true && result['screenTimeChannel'] == true;
    return _present!;
  }

  bool? _present;

  /// The one place the OS is asked what the standing is *right now*. Never
  /// cached across calls: a grant revoked in system settings must show up as
  /// revoked the moment the app comes back to the foreground.
  Future<ScreenTimePermissionState> permissionState() async {
    if (!await isAvailable) return ScreenTimePermissionState.unavailable;
    final map = await _method<Map<Object?, Object?>>('permission');
    if (map == null) return ScreenTimePermissionState.unavailable;
    return map['usageAccess'] == true ? ScreenTimePermissionState.granted : ScreenTimePermissionState.denied;
  }

  /// Opens Android's "Usage access" settings screen. A false return means the
  /// OEM build has no such screen — the calling UI always names the manual path
  /// ("Settings → Apps → Special access → Usage access") as well.
  Future<bool> openUsageAccessSettings() async {
    final ok = await _method<bool>('openUsageAccess');
    return ok ?? false;
  }

  /// Foreground minutes per local day (`yyyymmdd` keys), oldest first, covering
  /// the last [days] days including today. Empty when there is no grant.
  Future<Map<int, double>> dailyMinutes({int days = defaultLookbackDays}) async {
    final bounded = days.clamp(1, maxLookbackDays).toInt();
    final raw = await _method<List<Object?>>('dailyMinutes', {'days': bounded});
    return parseDailyMinutes(raw, now: DateTime.now(), days: bounded);
  }

  /// Today's per-app split, most-used first. Empty when there is no grant.
  Future<List<ScreenTimeAppUsage>> todayByApp({int limit = 6}) async {
    final raw = await _method<List<Object?>>('todayByApp', {'limit': limit});
    return parseTodayByApp(raw, limit: limit);
  }

  // ------------------------------------------------------- pure conversions
  /// Channel payload → `dayKey → minutes`. Pure, so the rules are testable
  /// without a device:
  ///
  ///  * a `day` outside the requested window is dropped (a stale bucket from an
  ///    OEM edge must not land in the chart);
  ///  * minutes are clamped to `(0, 1440]` — the same bound the tracker's
  ///    storage enforces — and non-finite values are dropped, never stored;
  ///  * duplicate days are summed, then clamped again: the platform is allowed
  ///    to split a day into more than one bucket.
  static Map<int, double> parseDailyMinutes(Object? raw, {required DateTime now, int days = defaultLookbackDays}) {
    if (raw is! List) return const <int, double>{};
    // Calendar arithmetic, never `Duration` subtraction: on a 23- or 25-hour day
    // the elapsed-time shortcut lands one row off (see `day_key.dart`).
    final windowStart = shiftDayKey(dayKey(now), -(days - 1));
    final windowEnd = dayKey(now);
    final summed = <int, double>{};
    for (final entry in raw) {
      if (entry is! Map) continue;
      final day = entry['day'];
      final minutes = entry['minutes'];
      if (day is! int) continue;
      if (minutes is! num) continue;
      final value = minutes.toDouble();
      if (!value.isFinite || value <= 0) continue;
      if (day < windowStart || day > windowEnd) continue;
      summed[day] = (summed[day] ?? 0) + value;
    }
    return {for (final e in summed.entries) e.key: e.value.clamp(0, 1440.0).toDouble()};
  }

  /// Channel payload → today's per-app list. Pure: unknown shapes are dropped
  /// rather than throwing, labels fall back to the package name (which is what
  /// the Kotlin side already does), and the list is capped to [limit] entries
  /// most-used first.
  static List<ScreenTimeAppUsage> parseTodayByApp(Object? raw, {int limit = 6}) {
    if (raw is! List) return const <ScreenTimeAppUsage>[];
    final out = <ScreenTimeAppUsage>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      final pkg = entry['package'];
      if (pkg is! String || pkg.isEmpty) continue;
      final minutes = entry['minutes'];
      if (minutes is! num) continue;
      final value = minutes.toDouble();
      if (!value.isFinite || value <= 0) continue;
      final label = entry['label'];
      out.add(
        ScreenTimeAppUsage(
          packageName: pkg,
          label: label is String && label.trim().isNotEmpty ? label.trim() : pkg,
          minutes: value.clamp(0, 1440.0).toDouble(),
        ),
      );
    }
    out.sort((a, b) => b.minutes.compareTo(a.minutes));
    return out.take(limit.clamp(0, 25).toInt()).toList();
  }

  Future<T?> _method<T>(String name, [Map<String, Object?>? args]) async {
    try {
      return await _channel.invokeMethod<T>(name, args);
    } on MissingPluginException {
      _present = false;
      return null;
    } on PlatformException catch (e) {
      debugPrint('ScreenTimeService.$name platform error: ${e.code}');
      return null;
    } catch (e) {
      debugPrint('ScreenTimeService.$name failed: $e');
      return null;
    }
  }
}
