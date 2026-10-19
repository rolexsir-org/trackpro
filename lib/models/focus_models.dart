import 'dart:ui' show Color;

/// Focus Lock — the model layer.
///
/// Deliberately free of Flutter, drift and platform imports: everything here is
/// plain data, which is what lets `FocusEngine` (pure) and the tests run without a
/// device, a database or a channel. The one exception is [Color] from `dart:ui`,
/// used for the optional accent a session inherits from the routine it is linked
/// to; it is a value type, not a widget.
///
/// Three invariants are encoded in these types rather than in comments:
///
///  1. **A session's enforcement is a recorded fact, not a hope.** [FocusEnforcement]
///     is written from what the platform reported, and the outcome derivation in
///     `FocusEngine.outcomeFor` refuses to call an unenforced session a clean
///     completion. There is no field called `blocked` that a caller could set.
///  2. **Time is measured, not assumed.** A session stores the wall clock *and* the
///     monotonic clock it started at, plus how much focus time was already banked
///     ([FocusSession.focusMs]) and which segment is currently accruing
///     ([FocusSession.segmentStartedAtRealtimeMs]). A process death, a reboot or a
///     clock change is therefore detectable instead of silently producing a wrong
///     countdown.
///  3. **Nothing is deleted to make a state look tidy.** An interrupted session is a
///     row with an honest outcome, never a gap.

/// How strict a session is.
///
/// [standard] is a timer: it reduces in-app distraction and stays quiet, and it
/// makes no claim about other applications. [blocking] requests a coverage panel
/// for apps the user selected; Android may still refuse a background launch. [deep]
/// applies the stricter rule set the user configured (a smaller pause budget, a hold
/// to end) — it is not a kiosk and it does not lock the device.
enum FocusMode {
  standard,
  blocking,
  deep;

  /// The string written to the database. Stable: an older build's row must keep
  /// meaning the same thing after an update.
  String get storage => name;

  static FocusMode? fromStorage(String? raw) {
    for (final m in FocusMode.values) {
      if (m.storage == raw) return m;
    }
    return null;
  }
}

/// Where a session is in its lifecycle. `ended` is terminal.
enum FocusSessionState {
  running,
  paused,
  ended;

  String get storage => name;

  static FocusSessionState fromStorage(String? raw) {
    for (final s in FocusSessionState.values) {
      if (s.storage == raw) return s;
    }
    return FocusSessionState.ended;
  }
}

/// What actually happened to a session. Four values, because "did it work?" has
/// four honest answers, not two.
///
///  * [completed] — the timer ran out (or the user ended it after the time was
///    up) and every rule the mode promised was in force, verified, throughout.
///  * [completedDegraded] — the time was served, but a rule the user selected was
///    not in force for the whole session: blocking was never confirmed on this
///    device, a permission was missing, or the pause budget was exceeded. The
///    session is still recorded and still counts as time spent; it is not counted
///    as a clean run.
///  * [interrupted] — the session ended because Track Pro could not continue: the
///    service was stopped, the device restarted, the app was updated, or a
///    permission was revoked. Track Pro does not know what happened during that time,
///    so it does not claim the session happened.
///  * [cancelled] — the user ended it early. No penalty, no lecture: it is recorded
///    as what it was.
enum FocusOutcome {
  completed,
  completedDegraded,
  interrupted,
  cancelled;

  String get storage => name;

  bool get isEnded => true;

  /// Only a clean completion may present itself as one. Used by the UI so no
  /// screen has to re-implement the rule.
  bool get isClean => this == FocusOutcome.completed;

  /// Did the user actually sit through the session? True for completions, degraded
  /// or not — that distinction is exactly what [completedDegraded] preserves.
  bool get servedTime => this == FocusOutcome.completed || this == FocusOutcome.completedDegraded;

  static FocusOutcome? fromStorage(String? raw) {
    for (final o in FocusOutcome.values) {
      if (o.storage == raw) return o;
    }
    return null;
  }
}

