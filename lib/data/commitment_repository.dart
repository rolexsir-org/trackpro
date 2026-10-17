import 'dart:convert';
import 'dart:ui' show Color;

import 'package:drift/drift.dart' show Value;

import '../models/models.dart';
import '../util/day_key.dart';
import 'db/database.dart';
import 'momentum.dart';

/// The Momentum store: commitments, the days they were actually kept, and pauses.
///
/// Same architecture as [EntryRepository] — writes go straight to SQLite, reads
/// come from an in-memory projection hydrated once per launch — but with one extra
/// rule that the tracker side does not need: **the projection is the only place
/// that decides anything**. `MomentumEngine` is pure, so a snapshot recomputed from
/// the same rows always produces the same figure, and a screen can never show a
/// number the database does not support.
class CommitmentRepository {
  CommitmentRepository(this.db, {this.now = DateTime.now, String Function()? idFactory})
      : _idFactory = idFactory;

  final TrackDatabase db;
  CommitmentDao get dao => db.commitmentDao;

  /// Injectable clock, so the tests can drive a Wednesday in March without
  /// pretending it is today, and so DST boundaries are testable.
  final DateTime Function() now;
  final String Function()? _idFactory;

  final List<Commitment> _commitments = <Commitment>[];
  final Map<String, Map<int, CommitmentDay>> _days = <String, Map<int, CommitmentDay>>{};
  final List<Pause> _pauses = <Pause>[];

  int _idCounter = 0;

  List<Commitment> get commitments => List<Commitment>.unmodifiable(_commitments);
  List<Commitment> get active => _commitments.where((c) => !c.archived).toList();
  List<Pause> get pauses => List<Pause>.unmodifiable(_pauses);
  Map<int, CommitmentDay> daysFor(String commitmentId) => _days[commitmentId] ?? const <int, CommitmentDay>{};

  int get todayKey => dayKey(now());

  bool get isEmpty => _commitments.isEmpty;

  /// How many days of history are loaded. Bounded: the Momentum screen draws at
  /// most a quarter, and the weekly review a week.
  static const int loadDays = 180;

  // ---------------------------------------------------------------- hydrate
  Future<void> hydrate() async {
    var from = todayKey;
    for (var i = 1; i < loadDays; i++) {
      from = previousDayKey(from);
    }

    _commitments
      ..clear()
      ..addAll((await dao.allRows()).map(_toModel));

    _days.clear();
    for (final row in await dao.allDays(fromDay: from)) {
      _days.putIfAbsent(row.commitmentId, () => <int, CommitmentDay>{})[row.day] = CommitmentDay(
        commitmentId: row.commitmentId,
        day: row.day,
        outcome: DayOutcomeText.fromStorage(row.outcome) ?? DayOutcome.missed,
        value: row.value,
        note: row.note,
      );
    }

    _pauses
      ..clear()
      ..addAll([
        for (final row in await dao.allPauses())
          Pause(commitmentId: row.commitmentId, fromDay: row.fromDay, toDay: row.toDay, reason: row.reason),
      ]);
  }

  // ------------------------------------------------------------------ writes
  /// Creates a commitment. Its record starts empty and its oldest possible day is
  /// [createdDay] (today, normally) — nothing before that is ever judged.
  Future<Commitment> create({
    required String name,
    required String emoji,
    required int color,
    required String outcome,
    required String minimumAction,
    required String fullAction,
    required Set<int> weekdays,
    String? id,
    int? createdDay,
  }) async {
    final trimmed = name.trim().isEmpty ? 'Untitled commitment' : name.trim();
    final day = createdDay ?? todayKey;
    final newId = id ?? _newId();
    final commit = Commitment(
      id: newId,
      name: trimmed,
      emoji: emoji,
      color: Color(color),
      outcome: outcome.trim(),
      minimumAction: minimumAction.trim(),
      fullAction: fullAction.trim(),
      revisions: [ScheduleRevision(day, weekdays.isEmpty ? const {1, 2, 3, 4, 5, 6, 7} : weekdays)],
      createdDay: day,
      sort: _commitments.length,
    );
    await dao.upsert(_toRow(commit));
    _commitments.add(commit);
    return commit;
  }

