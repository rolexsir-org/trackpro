// Drift schema for Track Pro.
//
// Design: one append-only `events` log (the source of truth for exports,
// category breakdowns and audit) plus a denormalised `daily_entries` rollup
// (the source of truth for charts, rings and streaks — one row per tracker per
// day, so a 28-day chart is a single indexed query instead of 400 event scans).
//
// Both are written from the same call site in EntryRepository, so they can
// never drift apart by more than one transaction.
//
//   dart run build_runner build --delete-conflicting-outputs

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../../util/day_key.dart';

// `dayKey` is declared in `util/day_key.dart` and re-exported here.
//
// It used to be declared in **both** places. Any file importing both libraries — and
// three did — then could not reference `dayKey` at all: Dart reports an ambiguous
// name, which is a compile error, not a warning. Nothing on this host can run the
// analyzer, and every text-level audit was happy, because a duplicate definition
// looks exactly like a definition. The tool that found it is
// `tools/symbol_clash_audit.py`.
export '../../util/day_key.dart' show dayKey;

part 'database.g.dart';

/// ---------------------------------------------------------------------------
/// DATA PROVENANCE (read this before adding a table or a write path)
/// ---------------------------------------------------------------------------
/// Every row that represents *something that happened* carries a `source`:
///
///   manual  — the user typed it. Authoritative. Never overwritten by sync.
///   health  — read from Health Connect. Idempotent per (tracker, day).
///   widget  — logged from the home-screen widget.
///   import  — restored from a user-supplied export.
///   legacy  — reserved for `demo`: rows written by a pre-1.0 development build
///             that could still seed synthetic history. **No code path in this
///             repository writes it any more** (the seeder was deleted and
///             `bootstrap()` cannot take one). It survives as a label so that an
///             upgraded install can still identify and delete those rows, and
///             so Diagnostics can prove they are gone.
///
/// Anything user-visible must therefore be able to answer "did a human put this
/// here?" — which is why `entryCountBySource()` and `demoRowCount()` exist.
///
/// Tracker configuration. Mirrors `models/models.dart` Tracker, minus the
/// Flutter-only bits (colors travel as ARGB ints).
/// The generated row class is named explicitly: Drift's default (strip a trailing
/// "s") gives `TrackerRow` here, and the previous code declared `List<Tracker>`,
/// which is the *model* class from `models.dart` — a type error that only a
/// compiler would have caught. Naming every data class by hand removes the
/// guesswork from review and from the audits.
@DataClassName('TrackerRow')
class TrackerRows extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get emoji => text()();
  TextColumn get kind => text()();
  TextColumn get unit => text()();
  TextColumn get blurb => text()();
  TextColumn get insight => text()();
  IntColumn get accent => integer()();
  IntColumn get accent2 => integer()();
  RealColumn get goal => real()();
  RealColumn get step => real()();
  BoolColumn get hero => boolean().withDefault(const Constant(false))();
  BoolColumn get hidden => boolean().withDefault(const Constant(false))();
  IntColumn get sort => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// One rolled-up value per tracker per local day. Fast path for every chart.
@DataClassName('DailyEntry')
class DailyEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get trackerId => text().references(TrackerRows, #id, onDelete: KeyAction.cascade)();

  /// Local day as yyyymmdd — an int key sorts and ranges cheaper than a date.
  IntColumn get day => integer()();
  DateTimeColumn get updatedAt => dateTime()();
  RealColumn get value => real()();

  /// manual | health | usage | widget | demo | import — user data always wins over
  /// sync (`usage` is the Android Usage Access screen-time auto-fill).
  TextColumn get source => text().withDefault(const Constant('manual'))();
  TextColumn get meta => text().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {trackerId, day, source},
  ];
}

/// A commitment: something the user said they would do, with the smallest version
/// of it they would still count as showing up.
///
/// One row per commitment. The schedule is versioned inside [scheduleJson] so that
/// editing today's plan never retroactively changes which days the user was
/// *supposed* to act on — history keeps its original meaning.
@DataClassName('CommitmentRow')
class CommitmentRows extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get emoji => text()();
  IntColumn get color => integer()();

  /// The desired outcome, in the user's words. Never scored.
  TextColumn get outcome => text()();
  TextColumn get minimumAction => text()();
  TextColumn get fullAction => text()();

  /// `[[fromDay,[weekdays...]], ...]`, oldest first. Always at least one entry.
  TextColumn get scheduleJson => text()();

  /// Nothing before this day is ever counted, planned or judged.
  IntColumn get createdDay => integer()();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  IntColumn get archivedDay => integer().nullable()();
  IntColumn get sort => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// One recorded decision per commitment per day: what actually happened.
///
/// `uniqueKeys(commitmentId, day)` is what makes a double tap on "full" harmless:
/// the second write replaces the first instead of creating a second row that would
/// inflate every derived count. There is no row for a day the user did not decide —
/// absence is absence, and the engine treats silence on a planned, past day as a
/// miss rather than filling it in here.
///
/// The table is called `CommitmentEntries` rather than `CommitmentDays` because the
/// model layer already has a `CommitmentDay` (a commitment id + day + outcome, with
/// no row id), and two types with one name would collide at every call site.
@DataClassName('CommitmentEntryRow')
class CommitmentEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get commitmentId => text().references(CommitmentRows, #id, onDelete: KeyAction.cascade)();

  /// Local day as yyyymmdd, same convention as `daily_entries`.
  IntColumn get day => integer()();

  /// full | minimum | missed | rest | skipped
  TextColumn get outcome => text()();

  /// What was actually completed, when the user typed an amount. Nullable: absent
  /// is not zero.
  RealColumn get value => real().nullable()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get recordedAt => dateTime()();

  /// manual | import — for symmetry with the tracker tables. Note that no seeder
  /// can write here: there is no seeder.
  TextColumn get source => text().withDefault(const Constant('manual'))();

  @override
  List<Set<Column>> get uniqueKeys => [
    {commitmentId, day},
  ];
}

