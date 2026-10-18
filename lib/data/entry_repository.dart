import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';

import '../config/app_environment.dart';
import '../util/day_key.dart';
import 'cycle_stats.dart';
import 'db/database.dart';
import 'default_trackers.dart';
import 'value_validation.dart';
import '../models/models.dart';

/// One stored day, as the history list needs it: which day, what value, and where
/// the value came from. `source` is what lets the sheet say "synced from Health" or
/// "you logged this" instead of guessing.
typedef RecordedDay = ({int day, double value, String source});

/// What actually happened during start-up, so the UI (and the tests) can assert
/// on it instead of guessing.
class BootstrapReport {
  const BootstrapReport({
    required this.createdTrackers,
    required this.trackerCount,
    required this.entryCount,
    required this.integrityOk,
  });

  /// True when this start-up wrote the tracker catalogue for the first time —
  /// i.e. a genuinely fresh install.
  final bool createdTrackers;
  final int trackerCount;

  /// Rows in `daily_entries` + `events`. **Zero on a genuinely fresh install** —
  /// that is the assertion the demo-data removal turns on.
  final int entryCount;
  final bool integrityOk;

  bool get isFreshInstall => entryCount == 0;
}

/// The single seam between the app and storage.
///
/// - **Writes** go straight to SQLite (rollup + event row in one transaction),
///   after passing [ValueValidation].
/// - **Reads** for the dashboard/charts come from a 90-day in-memory projection,
///   hydrated once at launch and patched per write, so scrolling stays at 60fps.
/// - **Aggregates** (category totals, streaks, averages, export) are SQL.
///
/// Provenance rule, repeated because it is the one that matters: rows written
/// here carry the `source` of whoever produced them, and `demo` rows are never
/// treated as the user's own data anywhere in the app.
class EntryRepository {
  EntryRepository(this.db);

  final TrackDatabase db;
  TrackDao get dao => db.trackDao;

  static const int cacheDays = 90;

  /// The dashboard's design window. A named constant, not a side effect of the
  /// demo fixture that used to define it.
  static const int dashboardDays = 28;

  final Map<String, List<double>> _cache = {};
  DateTime _lastHydrate = DateTime.fromMillisecondsSinceEpoch(0);

  /// Day → completed habit indices, hydrated from `daily_entries.meta`.
  final Map<int, List<int>> habitCompletions = {};

  int get windowDays => dashboardDays;

  Map<String, List<double>> get cache => _cache;
  DateTime get lastHydrate => _lastHydrate;

  int _todaySlot() => cacheDays - 1;

  // ---------------------------------------------------------------- bootstrap
  /// Opens the DB, writes tracker **definitions** if there are none, then
  /// hydrates the read cache.
  ///
  /// **This method has no seeder parameter, on purpose.** Every row that ever
  /// exists in a user's database is one they created, or Health Connect read on
  /// their behalf. Synthetic history lives in `test/fixtures/`, which `lib/`
  /// cannot import, so "did a dev build ship invented data?" is answered by the
  /// compiler rather than by a code review. `tools/release_gate.py` P-01/P-15
  /// checks the same invariant statically.
  Future<BootstrapReport> bootstrap() async {
    final created = await ensureDefaultTrackers();
    await hydrate();
    return BootstrapReport(
      createdTrackers: created,
      trackerCount: await dao.trackerCount(),
      entryCount: await dao.entryCount(),
      integrityOk: await isHealthy(),
    );
  }

  /// Writes the tracker catalogue if the database has no trackers yet.
  ///
  /// Definitions only — `daily_entries` and `events` stay empty. The three
  /// trackers the free tier covers ship enabled; the rest exist as addable
  /// catalogue entries.
  Future<bool> ensureDefaultTrackers() async {
    if (await dao.trackerCount() > 0) return false;
    final all = DefaultTrackers.all();
    await dao.upsertAllTrackers([
      for (var i = 0; i < all.length; i++)
        _trackerRow(
          all[i],
          sort: i,
          hidden: !DefaultTrackers.enabledByDefault.contains(all[i].id),
        ),
    ]);
    return true;
  }

