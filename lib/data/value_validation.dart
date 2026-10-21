import '../models/models.dart';

/// Plausibility bounds per tracker.
///
/// Storage is the last line of defence: a chart is only as trustworthy as the
/// worst value in it, and a single `NaN`, `-40`, or a steps reading of 10^9
/// (seen in the wild from broken wearable syncs) poisons every average, streak
/// and 28-day trend downstream. Everything that writes goes through
/// [ValueValidation.sanitize].
class ValueValidation {
  const ValueValidation._();

  /// Inclusive `[min, max]` accepted for a tracker id.
  static (double min, double max) boundsFor(String trackerId) => switch (trackerId) {
    'water' => (0, 20000), // 20 L; above that it is a typo or an IV drip
    'mood' => (0, 5),
    'expenses' => (0, 1000000),
    'sleep' => (0, 24),
    'calories' => (0, 20000),
    'steps' => (0, 200000),
    'screen' => (0, 1440),
    'weight' => (0, 500),
    'period' => (0, 10), // flow intensity / cycle-day marker
    _ => (0, 1e9),
  };

  /// Fallback when only the metric kind is known (adding a tracker later).
  static (double min, double max) boundsForKind(MetricKind kind) => switch (kind) {
    MetricKind.volume => (0, 20000),
    MetricKind.mood => (0, 5),
    MetricKind.money => (0, 1000000),
    MetricKind.hours => (0, 24),
    MetricKind.calories => (0, 20000),
    MetricKind.steps => (0, 200000),
    MetricKind.minutes => (0, 1440),
    MetricKind.weight => (0, 500),
    MetricKind.cycle => (0, 10),
    MetricKind.habits => (0, 50),
  };

  /// Returns the value to store, or `null` when it must be rejected outright.
  ///
  /// Rejection (rather than clamping) applies to non-finite and negative input:
  /// silently turning -5 cups into 0 would hide a bug in whatever produced it.
  /// Out-of-range-but-finite values are clamped, because a user typing 250000 ml
  /// meant "a lot", not "reject my entry".
  static double? sanitize(String trackerId, double value) {
    if (!value.isFinite) return null;
    if (value < 0) return null;
    final (min, max) = boundsFor(trackerId);
    return value.clamp(min, max).toDouble();
  }

  /// True when [value] had to be adjusted to be storable.
  static bool wasClamped(String trackerId, double value) {
    if (!value.isFinite || value < 0) return true;
    final (min, max) = boundsFor(trackerId);
    return value < min || value > max;
  }

  /// Guards a chart's inputs: drops anything unstorable, so a legacy bad row
  /// cannot derail an average.
  static List<double> sanitizeSeries(String trackerId, Iterable<double> values) => [
    for (final v in values) sanitize(trackerId, v) ?? 0,
  ];
}