/// How much of the selected rule set was actually in force.
///
/// This is the type that stops Track Pro from claiming a block it cannot prove. Blocking
/// on Android is built from two user-granted permissions plus a foreground service;
/// any of the three can be absent, and *absence must be visible*.
enum FocusEnforcement {
  /// No blocking was requested for this session (the user chose a timer session).
  timerOnly,

  /// Blocking was requested but a required permission is missing, so nothing is
  /// being enforced. The session runs as a timer and says so.
  unavailable,

  /// The backing service is alive and holds its permissions, but it has not yet
  /// observed a single foreground-app event — which is also what a device that
  /// refuses to report usage looks like. Enforcement is **not confirmed**.
  armed,

  /// Service alive, permissions held, the detector has seen foreground activity,
  /// and Android accepted a coverage-panel launch for a selected app. This is the
  /// only value that supports the sentence "blocking was working".
  verified,

  /// Enforcement stopped mid-session (the service went away or a permission was
  /// revoked). The remaining time in the session was not enforced.
  lost;

  String get storage => name;

  /// Whether this state may be described to the user as blocking being on. `armed`
  /// deliberately does **not** qualify: "we set it up and no evidence arrived" is
  /// not the same claim as "it worked".
  bool get isConfirmed => this == FocusEnforcement.verified;

  /// Whether the session intended to block anything at all.
  bool get intendsToBlock => this != FocusEnforcement.timerOnly;

  /// Whether this state deserves a call to action on screen: something the user
  /// wanted is not happening. `armed` qualifies even though the service is healthy,
  /// because "set up, no evidence yet" is still not proof, and the honest thing is to
  /// say so rather than to let a green dot imply more than it knows.
  bool get needsAttention =>
      this == FocusEnforcement.unavailable ||
      this == FocusEnforcement.armed ||
      this == FocusEnforcement.lost;

  static FocusEnforcement fromStorage(String? raw) {
    for (final e in FocusEnforcement.values) {
      if (e.storage == raw) return e;
    }
    return FocusEnforcement.unavailable;
  }
}

/// Why a session stopped. Recorded for every ended session, so the history can
/// explain itself without re-deriving anything.
enum FocusEndReason {
  /// The countdown reached zero.
  timer,

  /// The user ended it after the time was already up.
  userEnded,

  /// The user ended it early, including via the emergency exit.
  cancelled,

  /// The foreground service that was enforcing the session stopped.
  serviceLost,

  /// The device restarted while the session was live.
  deviceRestarted,

  /// A required permission was revoked while the session was live.
  permissionRevoked,

  /// The app was replaced by an update (or reinstalled) mid-session.
  appUpdated;

  String get storage => name;

  static FocusEndReason? fromStorage(String? raw) {
    for (final r in FocusEndReason.values) {
      if (r.storage == raw) return r;
    }
    return null;
  }
}

/// One focus session, as stored.
///
/// The mutable fields are checkpointed by `FocusRepository` on every meaningful
/// transition (start, pause, resume, tick, end) inside a transaction, which is what
/// makes recovery after a process death a matter of arithmetic rather than
/// guesswork.
class FocusSession {
  FocusSession({
    required this.id,
    required this.mode,
    required this.plannedMinutes,
    required this.goalLabel,
    this.commitmentId,
    required this.startedAtWallMs,
    required this.startedAtRealtimeMs,
    this.segmentStartedAtRealtimeMs,
    this.pausedAtWallMs,
    this.focusMs = 0,
    this.pausedMs = 0,
    this.state = FocusSessionState.running,
    this.outcome,
    this.enforcement = FocusEnforcement.timerOnly,
    this.endReason,
    this.blockedAttempts = 0,
    this.overlayShows = 0,
    this.detectionEvents = 0,
    this.timingVerified = true,
    this.blockedPackages = const <String>[],
    this.endedAtWallMs,
    this.reflection,
    required this.day,
    this.source = 'manual',
  });

  final String id;
  final FocusMode mode;
  final int plannedMinutes;

  /// What the user said they were focusing on, in their own words. Either a
  /// commitment's name or free text — never invented, and never empty (the UI
  /// supplies "Focus session" as the default rather than leaving a blank).
  final String goalLabel;