  Future<void> update(Commitment updated, {Set<int>? newWeekdays}) async {
    var next = updated;
    if (newWeekdays != null && !_sameDays(newWeekdays, updated.schedule)) {
      // A schedule change is a new revision starting today. Past days keep the
      // schedule that was in force when they happened — see MomentumEngine.isPlanned.
      next = updated.copyWith(revisions: [
        ...updated.revisions,
        ScheduleRevision(todayKey, newWeekdays.isEmpty ? updated.schedule : newWeekdays),
      ]);
    }
    await dao.upsert(_toRow(next));
    final i = _commitments.indexWhere((c) => c.id == next.id);
    if (i >= 0) {
      _commitments[i] = next;
    } else {
      _commitments.add(next);
    }
  }

  Future<void> archive(String id, {bool archived = true}) async {
    final day = archived ? todayKey : null;
    await dao.setArchived(id, archived: archived, day: day);
    _replace(id, (c) => c.copyWith(archived: archived, archivedDay: day));
  }

  Future<void> reorder(List<String> idsInOrder) async {
    for (var i = 0; i < idsInOrder.length; i++) {
      await dao.setSort(idsInOrder[i], i);
      _replace(idsInOrder[i], (c) => c.copyWith(sort: i));
    }
  }

  /// Hard delete. The commitment's day records and pauses go with it, by foreign
  /// key — a deleted commitment must not leave orphaned history behind that would
  /// reappear in an export.
  Future<void> delete(String id) async {
    await dao.deleteCommitment(id);
    _commitments.removeWhere((c) => c.id == id);
    _days.remove(id);
    _pauses.removeWhere((p) => p.commitmentId == id);
  }

  /// Records what actually happened. Idempotent per (commitment, day): logging
  /// twice replaces the answer, it does not stack.
  Future<CommitmentDay> record({
    required String commitmentId,
    required DayOutcome outcome,
    int? day,
    double? value,
    String? note,
  }) async {
    final key = day ?? todayKey;
    await dao.recordDay(
      commitmentId: commitmentId,
      day: key,
      outcome: outcome.storage,
      value: value,
      note: note,
    );
    final rec = CommitmentDay(commitmentId: commitmentId, day: key, outcome: outcome, value: value, note: note);
    _days.putIfAbsent(commitmentId, () => <int, CommitmentDay>{})[key] = rec;
    return rec;
  }

  Future<void> clearRecord(String commitmentId, {int? day}) async {
    final key = day ?? todayKey;
    await dao.clearDay(commitmentId, key);
    _days[commitmentId]?.remove(key);
  }

  Future<void> startPause(String commitmentId, {String? reason, int? day}) async {
    final from = day ?? todayKey;
    await dao.startPause(commitmentId: commitmentId, fromDay: from, reason: reason);
    _pauses.add(Pause(commitmentId: commitmentId, fromDay: from, reason: reason));
  }

  Future<void> endPause(String commitmentId, {int? day}) async {
    final to = day ?? todayKey;
    final touched = await dao.endPause(commitmentId, day: to);
    for (var i = 0; i < _pauses.length; i++) {
      final p = _pauses[i];
      if (p.commitmentId == commitmentId && p.toDay == null) _pauses[i] = p.copyWith(toDay: to);
    }
    if (touched == 0) {
      // Nothing was open. Reloading keeps the projection honest rather than
      // assuming the write landed somewhere it did not.
      _pauses
        ..clear()
        ..addAll([
          for (final row in await dao.allPauses())
            Pause(commitmentId: row.commitmentId, fromDay: row.fromDay, toDay: row.toDay, reason: row.reason),
        ]);
    }
  }

  bool isPaused(String commitmentId) => _pauses.any((p) => p.commitmentId == commitmentId && p.toDay == null);

  // ------------------------------------------------------------------ derived
  MomentumSnapshot? snapshotFor(String id, {int? today}) {
    final c = _byId(id);
    if (c == null) return null;
    return MomentumEngine.compute(
      c: c,
      recorded: daysFor(id),
      pauses: _pauses,
      today: today ?? todayKey,
    );
  }

  /// Snapshots for every live commitment, newest-created last.
  Map<String, MomentumSnapshot> snapshots({int? today}) {
    final key = today ?? todayKey;
    return {
      for (final c in active)
        c.id: MomentumEngine.compute(c: c, recorded: daysFor(c.id), pauses: _pauses, today: key),
    };
  }

