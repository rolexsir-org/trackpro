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
/// - **No surprise prompt.** Availability and authorization checks never open a
///   platform dialog. Only [requestPermissions], called from an explicit user
///   action after the in-app explanation, may call the platform request API.
///
/// `unavailable` and `denied` need different fixes and different copy: one is "install
/// Health Connect", the other is "grant the permission". Collapsing them into a single
/// "not connected" would put the wrong instruction in front of the user, and remembering
/// the answer from the last session would keep saying it after a revocation.
enum HealthPermissionState { unknown, unavailable, denied, granted }

class HealthService {
  HealthService({this.lookbackDays = 30, Health? health}) : _health = health ?? Health();

  final int lookbackDays;
  final Health _health;
  Future<void>? _configuration;
  bool _granted = false;

  static const List<HealthDataType> _types = [
    HealthDataType.STEPS,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.WEIGHT,
  ];

  static const List<HealthDataAccess> _readAccess = [
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
  ];

  bool get isAuthorized => _granted;

  /// The one place the OS is asked what the standing is. It uses the package's
  /// dedicated Health Connect SDK availability API before asking about a grant,
  /// so a permission-gated data read can never be mistaken for "not installed".
  Future<HealthPermissionState> permissionState() async {
    if (!await isAvailable()) {
      _granted = false;
      return HealthPermissionState.unavailable;
    }
    return await hasPermissions() ? HealthPermissionState.granted : HealthPermissionState.denied;
  }

  /// Health 13.x requires one configured [Health] instance. The same instance is
  /// retained for the application's lifetime, which also avoids a fresh instance
  /// forgetting a grant that the OS has already reported.
  Future<void> _ensureConfigured() async {
    _configuration ??= _health.configure();
    await _configuration;
  }

  /// A direct SDK check, not a permission-protected data probe. On Android 13 and
  /// below it distinguishes an absent/outdated Health Connect provider from a
  /// user who simply has not granted Track Pro access yet.
  Future<bool> isAvailable() async {
    try {
      await _ensureConfigured();
      return await _health.isHealthConnectAvailable();
    } catch (_) {
      return false;
    }
  }

  /// This is intentionally the *only* method that asks the platform to display
  /// the Health permission UI. Callers must have a contextual user gesture.
  Future<bool> requestPermissions() async {
    if (!await isAvailable()) {
      _granted = false;
      return false;
    }
    try {
      _granted = await _health.requestAuthorization(_types, permissions: _readAccess);
      return _granted;
    } catch (_) {
      _granted = false;
      return false;
    }
  }

  /// Checks the current OS grant and always brings the local cache into line.
  /// This is important after process recreation: a new service must not turn a
  /// pre-existing grant into an unsolicited request on the next automatic sync.
  Future<bool> hasPermissions() async {
    try {
      await _ensureConfigured();
      _granted = (await _health.hasPermissions(_types, permissions: _readAccess)) == true;
      return _granted;
    } catch (_) {
      _granted = false;
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
      final points = await _read([HealthDataType.SLEEP_ASLEEP], start, now);
      for (final p in _health.removeDuplicates(points)) {
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
      final points = await _read([HealthDataType.WEIGHT], start, now);
      final newest = <int, DateTime>{};
      for (final p in _health.removeDuplicates(points)) {
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
      final points = await _read([type], start, now);
      for (final p in _health.removeDuplicates(points)) {
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

  /// Health 13.x uses named query parameters. Keeping that API translation in one
  /// method makes every read follow the same configured-instance contract.
  Future<List<HealthDataPoint>> _read(List<HealthDataType> types, DateTime start, DateTime end) async {
    await _ensureConfigured();
    return _health.getHealthDataFromTypes(types: types, startTime: start, endTime: end);
  }

  /// `HealthDataPoint.value` has changed shape across plugin generations
  /// (`num` → `HealthValue` with `numericValue`). The current package uses the
  /// latter for numeric data, while this conversion remains deliberately narrow
  /// so an unfamiliar value becomes an omitted reading instead of invented data.
  double? _numeric(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    try {
      final dynamic dynamicValue = value;
      final dynamic nested = dynamicValue.numericValue;
      if (nested is num) return nested.toDouble();
    } catch (_) {
      // Not a numeric HealthValue — fall through to string parsing.
    }
    return double.tryParse('$value');
  }
}
