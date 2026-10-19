import 'dart:math' as math;

import 'package:track/data/db/database.dart';
import 'package:track/data/default_trackers.dart';
import 'package:track/util/day_key.dart';
import 'package:track/util/format.dart';

/// Synthetic history for **tests and development previews only**.
///
/// This lives under `test/` on purpose. Nothing in `lib/` may import it, so it
/// cannot be tree-shaken into a release binary and cannot seed a production
/// database: the compiler enforces the policy, not a code review.
///
/// It is deterministic (`Random(20261015)`) so a failing assertion is
/// reproducible across machines.
class DemoFixtures {
  DemoFixtures({math.Random? random}) : r = random ?? math.Random(20261015);

  final math.Random r;

  /// Days of history a fixture spans.
  static const int days = 28;

  /// Today's intended values, so a test can assert a specific ring.
  static const Map<String, double> todayValues = <String, double>{
    'water': 1750,
    'mood': 4,
    'expenses': 1240,
    'sleep': 7.3,
    'habits': 3,
    'calories': 1450,
    'steps': 6842,
    'period': 14,
    'screen': 312,
    'weight': 71.4,
  };

  /// A full `trackerId -> 28 days` projection, weekend-aware.
  Map<String, List<double>> history() {
    final out = <String, List<double>>{};
    for (final t in DefaultTrackers.all()) {
      out[t.id] = t.id == 'period' ? cycleHistory() : _series(t.id);
    }
    for (final id in todayValues.keys) {
      out[id]![days - 1] = todayValues[id]!;
    }
    return out;
  }

  List<double> _series(String id) {
    final out = <double>[];
    for (var i = days - 1; i >= 0; i--) {
      // Calendar arithmetic: the elapsed-time version can put two of these slots on the
      // same local day across a DST transition, which makes a fixture flaky in a timezone
      // the author does not live in. Same rule as `lib/util/day_key.dart`.
      final dow = weekdayOfDayKey(dayKeyFromToday(i)) % 7;
      final weekend = dow == 0 || dow == 6;
      final double v;
      switch (id) {
        case 'water':
          v = (jitter(r, weekend ? 2050 : 2350, 520) / 50).round() * 50;
        case 'mood':
          v = jitter(r, weekend ? 4.3 : 3.7, .9).round().clamp(1, 5).toDouble();
        case 'expenses':
          v = (jitter(r, weekend ? 1850 : 1120, 520) / 10).round() * 10;
        case 'sleep':
          v = (jitter(r, weekend ? 7.9 : 7.1, 1.0).clamp(4.5, 9.5).toDouble() * 10).round() / 10;
        case 'habits':
          v = jitter(r, weekend ? 3.4 : 4.0, 1.4).round().clamp(0, 3).toDouble();
        case 'calories':
          v = (jitter(r, 2050, 420) / 10).round() * 10;
        case 'steps':
          v = (jitter(r, weekend ? 9800 : 7600, 2600) / 10).round() * 10;
        case 'screen':
          v = (jitter(r, weekend ? 345 : 295, 70) / 5).round() * 5;
        case 'weight':
          v = ((74.2 - (days - 1 - i) * .1 + (r.nextDouble() * .5 - .25)) * 10).round() / 10;
        default:
          v = 0;
      }
      out.add(math.max(0, v));
    }
    return out;
  }

  /// Two logged cycles: a 5-day flow ending 13 days ago, plus the previous one.
  List<double> cycleHistory() {
    final out = List<double>.filled(days, 0);
    for (var i = 0; i < days; i++) {
      final ago = days - 1 - i;
      if (ago >= 13 && ago <= 17) out[i] = const [3, 3, 2, 2, 1][ago - 13].toDouble();
      if (ago >= 25 && ago <= days - 1) out[i] = const [3, 2, 2, 1, 1][ago - 25].toDouble();
    }
    return out;
  }

  /// Writes the whole fixture into a database — the only sanctioned way to get
  /// synthetic rows, and it is reachable only from tests.
  Future<void> writeInto(TrackDao dao, {String source = 'demo'}) async {
    final history = this.history();
    for (final t in DefaultTrackers.all()) {
      final values = history[t.id]!;
      await dao.replaceSeries(
        t.id,
        <int, double>{
          for (var i = 0; i < values.length; i++)
            dayKeyFromToday(values.length - 1 - i): values[i],
        },
        source: source,
      );
    }
  }
}