  /// The headline figure: credit across every live commitment's decided days in the
  /// window. Returns null until there is enough evidence — the screen says so.
  MomentumSnapshot? overall({int? today}) {
    final key = today ?? todayKey;
    final all = snapshots(today: key).values.toList();
    if (all.isEmpty) return null;

    var decided = 0, full = 0, minimum = 0, missed = 0, excluded = 0, planned = 0;
    var credit = 0.0;
    var windowFrom = key;
    for (final s in all) {
      decided += s.decidedDays;
      full += s.fullDays;
      minimum += s.minimumDays;
      missed += s.missedDays;
      excluded += s.excludedDays;
      planned += s.plannedDays;
      credit += s.credit;
      if (s.windowFrom < windowFrom) windowFrom = s.windowFrom;
    }
    return MomentumSnapshot(
      commitmentId: '__all__',
      windowFrom: windowFrom,
      windowTo: key,
      plannedDays: planned,
      decidedDays: decided,
      fullDays: full,
      minimumDays: minimum,
      missedDays: missed,
      excludedDays: excluded,
      credit: credit,
      rate: decided >= MomentumEngine.minDecidedDaysForRate ? credit / decided * 100 : null,
      fullStreak: all.map((s) => s.fullStreak).fold<int>(0, (a, b) => a > b ? a : b),
      keepGoingStreak: all.map((s) => s.keepGoingStreak).fold<int>(0, (a, b) => a > b ? a : b),
      longestFullStreakInWindow: all.map((s) => s.longestFullStreakInWindow).fold<int>(0, (a, b) => a > b ? a : b),
      lastFullDay: null,
      missedRun: 0,
      todayOpen: all.any((s) => s.todayOpen),
    );
  }

  WeeklyReview? review({int? today}) {
    if (active.isEmpty) return null;
    return MomentumEngine.weeklyReview(
      commitments: active,
      recorded: _days,
      pauses: _pauses,
      anyDayInWeek: today ?? todayKey,
    );
  }

  List<WeekdayPattern> patternsFor(String id, {int? today}) {
    final c = _byId(id);
    if (c == null) return const <WeekdayPattern>[];
    return MomentumEngine.weekdayPatterns(
      c: c,
      recorded: daysFor(id),
      pauses: _pauses,
      today: today ?? todayKey,
    );
  }

  Improvement? improvementFor(String id, {int? today}) {
    final c = _byId(id);
    if (c == null) return null;
    return MomentumEngine.improvement(
      c: c,
      recorded: daysFor(id),
      pauses: _pauses,
      today: today ?? todayKey,
    );
  }

  /// Everything the user recorded for one commitment, oldest first — the shape an
  /// export needs and the shape a migration test can assert on.
  List<CommitmentDay> historyFor(String id) {
    final map = daysFor(id);
    final keys = map.keys.toList()..sort();
    return [for (final k in keys) map[k]!];
  }

  // ------------------------------------------------------------------- export
  /// Everything a user recorded about their routines, in a shape that survives a
  /// round trip: definitions with their schedule revisions (so history keeps its
  /// meaning), every recorded day, and every pause.
  ///
  /// This exists because "export is always free" has to include the habit data, not
  /// just the measurements. It is also what a migration test can assert against.
  Map<String, Object?> exportPayload() => {
        'format': 'track.commitments.v1',
        'totals': {
          'routines': _commitments.length,
          'active': active.length,
          'recorded_days': _days.values.fold<int>(0, (a, m) => a + m.length),
        },
        'routines': [
          for (final c in _commitments)
            {
              'id': c.id,
              'name': c.name,
              'emoji': c.emoji,
              'colour': c.color.toARGB32(),
              'outcome': c.outcome,
              'minimum': c.minimumAction,
              'full': c.fullAction,
              'schedule': [
                for (final r in c.revisions)
                  {'from': isoDayKey(r.fromDay), 'days': (r.weekdays.toList()..sort())},
              ],
              'created': isoDayKey(c.createdDay),
              'archived': c.archived,
              'archived_on': c.archivedDay == null ? null : isoDayKey(c.archivedDay!),
              'days': [
                for (final rec in historyFor(c.id))
                  {
                    'date': isoDayKey(rec.day),
                    'outcome': rec.outcome.storage,
                    'value': rec.value,
                    'note': rec.note,
                  },
              ],
            },
        ],
        'pauses': [
          for (final p in _pauses)
            {
              'routine': p.commitmentId,
              'from': isoDayKey(p.fromDay),
              'to': p.toDay == null ? null : isoDayKey(p.toDay!),
              'reason': p.reason,
            },
        ],
      };