/// A deliberate break: a commitment is not judged — not even as missed — on the
/// days inside a pause. An open pause has a null `toDay` and stays open until the
/// user resumes.
@DataClassName('CommitmentPauseRow')
class CommitmentPauses extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get commitmentId => text().references(CommitmentRows, #id, onDelete: KeyAction.cascade)();
  IntColumn get fromDay => integer()();
  IntColumn get toDay => integer().nullable()();
  TextColumn get reason => text().nullable()();
}

/// Append-only log. Expenses, calories, cups, symptoms — the interesting detail
/// lives in `meta` (JSON), which is what makes "you spend most on Fridays"
/// answerable in one SQL query.
@DataClassName('EventRow')
class Events extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get trackerId => text().references(TrackerRows, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get ts => dateTime()();
  IntColumn get day => integer()();
  RealColumn get value => real()();
  TextColumn get source => text().withDefault(const Constant('manual'))();
  TextColumn get meta => text().nullable()();
}

/// Every Play purchase we have seen, for support, refunds and reconciliation.
/// The entitlement the UI reads is a fast KV cache; this table is the record of
/// what actually happened, including the purchase token the server needs.
@DataClassName('PurchaseRow')
class Purchases extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get productId => text()();

  /// Play purchase token — the key the backend verifies against the Developer API.
  TextColumn get purchaseToken => text()();

  /// purchased | restored | pending | canceled | error | expired | refunded
  TextColumn get status => text()();
  DateTimeColumn get purchasedAt => dateTime()();
  DateTimeColumn get expiresAt => dateTime().nullable()();
  BoolColumn get autoRenew => boolean().withDefault(const Constant(false))();
  BoolColumn get acknowledged => boolean().withDefault(const Constant(false))();
  BoolColumn get serverVerified => boolean().withDefault(const Constant(false))();
  BoolColumn get trial => boolean().withDefault(const Constant(false))();
  TextColumn get raw => text().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {purchaseToken, productId},
  ];
}

/// Monetisation funnel events (paywall views, plan picks, trial starts…).
/// Local by design: it answers "what converts?" with a GROUP BY, and shipping it
/// needs no new SDK and no new privacy disclosure.
@DataClassName('TrackEventRow')
class TrackEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  DateTimeColumn get at => dateTime()();
  TextColumn get meta => text().nullable()();
}

/// KV settings (theme, onboarding, habit checklists, sync cursors).
@DataClassName('AppSettingRow')
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// One focus session, from start to verdict.
///
/// Two design notes that are load-bearing:
///
///  * **The clocks are explicit.** `startedAtRealtimeMs` is the platform's
///    monotonic clock (`SystemClock.elapsedRealtime()`), which survives a process
///    death and ignores the user changing the system time; `startedAtWallMs` is only
///    for display and attribution. `focusMs` banks time already served, and
///    `segmentStartedAtRealtimeMs` marks the accruing segment, so paused time is
///    never counted as focus time and a crash mid-session costs at most the time
///    since the last checkpoint — which the recovery reports rather than hides.
///  * **Enforcement is recorded, never inferred.** `enforcement` is written from
///    what the platform reported (permissions held, service alive, foreground events
///    observed) and is what stops a session claiming a block it cannot prove.
@DataClassName('FocusSessionRow')
class FocusSessions extends Table {
  TextColumn get id => text()();

  /// standard | blocking | deep
  TextColumn get mode => text()();

  IntColumn get plannedMinutes => integer()();

  /// What the user said they were focusing on, in their words.
  TextColumn get goalLabel => text()();

