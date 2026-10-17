import 'package:health/health.dart';

import '../data/db/database.dart';

/// Health Connect bridge (HealthKit on iOS, Google Fit on older Android).
///
/// Steps, sleep and weight become *zero-effort* trackers: the cheapest possible
/// path to a user's second tracker, because they wake up already populated.
///
/// Rules that make this safe to ship:
/// - **Read-only.** Track Pro never writes to the health store.
/// - **Manual wins.** Merged per (tracker, day); anything the user typed for
///   that day is never overwritten (enforced in EntryRepository).
/// - **Bounded windows.** 30 days per pull, so first sync is fast and the
///   post-reinstall catch-up is complete but not unbounded.
/// - **Failures are silent.** No Health Connect, permission denied, OEM
///   weirdness — the app behaves exactly as it did before.
/// What Health Connect actually says, asked rather than remembered.
///
/// `unavailable` and `denied` need different fixes and different copy: one is "install
/// Health Connect", the other is "grant the permission". Collapsing them into a single
/// "not connected" would put the wrong instruction in front of the user, and remembering
/// the answer from the last session would keep saying it after a revocation.
enum HealthPermissionState { unknown, unavailable, denied, granted }

class HealthService {
  HealthService({this.lookbackDays = 30});

  final int lookbackDays;

  final HealthFactory _factory = HealthFactory(useHealthConnectIfAvailable: true);
  bool _granted = false;

  static const List<HealthDataType> _types = [
    HealthDataType.STEPS,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.WEIGHT,
  ];

  bool get isAuthorized => _granted;

  /// The one place the OS is asked what the standing is. Probes availability first,
  /// because on Android 13 and below Health Connect is a separate app and "not
  /// installed" is a different state from "not granted".
  Future<HealthPermissionState> permissionState() async {
    if (!await isAvailable()) return HealthPermissionState.unavailable;
    if (await hasPermissions()) {
      _granted = true;
      return HealthPermissionState.granted;
    }
    return HealthPermissionState.denied;
  }

  /// Probe: Health Connect may not be installed (it is a separate system app on
  /// Android 13 and below). A one-minute read is the cheapest reliable check.
  Future<bool> isAvailable() async {
    try {
      final now = DateTime.now();
      await _factory.getHealthDataFromTypes(now.subtract(const Duration(minutes: 1)), now, [HealthDataType.STEPS]);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestPermissions() async {
    try {
      _granted = await _factory.requestAuthorization(
        _types,
        permissions: const [HealthDataAccess.READ, HealthDataAccess.READ, HealthDataAccess.READ],
      );
      return _granted;
    } catch (_) {
      _granted = false;
      return false;
    }
  }

  Future<bool> hasPermissions() async {
    try {
      return await _factory.hasPermissions(_types);
    } catch (_) {
      return false;
    }
  }

  /// Total steps per local day, keyed yyyymmdd.
  ///
  /// Steps arrive as many small samples (a sensor tick every few minutes), so
  /// this is a sum per day. Dedupe matters: phone **and** watch both writing
  /// steps is the classic double-count.
  Future<Map<int, double>> dailySteps({int? days}) =>
      _perDaySum(HealthDataType.STEPS, days ?? lookbackDays, round: true);

  /// Hours slept per night, attributed to the **waking** day — that is how
  /// people read "last night's sleep" and how the platforms report it.
  Future<Map<int, double>> dailySleep({int? days}) async {
    final n = days ?? lookbackDays;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).subtract(Duration(days: n + 1));
    final out = <int, double>{};
    try {
      final points = await _factory.getHealthDataFromTypes(start, now, [HealthDataType.SLEEP_ASLEEP]);
      for (final p in HealthFactory.removeDuplicates(points)) {
        if (p.type != HealthDataType.SLEEP_ASLEEP) continue;
        final hours = p.dateTo.difference(p.dateFrom).inMinutes / 60.0;
        if (hours <= 0 || hours > 16) continue; // naps and bad data
        final wake = dayKey(p.dateTo);
        out[wake] = (out[wake] ?? 0) + hours;
      }
    } catch (_) {
      return {};
    }
    return {
      for (final e in out.entries) e.key: (e.value * 100).roundToDouble() / 100,
    };
  }

  /// Latest weight per day. A body weight is a snapshot, not a sum — summing it
  /// would be a hilarious bug.
  Future<Map<int, double>> dailyWeight({int? days}) async {
    final n = days ?? lookbackDays;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).subtract(Duration(days: n));
    final out = <int, double>{};
    try {
      final points = await _factory.getHealthDataFromTypes(start, now, [HealthDataType.WEIGHT]);
      final newest = <int, DateTime>{};
      for (final p in HealthFactory.removeDuplicates(points)) {
        if (p.type != HealthDataType.WEIGHT) continue;
        final kg = _numeric(p.value);
        if (kg == null || kg <= 0) continue;
        final key = dayKey(p.dateTo);
        final seen = newest[key];
        if (seen == null || p.dateTo.isAfter(seen)) {
          newest[key] = p.dateTo;
          out[key] = kg;
        }
      }
    } catch (_) {
      return {};
    }
    return out;
  }

  Future<Map<int, double>> _perDaySum(HealthDataType type, int days, {required bool round}) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).subtract(Duration(days: days));
    final out = <int, double>{};
    try {
      final points = await _factory.getHealthDataFromTypes(start, now, [type]);
      for (final p in HealthFactory.removeDuplicates(points)) {
        if (p.type != type) continue;
        final v = _numeric(p.value);
        if (v == null) continue;
        final key = dayKey(p.dateFrom);
        out[key] = (out[key] ?? 0) + v;
      }
    } catch (_) {
      return {};
    }
    return {
      for (final e in out.entries) e.key: round ? e.value.roundToDouble() : e.value,
    };
  }

  /// `HealthDataPoint.value` has changed shape across plugin generations
  /// (`num` → `HealthValue` with `numericValue`). Probing at runtime keeps this
  /// compiling and working across both without pinning the app to one version.
  double? _numeric(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    try {
      final dynamic dynamicValue = value;
      final dynamic nested = dynamicValue.numericValue;
      if (nested is num) return nested.toDouble();
    } catch (_) {
      // Not a HealthValue — fall through to string parsing.
    }
    return double.tryParse('$value');
  }
}