  /// One row per recorded day — the shape a spreadsheet wants.
  // ------------------------------------------------------------- data rights
  /// Deletes every routine and every day recorded against it.
  ///
  /// The in-memory projection goes with the rows: a reset that left the Momentum
  /// screen drawing routines which no longer exist would be a stale screen, and a
  /// stale screen after "delete all data" is the worst place for one.
  Future<Map<String, int>> deleteAllUserData({bool keepDefinitions = false}) async {
    final removed = await dao.deleteAllUserData(keepDefinitions: keepDefinitions);
    if (!keepDefinitions) {
      _commitments.clear();
      _days.clear();
      _pauses.clear();
    }
    return removed;
  }

  String exportCsv() {
    final lines = <String>['date,routine,outcome,value,note'];
    for (final c in _commitments) {
      for (final rec in historyFor(c.id)) {
        lines.add([
          isoDayKey(rec.day),
          _csv(c.name),
          rec.outcome.storage,
          rec.value?.toString() ?? '',
          _csv(rec.note ?? ''),
        ].join(','));
      }
    }
    return lines.join('\n');
  }

  static String _csv(String raw) {
    final needsQuotes = raw.contains(',') || raw.contains('"') || raw.contains('\n');
    final escaped = raw.replaceAll('"', '""');
    return needsQuotes ? '"$escaped"' : escaped;
  }

  // ------------------------------------------------------------- legacy import
  /// Converts an install's pre-Momentum habit checklist into commitments.
  ///
  /// The old model was a JSON list of habits in `app_settings['habits']` plus a
  /// per-day `{"done":[…indices]}` blob inside the `habits` tracker's
  /// `daily_entries.meta`. It is converted, **not deleted**: the original rows stay
  /// exactly where they were, so if this import is ever found to be wrong, nothing
  /// has been lost.
  ///
  /// Two honest limitations, both surfaced in the returned report:
  ///  - Legacy `done` lists store *positions*. If the user added or removed habits,
  ///    those positions may have pointed at a different habit that day. Only the
  ///    current list is used, because the old blob does not record its own mapping.
  ///  - Only completions were stored. A day the checklist was never opened is
  ///    imported as **no record**, not as a miss — the app cannot know, and will not
  ///    invent it.
  ///
  /// Idempotent: a settings marker records that the import ran, and each generated
  /// commitment is checked for existence before it is written.
  Future<LegacyImportReport> importLegacyHabits({TrackDao? trackerDao}) async {
    final settings = trackerDao ?? db.trackDao;
    const marker = 'commitments.legacyImported';
    if (await settings.getSetting(marker) != null) {
      return const LegacyImportReport(alreadyImported: true, habits: 0, days: 0);
    }

    final raw = await settings.getSetting('habits');
    var imported = 0;
    var days = 0;

    if (raw != null && raw.trim().isNotEmpty) {
      List<dynamic> decoded;
      try {
        decoded = jsonDecode(raw) as List<dynamic>;
      } catch (_) {
        decoded = const <dynamic>[]; // a corrupt config must not block start-up
      }

      // index -> (commitment id, name) for the legacy checklist mapping.
      final mapping = <int, String>{};
      for (var i = 0; i < decoded.length; i++) {
        final item = decoded[i];
        if (item is! Map) continue;
        final name = (item['name'] as String?)?.trim() ?? '';
        if (name.isEmpty) continue;
        final id = 'legacy-habit-$i';
        if (_byId(id) != null) {
          mapping[i] = id;
          continue;
        }
        final emoji = (item['emoji'] as String?) ?? '✅';
        final color = item['color'] is int ? item['color'] as int : 0xFF34C759;

        // Completions first, so createdDay can be the earliest day that has one.
        final rows = await db.trackDao.dailyRowsFor('habits', days: loadDays);
        final completed = <int>[];
        for (final row in rows) {
          final done = _doneIndices(row.meta);
          if (done.contains(i)) completed.add(row.day);
        }
        final createdDay = completed.isEmpty ? todayKey : completed.reduce((a, b) => a < b ? a : b);

        await dao.upsert(CommitmentRowsCompanion.insert(
          id: id,
          name: name,
          emoji: emoji,
          color: color,
          outcome: name,
          minimumAction: 'Do a smaller version of: $name',
          fullAction: name,
          scheduleJson: jsonEncode([ScheduleRevision(createdDay, const {1, 2, 3, 4, 5, 6, 7}).toJson()]),
          createdDay: createdDay,
          sort: Value(_commitments.length + imported),
        ));
        for (final day in completed) {
          await dao.recordDay(commitmentId: id, day: day, outcome: DayOutcome.full.storage, source: 'import');
          days++;
        }
        mapping[i] = id;
        imported++;
      }
      await hydrate();
    }

    await settings.setSetting(marker, DateTime.now().toIso8601String());
    return LegacyImportReport(
      alreadyImported: false,
      habits: imported,
      days: days,
      limitation: imported == 0
          ? null
          : 'Imported as full completions only, using today\'s habit list to read the old '
              'checklist positions. Days the checklist was never opened carry no record.',
    );
  }