  Future<void> hydrate() async {
    _cache.clear();
    for (final t in await dao.allTrackers()) {
      _cache[t.id] = ValueValidation.sanitizeSeries(t.id, await dao.series(t.id, days: cacheDays));
    }
    habitCompletions
      ..clear()
      ..addAll(await _loadHabitCompletions());
    _lastHydrate = DateTime.now();
  }

  /// The per-habit checklist history. Stored inside the `habits` tracker's daily
  /// `meta` so it is exported, deleted and backed up with everything else.
  Future<Map<int, List<int>>> _loadHabitCompletions() async {
    final rows = await dao.dailyRowsFor('habits', days: cacheDays);
    final out = <int, List<int>>{};
    for (final r in rows) {
      final indices = decodeHabitMeta(r.meta);
      if (indices != null) out[r.day] = indices;
    }
    return out;
  }

  // ------------------------------------------------------------------ writes
  /// Absolute daily value (water, mood, sleep, weight…).
  ///
  /// Returns false when the value was unstorable and nothing was written — the
  /// caller can then tell the user rather than pretending it saved.
  Future<bool> setDaily(String trackerId, double value, {String source = 'manual', String? meta}) async {
    final safe = ValueValidation.sanitize(trackerId, value);
    if (safe == null) return false;
    final now = DateTime.now();
    await dao.upsertDaily(trackerId: trackerId, day: dayKey(now), value: safe, source: source, meta: meta, at: now);
    _patch(trackerId, _todaySlot(), safe);
    if (trackerId == 'habits') {
      // The checklist itself travels inside the row's meta, so one write keeps
      // the value, the checklist history and the export in step.
      final indices = decodeHabitMeta(meta);
      if (indices != null) habitCompletions[dayKey(now)] = indices;
    }
    _lastHydrate = now;
    return true;
  }

  /// Increment that also belongs in the event feed (a cup, a snack, a payment).
  /// One increment in the event feed **and** the day's new rollup, in one
  /// transaction, so the feed and the ring cannot disagree.
  ///
  /// [delta] may be negative — it is the change that was actually applied, which is
  /// how "remove a cup" is expressible at all. The bound that matters is on
  /// [newDailyTotal], because that is the number every average, streak and ring is
  /// computed from; a non-finite delta is still refused outright.
  Future<bool> addEvent(
    String trackerId,
    double delta,
    double newDailyTotal, {
    String source = 'manual',
    String? meta,
  }) async {
    final safeTotal = ValueValidation.sanitize(trackerId, newDailyTotal);
    if (safeTotal == null || !delta.isFinite) return false;
    final now = DateTime.now();
    await dao.logEvent(
      trackerId: trackerId,
      newDailyTotal: safeTotal,
      delta: delta,
      source: source,
      meta: meta,
      at: now,
    );
    _patch(trackerId, _todaySlot(), safeTotal);
    _lastHydrate = now;
    return true;
  }

  /// Health Connect / Usage Access merge. Precedence manual > usage > health >
  /// demo, enforced per (tracker, day) so a sync never clobbers something the
  /// user typed, and a re-run never double-counts (the same day upserts onto the
  /// same (tracker, day, source) row).
  ///
  /// [source] names the origin to store: `'health'` for Health Connect pulls,
  /// `'usage'` for Android Usage Access screen-time pulls. Both are "the device
  /// told us"; only the label differs, and the label is what lets the UI say
  /// where a value came from.
  Future<int> mergeHealthSeries(String trackerId, Map<int, double> byDay, {String source = 'health'}) async {
    var written = 0;
    final today = DateTime.now();
    for (final e in byDay.entries) {
      final safe = ValueValidation.sanitize(trackerId, e.value);
      if (safe == null) continue; // a broken wearable reading is not a data point

      final sources = await dao.sourcesForDay(trackerId, e.key);
      if (sources.contains('manual')) continue;

      // A day left over from a development build's sample data must not block the
      // user's real Health Connect history from landing. The sample row is
      // **deleted** — the previous implementation re-wrote it with the health
      // value under `source: 'demo'`, which left the day double-counted: one real
      // row, one row the app still reported as "not yours" in Diagnostics.
      //
      // No shipped code writes `demo` rows any more, so this only affects installs
      // upgraded from an old dev build.
      if (sources.contains('demo')) {
        await dao.deleteDailyFor(trackerId, e.key, source: 'demo');
      }
      await dao.upsertDaily(trackerId: trackerId, day: e.key, value: safe, source: source, at: today);
      written++;
      final slot = _slotForDay(e.key);
      if (slot >= 0 && slot < cacheDays) _patch(trackerId, slot, safe);
    }
    if (written > 0) _lastHydrate = DateTime.now();
    return written;
  }


