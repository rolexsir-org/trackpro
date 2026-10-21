import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../data/db/database.dart';

/// Monetisation funnel events, written to SQLite.
///
/// Why local SQLite rather than a third-party SDK: these events are small, the
/// app is offline-first, and "how many people saw the paywall and how many
/// finished a trial" is answerable with a `GROUP BY` — no SDK, no ATT prompt, no
/// new privacy disclosure. Ship the heavy analytics later, once the funnel is
/// worth instrumenting properly.
///
/// The funnel these events describe:
///
///   paywall_viewed → plan_selected → purchase_started → purchase_completed
///                                     ↘ purchase_canceled / purchase_error
///
/// with `trigger` on every event, because *where* the paywall appeared (tracker
/// limit, insights lock, soft prompt after a streak) moves conversion more than
/// the paywall's own copy does.
class ProAnalytics {
  ProAnalytics(this.db);

  final TrackDatabase db;

  static const Set<String> funnel = {
    'paywall_viewed',
    'plan_selected',
    'purchase_started',
    'purchase_pending',
    'purchase_completed',
    'purchase_canceled',
    'purchase_error',
    'restore_started',
    'restore_completed',
    'trial_started',
    'paywall_dismissed',
    'manage_opened',
    'pro_gate_tapped',
    'soft_prompt_shown',
    'soft_prompt_dismissed',
  };

  void log(String name, [Map<String, Object?>? meta]) {
    if (!funnel.contains(name)) {
      debugPrint('ProAnalytics: "$name" is not a defined funnel event');
    }
    // Fire and forget: analytics must never delay a tap or break a purchase.
    db.trackDao
        .logTrackEvent(name, meta == null ? null : jsonEncode(meta))
        .catchError((Object e) => debugPrint('ProAnalytics write failed: $e'));
  }

  /// Conversion snapshot for the debug build / a future "why upgrade?" screen.
  Future<Map<String, int>> counts({int days = 30}) async {
    final rows = await db.trackDao.eventCounts(days: days);
    return {for (final r in rows) r.name: r.count};
  }

  /// The number that matters: views → completed purchases.
  Future<double> viewToPurchaseRate({int days = 30}) async {
    final c = await counts(days: days);
    final views = c['paywall_viewed'] ?? 0;
    final bought = c['purchase_completed'] ?? 0;
    if (views == 0) return 0;
    return bought / views;
  }

  static const String trialConversionQuery = r'''
-- Trial → paid, the metric that decides whether the plan is priced right.
-- Called from the backend once RTDN is wired; kept here as the contract.
SELECT
  COUNT(*) FILTER (WHERE name = 'trial_started')  AS trials,
  COUNT(*) FILTER (WHERE name = 'purchase_completed'
                     AND json_extract(meta, '$.trial') = 0) AS conversions
FROM track_events
WHERE name IN ('trial_started', 'purchase_completed');
''';

  static const String hardPaywallSkewQuery = r'''
-- Which trigger converts, so the paywall can be moved to where it earns.
SELECT
  json_extract(meta, '$.trigger') AS trigger,
  COUNT(*) FILTER (WHERE name = 'paywall_viewed')       AS views,
  COUNT(*) FILTER (WHERE name = 'purchase_completed')   AS purchases,
  ROUND(1.0 * COUNT(*) FILTER (WHERE name = 'purchase_completed')
        / MAX(1, COUNT(*) FILTER (WHERE name = 'paywall_viewed')), 3) AS rate
FROM track_events
GROUP BY 1
ORDER BY rate DESC;
''';
}

/// Decodes a funnel event's `meta` blob. Used by support tooling and the
/// conversion queries below.
Map<String, Object?> decodeEventMeta(String? raw) {
  if (raw == null) return const {};
  try {
    return (jsonDecode(raw) as Map).cast<String, Object?>();
  } catch (_) {
    return const {};
  }
}