  List<int> _doneIndices(String? meta) {
    if (meta == null || meta.isEmpty) return const <int>[];
    try {
      final decoded = jsonDecode(meta);
      if (decoded is! Map) return const <int>[];
      final done = decoded['done'];
      if (done is! List) return const <int>[];
      return [for (final v in done) if (v is int) v];
    } catch (_) {
      return const <int>[];
    }
  }

  // ------------------------------------------------------------------ helpers
  String _newId() {
    final f = _idFactory;
    if (f != null) return f();
    _idCounter++;
    return 'c${now().microsecondsSinceEpoch}-$_idCounter';
  }

  Commitment? _byId(String id) {
    for (final c in _commitments) {
      if (c.id == id) return c;
    }
    return null;
  }

  void _replace(String id, Commitment Function(Commitment) f) {
    final i = _commitments.indexWhere((c) => c.id == id);
    if (i >= 0) _commitments[i] = f(_commitments[i]);
  }

  static bool _sameDays(Set<int> a, Set<int> b) => a.length == b.length && a.every(b.contains);

  static Commitment _toModel(CommitmentRow r) => Commitment(
        id: r.id,
        name: r.name,
        emoji: r.emoji,
        color: Color(r.color),
        outcome: r.outcome,
        minimumAction: r.minimumAction,
        fullAction: r.fullAction,
        revisions: decodeSchedule(r.scheduleJson, fallbackDay: r.createdDay),
        createdDay: r.createdDay,
        archived: r.archived,
        archivedDay: r.archivedDay,
        sort: r.sort,
      );

  static CommitmentRowsCompanion _toRow(Commitment c) => CommitmentRowsCompanion.insert(
        id: c.id,
        name: c.name,
        emoji: c.emoji,
        color: c.color.toARGB32(),
        outcome: c.outcome,
        minimumAction: c.minimumAction,
        fullAction: c.fullAction,
        scheduleJson: jsonEncode([for (final r in c.revisions) r.toJson()]),
        createdDay: c.createdDay,
        archived: Value(c.archived),
        archivedDay: Value(c.archivedDay),
        sort: Value(c.sort),
      );
}

/// Decodes the stored schedule. A corrupt blob must not produce a commitment with
/// no days: it falls back to every day, starting at creation, which is what the
/// legacy habit rows meant. (A silently empty schedule would make every day
/// "not planned" and quietly zero the user's momentum.)
List<ScheduleRevision> decodeSchedule(String raw, {required int fallbackDay}) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is List && decoded.isNotEmpty) {
      final out = <ScheduleRevision>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        final from = item['from'];
        final days = item['days'];
        if (from is! int || days is! List) continue;
        out.add(ScheduleRevision(from, {for (final d in days) if (d is int && d >= 1 && d <= 7) d}));
      }
      out.sort((a, b) => a.fromDay.compareTo(b.fromDay));
      final usable = [for (final r in out) if (r.weekdays.isNotEmpty) r];
      if (usable.isNotEmpty) return usable;
    }
  } catch (_) {
    // fall through to the conservative default below
  }
  return [ScheduleRevision(fallbackDay, const {1, 2, 3, 4, 5, 6, 7})];
}

/// What a legacy import did, including the limitation it could not avoid.
class LegacyImportReport {
  const LegacyImportReport({
    required this.alreadyImported,
    required this.habits,
    required this.days,
    this.limitation,
  });

  final bool alreadyImported;
  final int habits;
  final int days;
  final String? limitation;

  bool get didImport => !alreadyImported && habits > 0;
}