  /// The days this tracker actually has a record for, newest first.
  ///
  /// This exists because the UI's history list was rendering the *gap-filled* series:
  /// a day the user never logged showed up as `0`, indistinguishable from a logged
  /// zero, and every row was captioned with the tracker's marketing blurb instead of
  /// its record. A history screen has to be built from rows, not from a projection
  /// that fills holes.
  ///
  /// [limit] bounds the query; the caller passes the visible window.
  Future<List<RecordedDay>> recordedDays(String trackerId, {int limit = 30}) async {
    final rows = await dao.dailyRowsFor(trackerId, days: limit);
    final out = <RecordedDay>[
      for (final r in rows) (day: r.day, value: r.value, source: r.source),
    ];
    out.sort((a, b) => b.day.compareTo(a.day));
    return out;
  }

  /// Writes a value onto a specific day — not just today.
  ///
  /// The log sheets only ever wrote the current day, so a value entered on the wrong
  /// day, or a reading corrected a day later, could not be fixed at all. This is the
  /// write behind the edit sheet. It is transactional in effect (one day, one row,
  /// upserted) and re-derives the cache slot so no screen keeps showing the old value.
  Future<bool> setDayValue(String trackerId, int day, double value, {String source = 'manual', String? meta}) async {
    final safe = ValueValidation.sanitize(trackerId, value);
    if (safe == null) return false;
    final now = DateTime.now();
    await db.transaction(() async {
      await dao.upsertDaily(trackerId: trackerId, day: day, value: safe, source: source, meta: meta, at: now);
    });
    _patchDay(trackerId, day, safe);
    _lastHydrate = now;
    return true;
  }

  /// Removes the record for one day, leaving the day *empty* rather than zero.
  ///
  /// Deleting is not the same as logging 0: a zero is a reading, absence is not. The
  /// row is deleted so streaks, averages and rings recompute from what is actually
  /// there — which is the behaviour the brief asks for and the one a person expects
  /// when they undo a mistake.
  Future<int> clearDay(String trackerId, int day) async {
    final removed = await db.transaction(() async {
      // Every source, not just the manual one: see
      // [TrackDao.deleteDailyForAllSources] for the day that used to survive this.
      final daily = await dao.deleteDailyForAllSources(trackerId, day);
      final events = await dao.deleteEventsForDay(trackerId, day);
      return daily + events;
    });
    if (removed > 0) {
      // The cache slot is a projection of the rows, not a row itself: after a delete
      // the slot is cleared so the ring, the streak and the average read the absence.
      // (One write, formerly two — a `_patchDay(…, 0)` immediately followed by
      // `_clearSlot(…)` that set the same slot to the same zero.)
      _clearSlot(trackerId, day);
      _lastHydrate = DateTime.now();
    }
    return removed;
  }

  /// Writes a value into the loaded cache slot for a given day, when that day is
  /// inside the window. Outside the window there is nothing cached to correct, and the
  /// next `hydrate` picks the row up.
  void _patchDay(String trackerId, int day, double value) {
    final slot = _slotForDay(day);
    if (slot >= 0 && slot < cacheDays) _patch(trackerId, slot, value);
  }

  void _clearSlot(String trackerId, int day) {
    final series = _cache[trackerId];
    if (series == null) return;
    final slot = _slotForDay(day);
    if (slot >= 0 && slot < cacheDays) series[slot] = 0;
  }

  /// The cache slot for a calendar day: the last slot is today, and each earlier
  /// local day steps back by one.
  ///
  /// `daysBetweenKeys` is calendar arithmetic on purpose (see `util/day_key.dart`):
  /// a millisecond-based day count is off by one on a 23- or 25-hour day, which
  /// would patch yesterday's slot with today's value — a ring that looks updated
  /// and a chart claiming a day the user never logged.
  int _slotForDay(int day) => cacheDays - 1 - daysBetweenKeys(day, todayKey());