  /// The routine this session was started from, when there was one. The FK is
  /// `ON DELETE SET NULL`, so deleting a routine never deletes the focused time
  /// the user actually spent; the session keeps its own [goalLabel] text.
  final String? commitmentId;

  final int startedAtWallMs;

  /// `SystemClock.elapsedRealtime()` at start: monotonic, unaffected by the user
  /// changing the clock, and — importantly — reset only by a reboot, which is how
  /// a restart is detected.
  final int startedAtRealtimeMs;

  /// Realtime clock at the start of the segment currently accruing focus time.
  /// Null while paused. On resume it is set to now, which is what makes
  /// `focusMs + (now - segmentStartedAtRealtimeMs)` correct across any number of
  /// pauses.
  final int? segmentStartedAtRealtimeMs;

  /// Wall clock at the start of the current pause, or null when the session is not
  /// paused. Stored so a pause has a definite beginning: without it, a session that
  /// was paused, killed by the OS and reopened could not tell whether the user came
  /// back in a minute or an hour, and would report focus time it did not have.
  final int? pausedAtWallMs;

  /// Focus time banked before the current segment. Never includes paused time.
  final int focusMs;
  final int pausedMs;

  final FocusSessionState state;
  final FocusOutcome? outcome;
  final FocusEnforcement enforcement;
  final FocusEndReason? endReason;

  /// How many times a blocked app was brought to the foreground during this
  /// session, as counted by the platform. Zero is a normal, good number.
  final int blockedAttempts;

  /// How many times the block surface was actually shown, and how many foreground
  /// events the detector saw. The second number is the evidence that detection
  /// works at all on this device — see [FocusEnforcement.armed].
  final int overlayShows;
  final int detectionEvents;

  /// False when the monotonic clock was unavailable and the session had to be
  /// timed with the wall clock. Recorded rather than hidden: it changes how much
  /// the timings can be trusted, and a row that says so is more useful than one
  /// that pretends.
  final bool timingVerified;

  final List<String> blockedPackages;
  final int? endedAtWallMs;
  final String? reflection;

  /// Local day key (`yyyymmdd`) the session is attributed to — the day it started.
  final int day;

  /// manual | import. No seeder can write here: there is no seeder.
  final String source;

  bool get isLive => state == FocusSessionState.running || state == FocusSessionState.paused;
  bool get isPaused => state == FocusSessionState.paused;

  int get plannedMs => plannedMinutes * 60 * 1000;

  /// Total clock time the session occupied, including pauses.
  int get wallSpanMs => focusMs + pausedMs;

  Duration get focusDuration => Duration(milliseconds: focusMs);

  FocusSession copyWith({
    FocusSessionState? state,
    FocusOutcome? outcome,
    FocusEnforcement? enforcement,
    FocusEndReason? endReason,
    int? segmentStartedAtRealtimeMs,
    bool clearSegment = false,
    int? pausedAtWallMs,
    bool clearPause = false,
    int? focusMs,
    int? pausedMs,
    int? blockedAttempts,
    int? overlayShows,
    int? detectionEvents,
    bool? timingVerified,
    List<String>? blockedPackages,
    int? endedAtWallMs,
    String? reflection,
  }) =>
      FocusSession(
        id: id,
        mode: mode,
        plannedMinutes: plannedMinutes,
        goalLabel: goalLabel,
        commitmentId: commitmentId,
        startedAtWallMs: startedAtWallMs,
        startedAtRealtimeMs: startedAtRealtimeMs,
        segmentStartedAtRealtimeMs: clearSegment ? null : (segmentStartedAtRealtimeMs ?? this.segmentStartedAtRealtimeMs),
        pausedAtWallMs: clearPause ? null : (pausedAtWallMs ?? this.pausedAtWallMs),
        focusMs: focusMs ?? this.focusMs,
        pausedMs: pausedMs ?? this.pausedMs,
        state: state ?? this.state,
        outcome: outcome ?? this.outcome,
        enforcement: enforcement ?? this.enforcement,
        endReason: endReason ?? this.endReason,
        blockedAttempts: blockedAttempts ?? this.blockedAttempts,
        overlayShows: overlayShows ?? this.overlayShows,
        detectionEvents: detectionEvents ?? this.detectionEvents,
        timingVerified: timingVerified ?? this.timingVerified,
        blockedPackages: blockedPackages ?? this.blockedPackages,
        endedAtWallMs: endedAtWallMs ?? this.endedAtWallMs,
        reflection: reflection ?? this.reflection,
        day: day,
        source: source,
      );
}

