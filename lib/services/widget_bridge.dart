import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../util/format.dart';

/// Pushes a small JSON snapshot of today's rings to the home-screen widget.
///
/// Why a snapshot instead of having the widget query SQLite itself:
/// - the widget renders in a different process (`:widget` isn't a thing, but the
///   RemoteViews host is another app) and pulling up sqflite there means a
///   second DB connection, migrations and memory just to draw three rings;
/// - the snapshot is ~600 bytes, written at most once per second, and is exactly
///   the data a widget is allowed to show.
///
/// The Kotlin side (`android_overlay/.../widget/TrackWidget.kt`) reads
/// `FlutterSharedPreferences` → key `flutter.track.widget.snapshot`, draws three
/// rings from it, and is nudged to redraw through the `track/widget` channel.
class WidgetBridge {
  WidgetBridge({this.debugLabel = 'track.widget.snapshot'});

  static const String storageKey = 'track.widget.snapshot';
  static const MethodChannel _channel = MethodChannel('track/widget');
  static const Duration _minInterval = Duration(milliseconds: 900);

  final String debugLabel;
  DateTime _lastWrite = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _debounce;

  /// Debounced so a burst of writes (water +250 ×6) produces one snapshot.
  Future<void> writeSnapshot(AppState state) async {
    if (DateTime.now().difference(_lastWrite) < _minInterval) {
      _debounce?.cancel();
      _debounce = Timer(_minInterval, () => unawaited(writeSnapshot(state)));
      return;
    }
    _lastWrite = DateTime.now();

    final payload = buildPayload(state);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(storageKey, jsonEncode(payload));
      await _channel.invokeMethod<void>('refresh');
    } catch (e) {
      debugPrint('$debugLabel: snapshot write failed — $e');
    }
  }

  /// Three rings, a streak and a one-line summary. Deliberately tiny: widgets
  /// have a hard RemoteViews size and complexity budget.
  Map<String, Object?> buildPayload(AppState state) {
    final trackers = state.visibleTrackers;
    final top =
        (trackers.where((t) => t.id != 'period' && t.id != 'weight').toList()
              ..sort((a, b) => ringPct(b, state.today(b.id)).compareTo(ringPct(a, state.today(a.id)))))
            .take(state.widgetRingCount) // 1 ring free, 3 with Pro
            .toList();

    // The commitment queue is the product now, so the widget leads with it: how
    // many commitments are still open today, and the longest current streak across
    // them. When no commitment exists (an install with only measurements), it falls
    // back to the tracker figures instead of showing a zero that means "nothing here".
    final openCommitments = state.todayCommitments.where((t) => !t.logged).length;
    final streak = state.hasCommitments ? state.bestCommitmentStreak : state.streak('habits');

    return {
      'updated': DateTime.now().toIso8601String(),
      // The real streak, including zero. This used to substitute 23 whenever the
      // user's streak was 0 — a fabricated number on the home screen, for
      // everybody, every day. The widget renders "no streak yet" instead.
      'streak': streak,
      'commitmentsOpen': openCommitments,
      'hasCommitments': state.hasCommitments,
      'summary': state.hasCommitments
          ? (openCommitments == 0
                ? 'All commitments logged today'
                : '$openCommitments commitment${openCommitments == 1 ? '' : 's'} still open today')
          : _summary(state),
      // The widget draws a small lock hint from this instead of an empty slot,
      // so the home screen quietly sells Pro every time it is glanced at.
      'pro': state.isPro,
      'lockedRings': state.isPro ? 0 : 2,
      'rings': [
        for (final t in top)
          {
            'id': t.id,
            'name': t.name,
            'emoji': t.emoji,
            'pct': double.parse(ringPct(t, state.today(t.id)).toStringAsFixed(3)),
            'value': _compact(t, state.today(t.id)),
            'color': t.accent.toARGB32(),
            'color2': t.accent2.toARGB32(),
          },
      ],
    };
  }

  String _summary(AppState state) {
    final open = state.visibleTrackers
        .where((t) => t.id != 'period' && t.id != 'weight' && !state.isLoggedToday(t.id))
        .length;
    return open == 0 ? 'All trackers logged today' : '$open trackers still open today';
  }

  String _compact(Tracker t, double v) {
    final s = fmtCompact(t, v);
    switch (t.kind) {
      case MetricKind.volume:
        return '$s L';
      case MetricKind.money:
        return s;
      case MetricKind.hours:
        return '$s h';
      case MetricKind.mood:
        return s;
      case MetricKind.cycle:
        return s;
      case MetricKind.weight:
        return '$s kg';
      case MetricKind.calories:
        return '$s kcal';
      case MetricKind.steps:
        return '$s steps';
      case MetricKind.minutes:
        return s;
      case MetricKind.habits:
        return '$s/5';
    }
  }
}