  Future<void> persistTracker(Tracker t, int sort) => dao.upsertTracker(_trackerRow(t, sort: sort));

  Future<void> persistGoal(String id, double goal) => dao.setGoal(id, goal);

  Future<void> persistHidden(String id, bool hidden) => dao.setHidden(id, hidden);

  Future<void> persistOrder(List<Tracker> ordered) async {
    await db.transaction(() async {
      for (var i = 0; i < ordered.length; i++) {
        await dao.setSort(ordered[i].id, i);
      }
    });
  }

  /// Deletes the user's entries but keeps their tracker configuration. Used by
  /// the destructive "delete my data" flow, which must not silently restore
  /// anything afterwards.
  Future<Map<String, int>> deleteAllUserData({bool keepTrackerDefinitions = true}) async {
    final removed = await dao.deleteAllUserData();
    if (!keepTrackerDefinitions) await dao.deleteTrackersAll();
    _cache.clear();
    habitCompletions.clear();
    await hydrate();
    return removed;
  }

  Future<int> deleteDemoRows() async {
    final n = await dao.deleteDemoRows();
    await hydrate();
    return n;
  }

  Future<List<SourceCount>> sourceCounts() => dao.entryCountBySource();

  Future<int> demoRowCount() => dao.demoRowCount();

  /// SQLite's own integrity verdict plus a foreign-key sweep.
  Future<bool> isHealthy() async {
    try {
      final verdict = await dao.integrityCheck();
      if (verdict.toLowerCase() != 'ok') return false;
      return await dao.foreignKeyViolationCount() == 0;
    } catch (_) {
      return false;
    }
  }

  // ------------------------------------------------------------------- reads
  /// The expense categories the app can colour, and their colours.
  ///
  /// One source of truth: the chart reads its colours from here and the write path
  /// validates its category against it, so a typo can never create a grey, unlabelled
  /// slice that nobody can explain. (`'Food & dining'` is kept for rows written by
  /// older builds; new ones use `'Food'`.)
  static const Map<String, int> categoryPalette = <String, int>{
    'Food': 0xFFFF9500,
    'Food & dining': 0xFFFF9500,
    'Groceries': 0xFF34C759,
    'Transport': 0xFF007AFF,
    'Shopping': 0xFFAF52DE,
    'Bills': 0xFF5856D6,
    'Fun': 0xFFFF2D55,
    'Health': 0xFF00C7BE,
    'Other': 0xFF8E8E93,
  };

  Future<List<CategoryTotal>> categoryTotals({int days = 7}) async {
    final sums = await dao.categoryTotals(days: days);
    return [
      for (final s in sums)
        if (s.total > 0) CategoryTotal(s.category, s.total, Color(categoryPalette[s.category] ?? 0xFF34C759)),
    ];
  }

  Future<List<Transaction>> recentTransactions({int limit = 5}) async {
    final rows = await dao.recentEvents('expenses', limit: limit);
    return [
      for (final r in rows)
        Transaction(
          _metaOf(r.meta, 'title') ?? 'Expense',
          _metaOf(r.meta, 'category') ?? 'Other',
          r.value,
          _relativeTime(r.ts),
        ),
    ];
  }

  /// The calorie log, from the event table — what was actually eaten/added.
  Future<List<FoodEntry>> recentFoodEntries({int limit = 20}) async {
    final rows = await dao.recentEvents('calories', limit: limit);
    return [
      for (final r in rows)
        FoodEntry(
          _metaOf(r.meta, 'title') ?? 'Calories',
          _metaOf(r.meta, 'emoji') ?? '🍽️',
          r.value,
          _relativeTime(r.ts),
          r.source,
        ),
    ];
  }