/// The arithmetic outcome of reading a session back after the app was away.
///
/// Produced by `FocusEngine.recover`, never guessed: every field is either a
/// measurement or an explicit admission that a measurement was unavailable.
class FocusRecovery {
  const FocusRecovery({
    required this.session,
    required this.elapsedMs,
    required this.remainingMs,
    required this.expired,
    required this.rebooted,
    required this.monotonicTrusted,
    required this.clockMovedBackwards,
    required this.timedOutWhileAway,
    required this.staleByMs,
  });

  final FocusSession session;

  /// Focus time served so far, pauses excluded.
  final int elapsedMs;
  final int remainingMs;

  /// The planned time is behind us.
  final bool expired;

  /// The monotonic clock ran backwards, which on Android means the device
  /// restarted. `elapsedMs` then falls back to the last checkpoint, because
  /// claiming the missing time would be inventing it.
  final bool rebooted;

  /// False when the session had to be timed from the wall clock (no platform
  /// channel / no Android). Recorded on the session.
  final bool monotonicTrusted;

  /// The wall clock moved backwards — a user setting the date, or a timezone
  /// database correction. The monotonic clock wins; this is only used to explain
  /// the discrepancy in the history.
  final bool clockMovedBackwards;

  /// The countdown finished while the app was not running. The session is not
  /// silently marked complete: it is ended, and its enforcement during the unseen
  /// stretch is exactly what it was at the last checkpoint.
  final bool timedOutWhileAway;

  /// How long ago the last checkpoint was written, when that is knowable.
  final int staleByMs;

  Duration get elapsed => Duration(milliseconds: elapsedMs);
  Duration get remaining => Duration(milliseconds: remainingMs);

  double get progress =>
      session.plannedMs <= 0 ? 1 : (elapsedMs / session.plannedMs).clamp(0.0, 1.0).toDouble();
}

/// A reusable rule set: mode + duration + the apps to restrict. Pro.
class FocusProfile {
  const FocusProfile({
    required this.id,
    required this.name,
    required this.mode,
    required this.minutes,
    this.commitmentId,
    this.packages = const <String>[],
    this.sort = 0,
  });

  final String id;
  final String name;
  final FocusMode mode;
  final int minutes;
  final String? commitmentId;
  final List<String> packages;
  final int sort;

  FocusProfile copyWith({String? name, FocusMode? mode, int? minutes, String? commitmentId, List<String>? packages, int? sort}) =>
      FocusProfile(
        id: id,
        name: name ?? this.name,
        mode: mode ?? this.mode,
        minutes: minutes ?? this.minutes,
        commitmentId: commitmentId ?? this.commitmentId,
        packages: packages ?? this.packages,
        sort: sort ?? this.sort,
      );
}

/// A recurring reminder to *start* a focus session. Pro.
///
/// Note what this is and is not: it schedules a notification at the chosen time
/// with a "Start now" action. It does **not** start enforcement silently. Two
/// reasons, both deliberate: an app that begins covering other apps without the
/// user present is the behaviour users correctly describe as malware, and Android
/// restricts starting a foreground service from the background. The scheduled
/// session is a prompt; the session begins when the person taps it.
class FocusSchedule {
  const FocusSchedule({
    required this.id,
    required this.mode,
    required this.minutes,
    required this.hour,
    required this.minute,
    required this.weekdays,
    this.commitmentId,
    this.packages = const <String>[],
    this.enabled = true,
    required this.notificationId,
  });

  final String id;
  final FocusMode mode;
  final int minutes;
  final int hour;
  final int minute;

