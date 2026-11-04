import 'dart:async';

import 'package:flutter/foundation.dart';

import '../util/format.dart';
import 'app_state.dart';

/// Where the application is in its start-up sequence.
///
/// There was no such state before this file existed, and that absence *was* the blank
/// screen. `main()` initialized the notifications plugin, opened the database, hydrated
/// the projection, imported the legacy habit list, recovered Focus Lock and re-armed
/// three reminders, and only then called `runApp`. Until the last of those awaits
/// finished the process had rendered nothing, so the launcher's splash colour was the
/// only thing on screen; and if any one of them threw — or simply never answered — a
/// blank window was the only possible outcome. There was no error surface to show,
/// because there was no widget tree to put one in, and in a release build there was no
/// record either: `debugPrint` goes to logcat, and logcat is not a diagnostic a user or
/// a support engineer can read off the phone.
///
/// The fix is not a `try/catch` around the old sequence. It is this state, rendered by
/// `StartupGate` from the very first frame: **starting**, **ready**, or **failed with a
/// retry**. The interface is only ever built in one of them, and it is never built on
/// top of a database that did not open.
enum StartupPhase {
  /// Nothing has begun. The first frame renders the start-up screen from here.
  idle,

  /// The essential stage is in flight.
  running,

  /// The database, the projection and the persisted settings are loaded. The real
  /// interface may be rendered.
  ready,

  /// The essential stage failed. The interface must not be rendered, and [AppStartup.retry]
  /// is the only way forward.
  failed,
}

/// One non-fatal start-up problem, in the words a settings row can show.
///
/// "Non-fatal" is the point: a reminder that could not be armed, a permission read that
/// never answered and a billing store that is not installed are all real failures whose
/// correct consequence is a missing feature — never a missing app.
@immutable
class StartupIssue {
  const StartupIssue({required this.stage, required this.detail});

  /// What was being attempted, in the user's vocabulary ("Reminders", "Focus Lock").
  final String stage;

  /// The error, shortened and stripped of stack noise.
  final String detail;

  /// The one-line form. Used for the diagnostics list and for de-duplication.
  String get summary => '$stage: $detail';
}

/// The app's start-up sequence, as a state machine the first frame can render.
///
/// Two rules are load-bearing and both are tested in `test/startup_test.dart`:
///
///  1. **Ready means loaded.** [state] must report `isLoaded` before this class reports
///     [StartupPhase.ready]. A sequence that "finished" without a database is a failed
///     sequence, not a ready app — the previous code could not tell the difference,
///     because there was no phase to be in.
///  2. **Once means once.** [start] is idempotent: concurrent callers join the same
///     future, and a completed sequence is never re-run. [retry] is the only way to run
///     it a second time, and it is only offered from [StartupPhase.failed].
class AppStartup extends ChangeNotifier {
  AppStartup({
    required this.state,
    required this.essential,
    this.background,
    this.essentialTimeout = const Duration(seconds: 20),
    this.backgroundTimeout = const Duration(seconds: 30),
  });

  /// The state the sequence is loading into. Also where every non-fatal problem is
  /// recorded, so Settings → Diagnostics shows the same list this class acts on.
  final AppState state;

  /// The stage the app cannot open without: the notifications plugin (which must be
  /// initialized before anything schedules a reminder) and `AppState.load()`.
  ///
  /// Any error, or a timeout, is fatal to start-up and shows the retry screen.
  final Future<void> Function() essential;

  /// Work that must not be on the first frame's critical path: billing, entitlement
  /// reconciliation, reminder sync, the widget snapshot, Health Connect and the
  /// usage-stats pull. It runs **after** [StartupPhase.ready], so a store that is not
  /// installed or a permission that was revoked costs the feature and not the app.
  final Future<void> Function()? background;

  /// How long the essential stage may take. Bounded because the alternative to a
  /// timeout is the bug this class exists to fix: an operation that never completes
  /// leaves the user on a start-up screen with no way to say so.
  final Duration essentialTimeout;

  /// How long the whole background pass may take before the app stops waiting on it and
  /// records the problem. Generous on purpose: it exists to stop a wedged store or a
  /// wedged health read from leaving a future pending for the life of the process, not to
  /// hurry work nobody is waiting for. The individual integrations inside it bound
  /// themselves (`AppState.optionalStageTimeout`).
  final Duration backgroundTimeout;

  StartupPhase phase = StartupPhase.idle;

  /// Why the essential stage failed. Null unless [phase] is [StartupPhase.failed].
  StartupIssue? failure;

  bool get isReady => phase == StartupPhase.ready;

  bool get isFailed => phase == StartupPhase.failed;

  Future<void>? _running;
  bool _backgroundStarted = false;
  bool _disposed = false;

  /// Runs the sequence, or joins the run already in flight.
  Future<void> start() {
    final inFlight = _running;
    if (inFlight != null) return inFlight;
    if (_disposed || phase == StartupPhase.ready) return Future<void>.value();
    final future = _run();
    _running = future;
    return future;
  }

  /// Retries a failed sequence. A no-op when the app is already ready, so a second tap
  /// on the retry button cannot start a second bootstrap.
  Future<void> retry() {
    if (_disposed || phase == StartupPhase.ready) return Future<void>.value();
    if (phase == StartupPhase.running) return start();
    failure = null;
    phase = StartupPhase.idle;
    _notify();
    return start();
  }

  Future<void> _run() async {
    phase = StartupPhase.running;
    failure = null;
    _notify();
    try {
      await essential().timeout(essentialTimeout);

      // Rule 1. `AppState.load()` sets this only after the database opened, the
      // projection hydrated and the persisted settings were read; anything less is a
      // start-up that must not be presented as success.
      if (!state.isLoaded) {
        throw StateError('the database and the in-memory projection did not load');
      }

      phase = StartupPhase.ready;
      _notify();
      _startBackground();
    } on TimeoutException {
      _fail(
        StartupIssue(
          stage: 'Start-up',
          detail: 'did not finish within ${essentialTimeout.inSeconds}s. '
              'Your data has not been changed.',
        ),
      );
    } catch (error) {
      _fail(StartupIssue(stage: 'Start-up', detail: shortErrorText(error)));
    } finally {
      // Cleared here, not by the caller: `start()` assigns the future this method
      // returned, and the assignment always happens before this `finally` runs because
      // the body awaits at least once.
      _running = null;
    }
  }

  void _startBackground() {
    final task = background;
    if (task == null || _backgroundStarted) return;
    _backgroundStarted = true;
    unawaited(_guarded('Background sync', task));
  }

  /// Runs one optional stage with a bound on it, recording rather than propagating
  /// whatever comes back. Used by [AppStartup] for [background]; `AppState` has the
  /// same rule for the stages inside `load()`.
  Future<void> _guarded(String stage, Future<void> Function() step) async {
    try {
      await step().timeout(backgroundTimeout);
    } on TimeoutException {
      _record(StartupIssue(stage: stage, detail: 'did not finish within ${backgroundTimeout.inSeconds}s'));
    } catch (error) {
      _record(StartupIssue(stage: stage, detail: shortErrorText(error)));
    }
  }

  void _fail(StartupIssue issue) {
    failure = issue;
    phase = StartupPhase.failed;
    state.recordStartupIssue(issue.stage, issue.detail);
    debugPrint('Track Pro start-up failed — ${issue.summary}');
    _notify();
  }

  void _record(StartupIssue issue) {
    state.recordStartupIssue(issue.stage, issue.detail);
    debugPrint('Track Pro start-up: ${issue.summary}');
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