  /// Per-day activity rhythm from real events only. An empty result means the
  /// UI must say "not enough entries", not draw a fake curve.
  ///
  /// The bucket width is **derived from [buckets]** so the bars always tile a whole
  /// day. The signature used to take `buckets` and `bucketHours` separately, and the
  /// one call site asked for 6 × 3 h = 18 hours: every event after 18:00 was clamped
  /// into a bar labelled "6pm–9pm" that actually held 6pm–midnight, so the busiest
  /// part of the day for water, calories and screen time was drawn at half its true
  /// width and the evening label lied about what it covered.
  Future<RhythmBuckets> rhythm(String trackerId, {int buckets = 8, DateTime? day}) async {
    final target = day ?? DateTime.now();
    final events = await dao.eventsForDay(trackerId, dayKey(target));
    final width = buckets <= 0 ? 24 : (24 ~/ buckets).clamp(1, 24);
    final sums = List<double>.filled(buckets <= 0 ? 1 : buckets, 0);
    for (final e in events) {
      final slot = (e.ts.hour ~/ width).clamp(0, sums.length - 1);
      sums[slot] += e.value;
    }
    final labels = [
      // The last bar runs to midnight whatever the divisor is, so its label never
      // claims a narrower window than it holds.
      for (var i = 0; i < sums.length; i++) _hourLabel(i * width, i == sums.length - 1 ? 24 : (i + 1) * width),
    ];
    return RhythmBuckets(labels: labels, values: sums, eventCount: events.length);
  }

  /// Cycle statistics from logged flow days in the projection.
  CycleStats cycleStats() => CycleStats.fromSeries(_cache['period'] ?? const <double>[]);

  // `streakOf` used to live here as a second, SQL-side implementation of the
  // 70%-of-goal streak, and it disagreed with the one every screen actually uses
  // (`format.dart`'s `streakOf(Tracker, List<double>)`, which also counts a run that
  // ends yesterday). Nothing called it. Two rules for one number is how a chip and a
  // chart end up telling different stories, so the duplicate is gone: `AppState.streak`
  // is the single definition, and `qualifiedDaysDesc()` remains for SQL-only callers.

  Future<int> trackedDays() => dao.trackedDayCount();

  /// First day with real data, decoded from the day key. Null on a fresh install.
  Future<DateTime?> firstLoggedDate() async {
    final key = await dao.firstLoggedDay();
    if (key == null) return null;
    return DateTime(key ~/ 10000, (key ~/ 100) % 100, key % 100);
  }

  Future<int> entryCount() => dao.entryCount();

  // ------------------------------------------------------------------ exports
  /// Export is a query, not a reconstruction, and it is never gated behind Pro.
  ///
  /// `source` travels with every row so a user (or a support engineer) can tell
  /// their own entries apart from an import or a stray sample row.
  /// The full export. `sections` lets a caller add data this repository does not
  /// own — the Momentum routines, whose storage lives in `CommitmentRepository` —
  /// without this class having to know about them. Merging is explicit rather than
  /// implicit, so the shape of a user's export is visible in one place.
  Future<String> exportJson({Map<String, Object?>? sections}) async {
    final rows = await dao.exportDaily();
    final trackers = await dao.allTrackers();
    final events = await dao.exportEvents();
    return const JsonEncoder.withIndent('  ').encode({
      'format': AppEnvironment.exportFormat,
      'app': 'Track Pro',
      'exported': DateTime.now().toIso8601String(),
      'totals': {
        'daily_rows': rows.length,
        'events': events.length,
        'days': await dao.trackedDayCount(),
        'demo_rows': rows.where((r) => r.source == 'demo').length,
      },
      'provenance': {
        for (final s in await dao.entryCountBySource()) s.source: s.count,
      },
      'trackers': [
        for (final t in trackers)
          {
            'id': t.id,
            'name': t.name,
            'goal': t.goal,
            'unit': t.unit,
            'history': {
              for (final r in rows.where((r) => r.trackerId == t.id)) isoDayKey(r.day): r.value,
            },
          }
      ],
      'events': [
        for (final e in events)
          {'tracker': e.trackerId, 'at': e.ts.toIso8601String(), 'value': e.value, 'source': e.source, 'meta': e.meta},
      ],
      ...?sections,
    });
  }

  /// CSV straight from the daily matrix — what people paste into Sheets or hand
  /// to a doctor. Zero-filled days are marked `.` rather than `0` so "did not
  /// log" is never confused with "logged zero".
  /// Source precedence, highest first. The export resolves a (tracker, day) that
  /// has more than one row the same way the app does, instead of letting whichever
  /// row the database happened to return last win: a conflicting health or usage
  /// reading must never overwrite what the user typed, in the file they take away.
  static const Map<String, int> sourceRank = {'manual': 4, 'usage': 3, 'health': 2, 'demo': 1};