  /// ISO weekdays, 1 = Monday … 7 = Sunday. Empty means "every day".
  final Set<int> weekdays;
  final String? commitmentId;
  final List<String> packages;
  final bool enabled;

  /// The **base** id used with `NotificationService`, stored so a schedule can
  /// always cancel exactly what it scheduled. The service adds the weekday (1–7) for
  /// weekday-targeted reminders, and cancels the whole `base..base+7` range, because
  /// a leftover reminder that fires at the wrong time is worse than none.
  final int notificationId;

  String get label => '${_two(hour)}:${_two(minute)}';

  static String _two(int v) => v < 10 ? '0$v' : '$v';

  FocusSchedule copyWith({bool? enabled, int? hour, int? minute, Set<int>? weekdays, List<String>? packages}) =>
      FocusSchedule(
        id: id,
        mode: mode,
        minutes: minutes,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
        weekdays: weekdays ?? this.weekdays,
        commitmentId: commitmentId,
        packages: packages ?? this.packages,
        enabled: enabled ?? this.enabled,
        notificationId: notificationId,
      );
}

/// One focus session's shape for the agenda-free summary the session screen shows
/// at the end. Built from the stored row, so the summary cannot disagree with the
/// record.
class FocusSummary {
  const FocusSummary({
    required this.session,
    required this.headline,
    required this.detail,
    required this.cleanlinessNote,
    required this.blockedApps,
    required this.minutesFocused,
  });

  final FocusSession session;
  final String headline;
  final String detail;

  /// The sentence that explains a degraded or interrupted outcome in plain words.
  /// Empty for a clean completion, which needs no excuse.
  final String cleanlinessNote;

  final List<String> blockedApps;
  final int minutesFocused;
}

/// Aggregate focus figures, with the sample they came from.
///
/// Every nullable field is null because there is not enough evidence for it yet —
/// the same discipline as `MomentumSnapshot.rate`. A screen that wants to print a
/// number has to handle the null, which is how the threshold survives contact with
/// a fresh install.
class FocusStats {
  const FocusStats({
    required this.endedSessions,
    required this.completed,
    required this.degraded,
    required this.interrupted,
    required this.cancelled,
    required this.minutesLast7Days,
    required this.minutesTotal,
    required this.cleanStreak,
    required this.typicalStartMinute,
  });

  final int endedSessions;
  final int completed;
  final int degraded;
  final int interrupted;
  final int cancelled;

  /// Minutes from sessions that served their time (clean or degraded). A cancelled
  /// or interrupted session contributes nothing: Track Pro does not round up.
  final int minutesLast7Days;
  final int minutesTotal;

  /// Consecutive most-recent ended sessions that were clean completions.
  final int cleanStreak;

  /// Median start-of-day minute across clean or degraded sessions, or null below
  /// [minSessionsForPattern]. Null means "not enough of a habit to describe one".
  final int? typicalStartMinute;

  bool get hasAny => endedSessions > 0;

  /// Share of ended sessions that were fully enforced, or null below
  /// [minSessionsForShare]: two sessions is not a rate.
  double? get cleanShare =>
      endedSessions < minSessionsForShare ? null : completed / endedSessions * 100;

  /// Ended sessions spent actually focusing, as a share of ended time. Null below
  /// the same threshold. This is the number that separates "I use focus sessions"
  /// from "I have started focus sessions".
  double? get servedShare => endedSessions < minSessionsForShare
      ? null
      : (completed + degraded) / endedSessions * 100;

  /// Below this many ended sessions, no share is reported.
  static const int minSessionsForShare = 3;

  /// Below this many sessions that served their time, no "you usually focus at …"
  /// claim is made. A pattern needs a habit behind it.
  static const int minSessionsForPattern = 5;

  static const FocusStats empty = FocusStats(
    endedSessions: 0,
    completed: 0,
    degraded: 0,
    interrupted: 0,
    cancelled: 0,
    minutesLast7Days: 0,
    minutesTotal: 0,
    cleanStreak: 0,
    typicalStartMinute: null,
  );
}