  /// The routine this was started from, when there was one. `SET NULL`, not
  /// cascade: deleting a routine must never delete time the user actually spent.
  TextColumn get commitmentId => text().nullable().references(CommitmentRows, #id, onDelete: KeyAction.setNull)();

  IntColumn get startedAtWallMs => integer()();
  IntColumn get startedAtRealtimeMs => integer()();

  /// Realtime clock when the current run segment began. Null while paused.
  IntColumn get segmentStartedAtRealtimeMs => integer().nullable()();

  /// Wall clock when the current pause began, or null when running. A pause has to
  /// have a definite start: without it, a session paused and then killed by the OS
  /// could not tell a one-minute pause from an hour-long one.
  IntColumn get pausedAtWallMs => integer().nullable()();

  /// Focus time banked before the current segment. Excludes paused time.
  IntColumn get focusMs => integer().withDefault(const Constant(0))();
  IntColumn get pausedMs => integer().withDefault(const Constant(0))();

  /// running | paused | ended
  TextColumn get state => text()();

  /// completed | completedDegraded | interrupted | cancelled — null while live.
  TextColumn get outcome => text().nullable()();

  /// timerOnly | unavailable | armed | verified | lost
  TextColumn get enforcement => text()();

  /// timer | userEnded | cancelled | serviceLost | deviceRestarted |
  /// permissionRevoked | appUpdated
  TextColumn get endReason => text().nullable()();

  IntColumn get blockedAttempts => integer().withDefault(const Constant(0))();
  IntColumn get overlayShows => integer().withDefault(const Constant(0))();

  /// Foreground-app events the monitor reported during this session. Zero on a
  /// device that refuses to report usage — the evidence behind "unconfirmed".
  IntColumn get detectionEvents => integer().withDefault(const Constant(0))();

  /// False when the session had to be timed with the wall clock.
  BoolColumn get timingVerified => boolean().withDefault(const Constant(true))();

  /// JSON array of the package ids that were restricted. Package ids only: no
  /// usage times, no content, and nothing leaves the device.
  TextColumn get blockedPackagesJson => text().withDefault(const Constant('[]'))();

  IntColumn get endedAtWallMs => integer().nullable()();

  /// The user's own words about how it went. Optional, never prompted twice.
  TextColumn get reflection => text().nullable()();

  /// Local day key of the start, for the history and the streak maths.
  IntColumn get day => integer()();

  /// manual | import — symmetry with the other tables.
  TextColumn get source => text().withDefault(const Constant('manual'))();

  @override
  Set<Column> get primaryKey => {id};
}

/// A reusable rule set: mode, duration, and the apps to restrict. Pro.
@DataClassName('FocusProfileRow')
class FocusProfiles extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get mode => text()();
  IntColumn get minutes => integer()();
  TextColumn get commitmentId => text().nullable().references(CommitmentRows, #id, onDelete: KeyAction.setNull)();
  TextColumn get packagesJson => text().withDefault(const Constant('[]'))();
  IntColumn get sort => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// A recurring reminder to start a focus session, at a wall-clock time on chosen
/// weekdays. Pro.
///
/// This schedules a **notification with a "Start now" action**, not a silent
/// session: beginning to restrict other apps while nobody is holding the phone is
/// the behaviour users correctly call malware, and Android restricts it anyway.
@DataClassName('FocusScheduleRow')
class FocusSchedules extends Table {
  TextColumn get id => text()();
  TextColumn get mode => text()();
  IntColumn get minutes => integer()();
  IntColumn get hour => integer()();
  IntColumn get minute => integer()();

  /// ISO weekdays as a JSON array; empty means every day.
  TextColumn get weekdaysJson => text().withDefault(const Constant('[]'))();
  TextColumn get commitmentId => text().nullable().references(CommitmentRows, #id, onDelete: KeyAction.setNull)();
  TextColumn get packagesJson => text().withDefault(const Constant('[]'))();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();

  /// The id handed to `NotificationService`, stored so a schedule can always
  /// cancel exactly what it scheduled — including after a reinstall of the app's
  /// settings, which is why it is not derived on the fly.
  IntColumn get notificationId => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    TrackerRows,
    DailyEntries,
    Events,
    AppSettings,
    Purchases,
    TrackEvents,
    CommitmentRows,
    CommitmentEntries,
    CommitmentPauses,
    FocusSessions,
    FocusProfiles,
    FocusSchedules,
  ],
  daos: [TrackDao, CommitmentDao, FocusDao],
)
class TrackDatabase extends _$TrackDatabase {
  TrackDatabase() : super(_open());
  TrackDatabase.forTesting(QueryExecutor executor) : super(executor);

  static QueryExecutor _open() => driftDatabase(name: 'track');

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await customStatement('PRAGMA foreign_keys = ON');
    },
    onUpgrade: (m, from, to) async {
      // v1 → v2: monetisation. Additive only, so existing history survives —
      // which matters more here than anywhere else in the app, because the
      // user's accumulated data is the product.
      if (from < 2) {
        await m.createTable(purchases);
        await m.createTable(trackEvents);
      }
      // v2 → v3: Momentum. Three new tables, again purely additive: every
      // tracker row, entry, event, purchase and setting from v2 is untouched
      // and unread by these statements. There is deliberately **no data
      // rewrite here** — converting an install's legacy habit checklist into
      // commitments is an explicit, idempotent, testable import
      // (`CommitmentMigration.importLegacy`), not a side effect of opening the
      // database. A migration that silently rewrites user data is a migration
      // nobody can roll back.
      if (from < 3) {
        await m.createTable(commitmentRows);
        await m.createTable(commitmentEntries);
        await m.createTable(commitmentPauses);
      }
      // v3 → v4: Focus Lock. Three new tables, additive like every migration
      // before them. The one thing worth stating explicitly: a session that was
      // live when the app was updated is **not** rewritten here. Recovery is
      // `FocusRepository.recover()`, which runs at start-up, is idempotent, and
      // decides the outcome from the stored clocks. A migration that decided a
      // session's outcome would be choosing history inside `onUpgrade`, which is
      // exactly where it cannot be tested.
      if (from < 4) {
        await m.createTable(focusSessions);
        await m.createTable(focusProfiles);
        await m.createTable(focusSchedules);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}

/// ---------------------------------------------------------------------------
/// DAO — every read the UI does goes through here, so charts come from SQL
/// aggregates rather than from scanning Dart lists.
/// ---------------------------------------------------------------------------
@DriftAccessor(tables: [TrackerRows, DailyEntries, Events, AppSettings, Purchases, TrackEvents])
class TrackDao extends DatabaseAccessor<TrackDatabase> with _$TrackDaoMixin {
  TrackDao(super.db);

  // ------------------------------------------------------------------ trackers
  Future<List<TrackerRow>> allTrackers() =>
      (select(trackerRows)..orderBy([(t) => OrderingTerm(expression: t.sort)])).get();

  Future<void> upsertTracker(TrackerRowsCompanion row) => into(trackerRows).insertOnConflictUpdate(row);

  Future<void> upsertAllTrackers(List<TrackerRowsCompanion> rows) async {
    await batch((b) => b.insertAllOnConflictUpdate(trackerRows, rows));
  }

  Future<void> setGoal(String id, double goal) =>
      (update(trackerRows)..where((t) => t.id.equals(id))).write(TrackerRowsCompanion(goal: Value(goal)));

  Future<void> setHidden(String id, bool hidden) =>
      (update(trackerRows)..where((t) => t.id.equals(id))).write(TrackerRowsCompanion(hidden: Value(hidden)));

  Future<int> trackerCount() async {
    final c = trackerRows.id.count();
    final row = await (selectOnly(trackerRows)..addColumns([c])).getSingle();
    return row.read(c) ?? 0;
  }

  Future<void> deleteTrackersAll() => delete(trackerRows).go();

  /// Which sources have written this (tracker, day) — the merge guard for
  /// health sync, so a manual entry is never overwritten by an import.
  Future<List<String>> sourcesForDay(String trackerId, int day) async {
    final rows = await (select(dailyEntries)..where((d) => d.trackerId.equals(trackerId) & d.day.equals(day))).get();
    return rows.map((r) => r.source).toList();
  }

  Future<void> setSort(String id, int sort) =>
      (update(trackerRows)..where((t) => t.id.equals(id))).write(TrackerRowsCompanion(sort: Value(sort)));

  // -------------------------------------------------------------------- writes
  /// Upsert today's rolled-up value. `uniqueKeys(trackerId, day, source)` makes
  /// this idempotent, so a health sync re-run never double-counts.
  Future<void> upsertDaily({
    required String trackerId,
    required int day,
    required double value,
    String source = 'manual',
    String? meta,
    DateTime? at,
  }) {
    return into(dailyEntries).insertOnConflictUpdate(
      DailyEntriesCompanion.insert(
        trackerId: trackerId,
        day: day,
        value: value,
        updatedAt: at ?? DateTime.now(),
        source: Value(source),
        meta: Value(meta),
      ),
    );
  }

  /// Removes one (tracker, day, source) rollup — used when real data replaces a
  /// synthetic row, and by the deletion flows. Returns the number of rows removed
  /// so a caller can tell "nothing to replace" from "replaced".
  Future<int> deleteDailyFor(String trackerId, int day, {required String source}) => (delete(
    dailyEntries,
  )..where((d) => d.trackerId.equals(trackerId) & d.day.equals(day) & d.source.equals(source))).go();

  /// Removes **every** source's rollup for one (tracker, day).
  ///
  /// This is what "clear this day" has to mean. A day whose only row came from
  /// Health Connect (steps, sleep, weight) has no `source = 'manual'` row, so
  /// deleting by source found nothing to remove: the sheet reported that nothing was
  /// stored while the row stayed in the database and repainted itself on the next
  /// hydrate. The user's own delete wins over the origin of the row; a later sync
  /// can refill the day, which is exactly what a sync is for.
  Future<int> deleteDailyForAllSources(String trackerId, int day) =>
      (delete(dailyEntries)..where((d) => d.trackerId.equals(trackerId) & d.day.equals(day))).go();

  Future<void> insertEvent({
    required String trackerId,
    required double value,
    String source = 'manual',
    String? meta,
    DateTime? at,
  }) {
    final now = at ?? DateTime.now();
    return into(events).insert(
      EventsCompanion.insert(
        trackerId: trackerId,
        ts: now,
        day: dayKey(now),
        value: value,
        source: Value(source),
        meta: Value(meta),
      ),
    );
  }

  /// Writes the rollup and the event row in one transaction.
  Future<void> logEvent({
    required String trackerId,
    required double newDailyTotal,
    required double delta,
    String source = 'manual',
    String? meta,
    DateTime? at,
  }) async {
    await transaction(() async {
      await insertEvent(trackerId: trackerId, value: delta, source: source, meta: meta, at: at);
      await upsertDaily(
        trackerId: trackerId,
        day: dayKey(at ?? DateTime.now()),
        value: newDailyTotal,
        source: source,
        at: at,
      );
    });
  }

  /// Replaces one tracker's whole rollup series. **Test and fixture support only**: no
  /// path in `lib/` calls it, and `source` is required rather than defaulted to `'demo'`
  /// so that nothing added later can write sample-labelled rows by omission. The `demo`
  /// *reading* side (the purge, the counts, the provenance label) has to stay — real
  /// installs out there still carry those rows — but the writing side should not.
  Future<void> replaceSeries(
    String trackerId,
    Map<int, double> dayToValue, {
    required String source,
    String? meta,
  }) async {
    await transaction(() async {
      await (delete(dailyEntries)..where((d) => d.trackerId.equals(trackerId))).go();
      await batch(
        (b) => b.insertAll(dailyEntries, [
          for (final e in dayToValue.entries)
            DailyEntriesCompanion.insert(
              trackerId: trackerId,
              day: e.key,
              value: e.value,
              updatedAt: DateTime.now(),
              source: Value(source),
              meta: Value(meta),
            ),
        ]),
      );
    });
  }

  Future<void> wipeUserData() async {
    await transaction(() async {
      await delete(events).go();
      await delete(dailyEntries).go();
      await delete(appSettings).go();
    });
  }

  // --------------------------------------------------------------------- reads
  /// The [days] day keys ending today, oldest first.
  ///
  /// Built by stepping the **date components**, not by subtracting a `Duration`
  /// from `DateTime.now()`: a day that is 23 or 25 hours long (a DST transition, or
  /// a flight across zones) shifts millisecond arithmetic by a day, which silently
  /// moves every value in every chart one slot sideways. Stepping components also
  /// pins the window to one "today": the previous version re-read `DateTime.now()`
  /// inside the loop, so a query that happened to cross midnight shifted its own
  /// slots halfway through building the list.
  static List<int> dayKeysEndingToday(int days) {
    if (days <= 0) return const <int>[];
    return [for (var i = days - 1; i >= 0; i--) dayKeyFromToday(i)];
  }

  /// The left edge of a `days`-long window ending today, without building the window.
  ///
  /// Two of the aggregate queries below only need the first day, and `series()` needs
  /// every one of them; both must derive it the same way or the chart and the tile
  /// disagree about where "the last 30 days" starts.
  static int dayKeyWindowStart(int days) => dayKeyFromToday(days - 1 < 0 ? 0 : days - 1);

  /// The chart query: last [days] days for one tracker, ascending, gap-filled
  /// with zeros so a broken streak shows as a real hole rather than a jump.
  Future<List<double>> series(String trackerId, {int days = 28, String? source}) async {
    final keys = dayKeysEndingToday(days);
    final q = select(dailyEntries)
      ..where((d) => d.trackerId.equals(trackerId) & d.day.isBiggerOrEqualValue(keys.isEmpty ? 0 : keys.first));
    if (source != null) q.where((d) => d.source.equals(source));
    q.orderBy([(d) => OrderingTerm(expression: d.day)]);
    final rows = await q.get();

    final byDay = {for (final r in rows) r.day: r.value};
    return [for (final k in keys) byDay[k] ?? 0.0];
  }

  /// SQL aggregate: spend grouped by the category stored in `meta` JSON.
  /// This is the "expenses by category" chart, answered without touching Dart.
  Future<List<CategorySum>> categoryTotals({int days = 7}) async {
    final from = dayKeyWindowStart(days);
    final total = events.value.sum();
    final q = selectOnly(events)
      ..addColumns([events.meta, total])
      ..where(events.trackerId.equals('expenses') & events.day.isBiggerOrEqualValue(from))
      ..groupBy([events.meta])
      ..orderBy([OrderingTerm.desc(total)]);
    final rows = await q.get();
    return [for (final r in rows) CategorySum(_categoryOf(r.read(events.meta)) ?? 'Other', r.read(total) ?? 0)];
  }

  /// SQL aggregate: how many distinct days have any data (the "26 of 28" tile).
  /// The first day the user actually recorded something, or null on a fresh
  /// install. Used for "tracking since …" — never assumed to be today.
  Future<int?> firstLoggedDay() async {
    final row =
        await (selectOnly(dailyEntries)
              ..addColumns([dailyEntries.day.min()])
              ..where(dailyEntries.value.isBiggerThanValue(0)))
            .getSingleOrNull();
    return row?.read(dailyEntries.day.min());
  }

  Future<int> trackedDayCount() async {
    final rows = await (selectOnly(dailyEntries, distinct: true)..addColumns([dailyEntries.day])).get();
    return rows.map((r) => r.read(dailyEntries.day)).whereType<int>().length;
  }

  Future<int> entryCount() async {
    final count = dailyEntries.id.count();
    final dailies = await (selectOnly(dailyEntries)..addColumns([count])).getSingle();
    final ecount = events.id.count();
    final evs = await (selectOnly(events)..addColumns([ecount])).getSingle();
    return (dailies.read(count) ?? 0) + (evs.read(ecount) ?? 0);
  }

  /// Newest-first event feed for the Expenses/Screen-time detail screens.
  Future<List<EventRow>> recentEvents(String trackerId, {int limit = 10}) =>
      (select(events)
            ..where((e) => e.trackerId.equals(trackerId))
            ..orderBy([(e) => OrderingTerm.desc(e.ts)])
            ..limit(limit))
          .get();

  // ------------------------------------------------------------------ settings
  Future<String?> getSetting(String key) async {
    final row = await (select(appSettings)..where((s) => s.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> setSetting(String key, String value) =>
      into(appSettings).insertOnConflictUpdate(AppSettingsCompanion.insert(key: key, value: value));

  // ----------------------------------------------------- purchases & analytics
  Future<void> recordPurchase({
    required String productId,
    required String purchaseToken,
    required String status,
    required DateTime purchasedAt,
    DateTime? expiresAt,
    bool autoRenew = false,
    bool acknowledged = false,
    bool serverVerified = false,
    bool trial = false,
    String? raw,
  }) {
    return into(purchases).insertOnConflictUpdate(
      PurchasesCompanion.insert(
        productId: productId,
        purchaseToken: purchaseToken,
        status: status,
        purchasedAt: purchasedAt,
        expiresAt: Value(expiresAt),
        autoRenew: Value(autoRenew),
        acknowledged: Value(acknowledged),
        serverVerified: Value(serverVerified),
        trial: Value(trial),
        raw: Value(raw),
      ),
    );
  }

  Future<void> markPurchaseVerified(String purchaseToken, {required bool verified}) async {
    await (update(
      purchases,
    )..where((p) => p.purchaseToken.equals(purchaseToken))).write(PurchasesCompanion(serverVerified: Value(verified)));
  }

  Future<List<PurchaseRow>> recentPurchases({int limit = 25}) =>
      (select(purchases)
            ..orderBy([(p) => OrderingTerm.desc(p.purchasedAt)])
            ..limit(limit))
          .get();

  /// Funnel event (paywall views, trial starts…). Distinct name from `logEvent`
  /// above, which writes *tracker* events — different table, different purpose.
  Future<void> logTrackEvent(String name, [String? meta]) =>
      into(trackEvents).insert(TrackEventsCompanion.insert(name: name, meta: Value(meta), at: DateTime.now()));

  Future<List<EventCount>> eventCounts({int days = 30}) async {
    final from = DateTime.now().subtract(Duration(days: days));
    final count = trackEvents.id.count();
    final rows =
        await (selectOnly(trackEvents)
              ..addColumns([trackEvents.name, count])
              ..where(trackEvents.at.isBiggerOrEqualValue(from))
              ..groupBy([trackEvents.name]))
            .get();
    return [for (final r in rows) EventCount(r.read(trackEvents.name) ?? '?', r.read(count) ?? 0)];
  }

  // ------------------------------------------------- provenance & maintenance
  /// Rows per source, across both tables — the answer to "is any of this real?".
  /// Used by Settings → Diagnostics and by the release test that asserts a fresh
  /// production database contains no `demo` rows.
  Future<List<SourceCount>> entryCountBySource() async {
    final daily = await customSelect(
      'SELECT source, COUNT(*) AS n FROM daily_entries GROUP BY source',
      readsFrom: {dailyEntries},
    ).get();
    final evs = await customSelect(
      'SELECT source, COUNT(*) AS n FROM events GROUP BY source',
      readsFrom: {events},
    ).get();
    final totals = <String, int>{};
    for (final r in [...daily, ...evs]) {
      final src = r.read<String>('source');
      totals[src] = (totals[src] ?? 0) + (r.read<int>('n'));
    }
    final out = [for (final e in totals.entries) SourceCount(e.key, e.value)];
    out.sort((a, b) => b.count.compareTo(a.count));
    return out;
  }

  Future<int> demoRowCount() async {
    final daily = await customSelect(
      "SELECT COUNT(*) AS n FROM daily_entries WHERE source = 'demo'",
      readsFrom: {dailyEntries},
    ).getSingle();
    final evs = await customSelect(
      "SELECT COUNT(*) AS n FROM events WHERE source = 'demo'",
      readsFrom: {events},
    ).getSingle();
    return (daily.read<int>('n')) + (evs.read<int>('n'));
  }

  /// Deletes only rows that came from a seeder. User data, health data and
  /// purchase records are untouched — this is the "remove the sample data"
  /// button, not a reset.
  Future<int> deleteDemoRows() async {
    final before = await demoRowCount();
    await transaction(() async {
      await (delete(dailyEntries)..where((d) => d.source.equals('demo'))).go();
      await (delete(events)..where((e) => e.source.equals('demo'))).go();
    });
    return before;
  }

  /// Schema-integrity probe. Cheap enough to run on a cold start and after a
  /// crash was detected; returns SQLite's own verdict verbatim.
  Future<String> integrityCheck() async {
    final rows = await customSelect('PRAGMA integrity_check', readsFrom: {}).get();
    return rows.map((r) => r.read<String>('integrity_check')).join('; ');
  }

  Future<int> foreignKeyViolationCount() async {
    final rows = await customSelect('PRAGMA foreign_key_check', readsFrom: {}).get();
    return rows.length;
  }

  /// Everything a user produced, in one place — used by the deletion flow.
  /// Tracker *definitions* survive: deleting your entries should not delete the
  /// trackers you configured.
  Future<Map<String, int>> deleteAllUserData() async {
    final before = <String, int>{
      'daily_entries': (await customSelect(
        'SELECT COUNT(*) AS n FROM daily_entries',
        readsFrom: {},
      ).getSingle()).read<int>('n'),
      'events': (await customSelect('SELECT COUNT(*) AS n FROM events', readsFrom: {}).getSingle()).read<int>('n'),
    };
    await transaction(() async {
      await delete(events).go();
      await delete(dailyEntries).go();
    });
    return before;
  }

  /// Per-day metadata for one tracker — habit checklists, symptom notes.
  Future<List<DailyEntry>> dailyRowsFor(String trackerId, {int days = 60}) {
    final from = dayKeyWindowStart(days);
    return (select(dailyEntries)
          ..where((d) => d.trackerId.equals(trackerId) & d.day.isBiggerOrEqualValue(from))
          ..orderBy([(d) => OrderingTerm(expression: d.day)]))
        .get();
  }

  /// Events inside one local day, for the hourly rhythm charts. Bounded by day,
  /// so the row count is small even for a heavy logger.
  Future<List<EventRow>> eventsForDay(String trackerId, int day) =>
      (select(events)
            ..where((e) => e.trackerId.equals(trackerId) & e.day.equals(day))
            ..orderBy([(e) => OrderingTerm(expression: e.ts)]))
          .get();

  /// Deletes the event rows inside one day, for the "clear this day" path.
  ///
  /// Both tables move together on purpose: the daily rollup is what the charts read,
  /// but the event log is what Export and the transaction list read, and clearing only
  /// one of them would leave a day that looks deleted in the ring and present in the
  /// export. The caller wraps this in a transaction with the daily delete.
  Future<int> deleteEventsForDay(String trackerId, int day) =>
      (delete(events)..where((e) => e.trackerId.equals(trackerId) & e.day.equals(day))).go();

  // -------------------------------------------------------------------- export
  /// Export is a query, not a reconstruction: the full daily matrix, ready for
  /// CSV, plus the raw event log for a complete audit trail.
  Future<List<DailyEntry>> exportDaily() =>
      (select(dailyEntries)..orderBy([(d) => OrderingTerm(expression: d.day)])).get();

  Future<List<EventRow>> exportEvents() => (select(events)..orderBy([(e) => OrderingTerm(expression: e.ts)])).get();
}

/// ---------------------------------------------------------------------------
/// Commitment DAO — the Momentum tables. Kept separate from `TrackDao` so the
/// habit engine's queries never get tangled with the measurement tracker's.
/// ---------------------------------------------------------------------------
@DriftAccessor(tables: [CommitmentRows, CommitmentEntries, CommitmentPauses])
class CommitmentDao extends DatabaseAccessor<TrackDatabase> with _$CommitmentDaoMixin {
  CommitmentDao(super.db);

  Future<List<CommitmentRow>> allRows() => (select(
    commitmentRows,
  )..orderBy([(t) => OrderingTerm(expression: t.archived), (t) => OrderingTerm(expression: t.sort)])).get();

  Future<void> upsert(CommitmentRowsCompanion row) => into(commitmentRows).insertOnConflictUpdate(row);

  Future<void> setArchived(String id, {required bool archived, int? day}) => (update(
    commitmentRows,
  )..where((t) => t.id.equals(id))).write(CommitmentRowsCompanion(archived: Value(archived), archivedDay: Value(day)));

  /// Hard delete. Cascades to that commitment's days and pauses through the
  /// foreign keys, which are enforced (`PRAGMA foreign_keys = ON`).
  Future<int> deleteCommitment(String id) => (delete(commitmentRows)..where((t) => t.id.equals(id))).go();

  Future<void> setSort(String id, int sort) =>
      (update(commitmentRows)..where((t) => t.id.equals(id))).write(CommitmentRowsCompanion(sort: Value(sort)));

  // ------------------------------------------------------------------- days
  Future<List<CommitmentEntryRow>> daysFor(String commitmentId, {int? fromDay}) {
    final q = select(commitmentEntries)..where((d) => d.commitmentId.equals(commitmentId));
    if (fromDay != null) q.where((d) => d.day.isBiggerOrEqualValue(fromDay));
    return (q..orderBy([(d) => OrderingTerm(expression: d.day)])).get();
  }

  Future<List<CommitmentEntryRow>> allDays({int? fromDay}) {
    final q = select(commitmentEntries);
    if (fromDay != null) q.where((d) => d.day.isBiggerOrEqualValue(fromDay));
    return (q..orderBy([(d) => OrderingTerm(expression: d.day)])).get();
  }

  /// Records a decision for one day. Upsert on (commitment, day): a correction or
  /// a repeated tap replaces the previous answer rather than stacking on top of it.
  Future<void> recordDay({
    required String commitmentId,
    required int day,
    required String outcome,
    double? value,
    String? note,
    String source = 'manual',
    DateTime? at,
  }) => into(commitmentEntries).insertOnConflictUpdate(
    CommitmentEntriesCompanion.insert(
      commitmentId: commitmentId,
      day: day,
      outcome: outcome,
      value: Value(value),
      note: Value(note),
      recordedAt: at ?? DateTime.now(),
      source: Value(source),
    ),
  );

  Future<int> clearDay(String commitmentId, int day) =>
      (delete(commitmentEntries)..where((d) => d.commitmentId.equals(commitmentId) & d.day.equals(day))).go();

  Future<int> dayCountFor(String commitmentId) async {
    final c = commitmentEntries.id.count();
    final row =
        await (selectOnly(commitmentEntries)
              ..addColumns([c])
              ..where(commitmentEntries.commitmentId.equals(commitmentId)))
            .getSingle();
    return row.read(c) ?? 0;
  }

  Future<int> totalDayCount() async {
    final c = commitmentEntries.id.count();
    final row = await (selectOnly(commitmentEntries)..addColumns([c])).getSingle();
    return row.read(c) ?? 0;
  }

  // ----------------------------------------------------------------- pauses
  Future<List<CommitmentPauseRow>> allPauses({bool openOnly = false}) {
    final q = select(commitmentPauses);
    if (openOnly) q.where((p) => p.toDay.isNull());
    return (q..orderBy([(p) => OrderingTerm(expression: p.fromDay)])).get();
  }

  Future<int> startPause({required String commitmentId, required int fromDay, String? reason}) =>
      into(commitmentPauses).insert(
        CommitmentPausesCompanion.insert(
          commitmentId: commitmentId,
          fromDay: fromDay,
          toDay: const Value(null),
          reason: Value(reason),
        ),
      );

  /// Closes every open pause for a commitment at [day]. Returns rows touched, so a
  /// caller can tell "resumed" from "was not paused".
  Future<int> endPause(String commitmentId, {required int day}) =>
      (update(commitmentPauses)..where((p) => p.commitmentId.equals(commitmentId) & p.toDay.isNull())).write(
        CommitmentPausesCompanion(toDay: Value(day)),
      );

  Future<int> deletePausesFor(String commitmentId) =>
      (delete(commitmentPauses)..where((p) => p.commitmentId.equals(commitmentId))).go();

  // ------------------------------------------------------------- data rights
  /// Removes the user's routines and everything recorded against them, in one
  /// transaction, and reports what was actually removed.
  ///
  /// `keepDefinitions` keeps the routine rows themselves — the same shape as
  /// `TrackDao.deleteAllUserData`, which keeps the tracker catalogue — and exists
  /// so a test can re-log against known routines. "Delete all data" passes false:
  /// leaving a routine named after something private behind after a wipe is the
  /// version of this that people would be angry about.
  Future<Map<String, int>> deleteAllUserData({bool keepDefinitions = false}) async {
    final removed = <String, int>{};
    await transaction(() async {
      removed['routine_days'] = await delete(commitmentEntries).go();
      removed['routine_pauses'] = await delete(commitmentPauses).go();
      removed['routines'] = keepDefinitions ? 0 : await delete(commitmentRows).go();
    });
    return removed;
  }
}

class SourceCount {
  const SourceCount(this.source, this.count);

  final String source;
  final int count;

  /// Human label, so the diagnostics screen does not say "manual: 412" to a
  /// person who has never seen the schema.
  String get label => switch (source) {
    'manual' => 'Typed by you',
    'health' => 'From Health Connect',
    'usage' => 'From Android Usage Access',
    'widget' => 'From the home-screen widget',
    'import' => 'Restored from a backup',
    'demo' => 'Sample data (not yours)',
    _ => source,
  };
}

class EventCount {
  const EventCount(this.name, this.count);

  final String name;
  final int count;
}

class CategorySum {
  const CategorySum(this.category, this.total);

  final String category;
  final double total;
}

/// Every read and write Focus Lock performs, in one place.
///
/// The DAO has no opinions: it moves rows. The rules (what an outcome may be, what
/// enforcement was in force, how a session is recovered) live in `FocusEngine` and
/// `FocusRepository`, where they are testable without a database — except for the
/// two ideas the SQL itself has to enforce:
///
///  * `closeAllOpen` ends any live session, which is what makes "there is at most
///    one live session" a property of the store rather than a convention;
///  * `deleteAllUserData` removes the user's sessions and schedules while leaving
///    their *definitions* (profiles) alone unless asked — the same contract as the
///    tracker tables, so "delete my data" cannot half-delete.
@DriftAccessor(tables: [FocusSessions, FocusProfiles, FocusSchedules])
class FocusDao extends DatabaseAccessor<TrackDatabase> with _$FocusDaoMixin {
  FocusDao(super.db);

  // --------------------------------------------------------------- sessions
  Future<List<FocusSessionRow>> allSessions({int? fromDay}) {
    final q = select(focusSessions);
    if (fromDay != null) q.where((t) => t.day.isBiggerOrEqualValue(fromDay));
    return (q..orderBy([(t) => OrderingTerm(expression: t.startedAtWallMs, mode: OrderingMode.desc)])).get();
  }

  /// The live session, if there is one. Oldest first, so if a corrupt state ever
  /// holds two, the caller sees the one the user actually started first.
  Future<FocusSessionRow?> openSession() =>
      (select(focusSessions)
            ..where((t) => t.state.equals('running') | t.state.equals('paused'))
            ..orderBy([(t) => OrderingTerm(expression: t.startedAtWallMs)])
            ..limit(1))
          .getSingleOrNull();

  Future<FocusSessionRow?> byId(String id) => (select(focusSessions)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> upsert(FocusSessionsCompanion row) => into(focusSessions).insertOnConflictUpdate(row);

  /// Ends every live session. Used by recovery for the impossible-but-handled case
  /// of two open rows, and by "delete all data". Returns the rows touched.
  Future<int> closeAllOpen({
    required String state,
    required String outcome,
    required String endReason,
    required DateTime at,
    int? atWallMs,
  }) => (update(focusSessions)..where((t) => t.state.equals('running') | t.state.equals('paused'))).write(
    FocusSessionsCompanion(
      state: Value(state),
      outcome: Value(outcome),
      endReason: Value(endReason),
      endedAtWallMs: Value(atWallMs ?? at.millisecondsSinceEpoch),
    ),
  );

  Future<int> endSession({
    required String id,
    required int focusMs,
    required int pausedMs,
    required String outcome,
    required String endReason,
    required String enforcement,
    required int blockedAttempts,
    required int overlayShows,
    required int detectionEvents,
    required bool timingVerified,
    required int endedAtWallMs,
    String? reflection,
  }) => (update(focusSessions)..where((t) => t.id.equals(id))).write(
    FocusSessionsCompanion(
      state: const Value('ended'),
      outcome: Value(outcome),
      endReason: Value(endReason),
      enforcement: Value(enforcement),
      focusMs: Value(focusMs),
      pausedMs: Value(pausedMs),
      blockedAttempts: Value(blockedAttempts),
      overlayShows: Value(overlayShows),
      detectionEvents: Value(detectionEvents),
      timingVerified: Value(timingVerified),
      endedAtWallMs: Value(endedAtWallMs),
      reflection: Value(reflection),
    ),
  );

  Future<int> setReflection(String id, String? reflection) => (update(
    focusSessions,
  )..where((t) => t.id.equals(id))).write(FocusSessionsCompanion(reflection: Value(reflection)));

  Future<int> deleteSession(String id) => (delete(focusSessions)..where((t) => t.id.equals(id))).go();

  /// Sessions that served their time (clean or degraded), for the analytics card.
  /// Done in SQL so the figure cannot drift from what a count query says.
  Future<int> servedCount({int? fromDay}) async {
    final c = focusSessions.id.count();
    var q = selectOnly(focusSessions)..addColumns([c]);
    if (fromDay != null) q.where(focusSessions.day.isBiggerOrEqualValue(fromDay));
    q.where(focusSessions.outcome.equals('completed') | focusSessions.outcome.equals('completedDegraded'));
    final row = await q.getSingle();
    return row.read(c) ?? 0;
  }

  Future<int> totalCount() async {
    final c = focusSessions.id.count();
    final row = await (selectOnly(focusSessions)..addColumns([c])).getSingle();
    return row.read(c) ?? 0;
  }

  // --------------------------------------------------------------- profiles
  Future<List<FocusProfileRow>> allProfiles() =>
      (select(focusProfiles)..orderBy([(t) => OrderingTerm(expression: t.sort)])).get();

  Future<void> upsertProfile(FocusProfilesCompanion row) => into(focusProfiles).insertOnConflictUpdate(row);

  Future<int> deleteProfile(String id) => (delete(focusProfiles)..where((t) => t.id.equals(id))).go();

  // -------------------------------------------------------------- schedules
  Future<List<FocusScheduleRow>> allSchedules() => select(focusSchedules).get();

  Future<void> upsertSchedule(FocusSchedulesCompanion row) => into(focusSchedules).insertOnConflictUpdate(row);

  Future<int> deleteSchedule(String id) => (delete(focusSchedules)..where((t) => t.id.equals(id))).go();

  Future<int> setScheduleEnabled(String id, {required bool enabled}) =>
      (update(focusSchedules)..where((t) => t.id.equals(id))).write(FocusSchedulesCompanion(enabled: Value(enabled)));

  // ------------------------------------------------------------- data rights
  /// Removes the user's focus records. Definitions are kept unless
  /// `keepDefinitions` is false, matching `TrackDao.deleteAllUserData`.
  Future<Map<String, int>> deleteAllUserData({bool keepDefinitions = true}) async {
    final sessions = await delete(focusSessions).go();
    final schedules = await delete(focusSchedules).go();
    final profiles = keepDefinitions ? 0 : await delete(focusProfiles).go();
    return {'focus_sessions': sessions, 'focus_schedules': schedules, 'focus_profiles': profiles};
  }

  Future<int> countForDiagnostics() => totalCount();
}

String? _categoryOf(String? meta) {
  if (meta == null || meta.isEmpty) return null;
  final match = RegExp(r'"category"\s*:\s*"([^"]+)"').firstMatch(meta);
  return match?.group(1);
}