  Future<String> exportCsv() async {
    final trackers = await dao.allTrackers();
    final rows = await dao.exportDaily();
    final byTracker = <String, Map<int, double>>{};
    final bestRank = <String, Map<int, int>>{};
    for (final r in rows) {
      final day = byTracker.putIfAbsent(r.trackerId, () => <int, double>{});
      final ranks = bestRank.putIfAbsent(r.trackerId, () => <int, int>{});
      final incoming = sourceRank[r.source] ?? 0;
      final current = ranks[r.day];
      if (current == null || incoming >= current) {
        day[r.day] = r.value;
        ranks[r.day] = incoming;
      }
    }
    final days = <int>{for (final r in rows) r.day}.toList()..sort();
    final head = ['date', ...trackers.map((t) => t.id)].join(',');
    final lines = [
      for (final d in days)
        [
          isoDayKey(d),
          ...trackers.map((t) {
            final v = byTracker[t.id]?[d];
            return v == null ? '.' : v.toString();
          }),
        ].join(','),
    ];
    return [head, ...lines].join('\n');
  }

  // ------------------------------------------------------------------ helpers
  void _patch(String trackerId, int slot, double value) {
    final list = _cache.putIfAbsent(trackerId, () => List<double>.filled(cacheDays, 0));
    if (slot >= 0 && slot < list.length) list[slot] = value;
  }

  TrackerRowsCompanion _trackerRow(Tracker t, {required int sort, bool? hidden}) => TrackerRowsCompanion.insert(
        id: t.id,
        name: t.name,
        emoji: t.emoji,
        kind: t.kind.name,
        unit: t.unit,
        blurb: t.blurb,
        insight: t.insight,
        accent: t.accent.toARGB32(),
        accent2: t.accent2.toARGB32(),
        goal: t.goal,
        step: t.step,
        hero: Value(t.hero),
        hidden: Value(hidden ?? t.hidden),
        sort: Value(sort),
      );

  String? _metaOf(String? meta, String key) {
    if (meta == null || meta.isEmpty) return null;
    try {
      return (jsonDecode(meta) as Map)[key] as String?;
    } catch (_) {
      return null;
    }
  }

  String _relativeTime(DateTime ts) {
    final diff = DateTime.now().difference(ts);
    if (diff.inMinutes < 2) return 'Just now';
    if (diff.inHours < 24) {
      return 'Today · ${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}';
    }
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays} days ago';
  }

  static String _hourLabel(int from, int to) {
    String h(int x) {
      // 24 is a legal `to` (midnight, end of the last bucket) and must read 12am.
      final y = x % 24;
      final suffix = y < 12 ? 'am' : 'pm';
      final hour = y % 12 == 0 ? 12 : y % 12;
      return '$hour$suffix';
    }

    return '${h(from)}–${h(to)}';
  }
}

/// A logged food/calorie entry, straight from the event log.
class FoodEntry {
  const FoodEntry(this.title, this.emoji, this.kcal, this.when, this.source);

  final String title;
  final String emoji;
  final double kcal;
  final String when;
  final String source;
}

/// Hourly (or multi-hour) activity buckets for the day, from real events.
class RhythmBuckets {
  const RhythmBuckets({required this.labels, required this.values, required this.eventCount});

  final List<String> labels;
  final List<double> values;

  /// How many events this is built from. Zero means "nothing to plot".
  final int eventCount;

  bool get hasData => eventCount > 0;
}

/// Habit completion list stored in a daily row's meta: `{"done":[0,2,4]}`.
List<int>? decodeHabitMeta(String? meta) {
  if (meta == null || meta.isEmpty) return null;
  try {
    final decoded = jsonDecode(meta);
    if (decoded is! Map) return null;
    final done = decoded['done'];
    if (done is! List) return null;
    return [for (final v in done) if (v is int) v];
  } catch (_) {
    return null;
  }
}

String encodeHabitMeta(List<int> done) => jsonEncode({'done': done});

