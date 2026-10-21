import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../config/app_environment.dart';
import '../config/pro_config.dart';
import '../data/commitment_repository.dart';
import '../data/cycle_stats.dart';
import '../data/db/database.dart';
import '../data/default_trackers.dart';
import '../data/momentum.dart';
import '../data/entry_repository.dart';
import '../data/focus_engine.dart';
import '../data/focus_repository.dart';
import '../data/insights_engine.dart';
import '../data/value_validation.dart';
import '../models/focus_models.dart';
import '../models/models.dart';
import '../services/billing_service.dart';
import '../services/pro_analytics.dart';
import '../services/haptics.dart';
import '../services/focus_platform.dart';
import '../services/health_service.dart';
import '../services/notification_service.dart';
import '../services/screen_time_service.dart';
import '../services/widget_bridge.dart';
import '../util/day_key.dart';
import '../util/format.dart';

/// Single source of truth for the UI. All persistence is delegated to
/// [EntryRepository] (Drift/SQLite); this class keeps the in-memory projection
/// the screens read during scroll, so nothing rebuilds from a query mid-frame.
class AppState extends ChangeNotifier {
  AppState({
    required this.repo,
    required this.commitmentRepo,
    this.focusRepo,
    this.health,
    this.screenTime,
    this.notifications,
    this.widgetBridge,
    this.billing,
    this.analytics,
    this.packageName = 'com.track.app',
  });

  final EntryRepository repo;

  /// Momentum storage. Separate from [repo] because habits and measurements are
  /// different things: a tracker answers "how much", a commitment answers "did you".
  final CommitmentRepository commitmentRepo;

  /// Focus Lock storage. Nullable so a test or a build without the native channel
  /// can construct the app state; when it is null the feature reports itself as
  /// unavailable rather than pretending to run a session. `main()` always passes one.
  FocusRepository? focusRepo;

  final HealthService? health;

  /// Usage Access screen-time readings. Nullable like [health]: a test host or a
  /// non-Android build constructs the state without it, and the Screen time
  /// tracker then behaves exactly as it always did — manual entry only.
  final ScreenTimeService? screenTime;
  final NotificationService? notifications;
  final WidgetBridge? widgetBridge;

  /// Play Billing. Null in tests and on platforms without a store — every call
  /// site null-checks rather than pretending billing always exists.
  BillingService? billing;
  ProAnalytics? analytics;

  /// Used for the "manage subscription" deep link and server verification.
  final String packageName;

  final List<Tracker> trackers = <Tracker>[];
  final Map<String, List<double>> history = <String, List<double>>{};
  final List<String> added = <String>[];
  final List<Habit> habits = <Habit>[];
  final List<Transaction> transactions = <Transaction>[];
  final List<CategoryTotal> categories = <CategoryTotal>[];

  bool isDark = false;
  bool onboarded = false;
  int tabIndex = 0;
  String _range = 'week';
  bool editing = false;

  /// Current Pro entitlement. Defaults to free, so a crash in billing can never
  /// accidentally unlock everything.
  Entitlement entitlement = Entitlement.free;
  DateTime? softPromptLastShown;

  /// SQL-derived counts, refreshed opportunistically (the "1,284 entries" tiles).
  /// These are the honest replacements for the hardcoded numbers the first draft
  /// shipped: if the database says 0, the tile says 0.
  int entryCount = 0;
  int trackedDays = 0;
  int healthSyncedDays = 0;
  int demoRowCount = 0;
  DateTime? lastSync;

  /// Health Connect's actual standing, read from the OS rather than remembered.
  /// `unknown` until asked: on a device without Health Connect, "not connected" and
  /// "no permission" are different problems with different fixes, and guessing
  /// between them would put the wrong instruction on screen.
  HealthPermissionState healthPermission = HealthPermissionState.unknown;

  /// Android Usage Access standing for the Screen time tracker's auto-fill.
  /// Same rule as [healthPermission]: re-read from the OS on every resume, never
  /// remembered as truth — a grant revoked in system settings must stop showing
  /// "auto-filled" the moment the app comes back.
  ScreenTimePermissionState screenTimePermission = ScreenTimePermissionState.unknown;

  /// When the usage-stats auto-fill last wrote tracker rows. Null until the
  /// first successful sync; the Screen time detail view shows it so "chart
  /// filled" and "chart stale" are distinguishable.
  DateTime? screenTimeLastSync;

  /// Today's per-app split, straight from the platform. Empty when there is no
  /// grant or no reading — never fabricated.
  List<ScreenTimeAppUsage> screenTimeApps = <ScreenTimeAppUsage>[];

  /// True while a sync is in flight, so the UI can spin instead of lying.
  bool screenTimeSyncing = false;

  /// Set when the user says "not now" to the launch permission notice.
  ///
  /// Deliberately not persisted: it silences the card for this run of the app and no
  /// longer. A permission that is still missing when the app is next opened is still
  /// worth one quiet sentence, and the card is not a modal prompt, so it never blocks
  /// anything or asks twice in a row.
  bool permissionNoticeDismissed = false;

  void dismissPermissionNotice() {
    permissionNoticeDismissed = true;
    notifyListeners();
  }

  /// The last write that failed, if any.
  ///
  /// This exists because the alternative — the previous behaviour — was to swallow the
  /// error, keep the optimistic value in the cache, and let the UI confirm a save that
  /// SQLite never received. The value would look right until the next launch and then
  /// silently revert. Nothing in the app may present an unsaved change as saved, so the
  /// failure is recorded here, the projection is re-derived from the store, and
  /// `HomeShell` shows it.
  SaveFailure? writeFailure;

  /// Whether Health Connect is connected right now, according to the OS.
  ///
  /// A convenience for the two places that word a message differently for a connected
  /// device and an unconnected one — and the reason those places cannot say "permission
  /// needed" to a free user, or "connected" after a revocation.
  bool get healthConnected => healthPermission == HealthPermissionState.granted;

  /// Whether Android is filling the Screen time tracker automatically right now.
  bool get screenTimeConnected => screenTimePermission == ScreenTimePermissionState.granted;

  /// True when the build has any usage-stats capability at all (Android + the
  /// native channel). False on Linux desktop and in tests, where the UI must
  /// not offer a grant flow that cannot exist.
  bool get screenTimeAvailable => screenTime != null;

  /// Clears the banner. The data has already been re-read from the store by then, so
  /// dismissing this hides a message, not a problem.
  void acknowledgeWriteFailure() {
    if (writeFailure == null) return;
    writeFailure = null;
    notifyListeners();
  }

  /// Fresh-install truth, so every screen can show an empty state instead of a
  /// chart with nothing in it.
  bool hasAnyData = false;
  bool integrityOk = true;
  List<SourceCount> sourceCounts = <SourceCount>[];

  /// The calorie log from the event table, newest first.
  List<FoodEntry> foodEntries = <FoodEntry>[];

  /// Per-tracker activity buckets for today, refreshed with the aggregates.
  final Map<String, RhythmBuckets> _rhythms = <String, RhythmBuckets>{};

  /// User-entered height, needed for BMI. Null until they set it — the BMI tile
  /// says so rather than inventing a number.
  double? heightCm;

  // ------------------------------------------------------------------ momentum
  /// Derived from the commitment rows on every aggregate refresh. `rate` is null
  /// inside every snapshot until that commitment has enough decided days; the UI
  /// renders the sample instead of a percentage.
  Map<String, MomentumSnapshot> momentum = <String, MomentumSnapshot>{};

  /// The same figure across every live commitment. Null when there is nothing to
  /// compute — which is not the same as zero, and is never shown as zero.
  MomentumSnapshot? overallMomentum;

  /// Monday-to-Sunday review of the current week, from real records.
  WeeklyReview? weeklyReview;

  /// What the one-time conversion of an install's legacy habit checklist did, so
  /// Settings can state it rather than leaving the user to wonder where their old
  /// ticks went.
  LegacyImportReport? legacyImportReport;

  // ------------------------------------------------------- reminder preferences
  // These are read by `_syncNotifications`, so every switch in Settings changes
  // what actually gets scheduled. (They used to be widget-local booleans that
  // toggled nothing and forgot themselves on rebuild.)
  bool notifyDaily = true;
  bool notifyStreakSaver = true;
  bool notifyWeekly = true;

  /// When false, reminder bodies name the trackers that are still open. Off by
  /// default: a lock screen is readable by whoever is holding the phone.
  bool lockScreenDetails = false;

  /// Whether the OS currently allows notifications at all.
  bool notificationsAllowed = false;

  /// Computed from real rows on every aggregate refresh.
  List<Insight> insights = <Insight>[];
  CycleStats cycle = const CycleStats(
    starts: [],
    averageLength: 0,
    shortestLength: 0,
    longestLength: 0,
    lastStart: null,
    currentCycleDay: null,
    periodLengthAvg: 0,
  );

  /// True once the user has logged enough days for patterns to be meaningful.
  bool get hasEnoughForPatterns =>
      insights.isNotEmpty && insights.first.sampleDays >= InsightsEngine.minLoggedDaysForPatterns;

  int get days => repo.windowDays;

  /// The day the user's own history starts, or null when there is none yet.
  DateTime? trackingSince;

  /// Days actually held in memory (the repository's cache window). The 90-day Pro
  /// range is drawn from this, so a chart never indexes past its own series.
  int get loadedDays => history.values.isEmpty ? days : history.values.first.length;

  List<Tracker> get visibleTrackers =>
      trackers.where((t) => !t.hidden).toList()..sort((a, b) => a.order.compareTo(b.order));

  Tracker byId(String id) => trackers.firstWhere((t) => t.id == id);

  /// The catalogue entry for [id], or null when there is none.
  ///
  /// Every write path resolves the tracker through this **before** it touches the
  /// in-memory projection. `byId` throws on an unknown id, and a throw halfway
  /// through a write is the worst of both worlds: the cache has already been
  /// painted with a value that was never stored, and a series was created for a
  /// tracker that does not exist.
  Tracker? trackerOrNull(String id) {
    for (final t in trackers) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// The value to show for "today" on a tracker: the last slot of the loaded
  /// series, or zero when the tracker has no series in memory. Zero means "nothing
  /// logged", which is exactly what the rings already render; the previous
  /// `history[id]!.last` threw a null/range error instead, on any id the projection
  /// did not carry.
  double today(String id) {
    final h = history[id];
    return (h == null || h.isEmpty) ? 0 : h.last;
  }

  /// The last seven points of a series, clamped to what is in memory. Delegates to
  /// [series] for the same reason it exists: a short series is a short list, never a
  /// RangeError.
  List<double> week(String id) => series(id, 7);

  /// Mean of the last [n] points. Zero when there is nothing to average — callers
  /// already treat a zero average as "no data" (the projection is zero-filled), and
  /// an empty list has no mean to report.
  double avg(String id, int n) {
    final w = series(id, n);
    if (w.isEmpty) return 0;
    return w.reduce((a, b) => a + b) / w.length;
  }

  /// The loaded series for a tracker, or an empty list when the projection does not
  /// carry it. Read-side callers use this instead of `history[id]!`, so a tracker
  /// that was deleted, renamed or never loaded degrades to an empty chart rather
  /// than a crash.
  List<double> historyOf(String id) => history[id] ?? const <double>[];

  /// A *writable* series for a tracker: created zero-filled when absent, so a write
  /// to the current slot can never land out of range. (Reads never create one.)
  List<double> _writableSeries(String id) =>
      history.putIfAbsent(id, () => List<double>.filled(EntryRepository.cacheDays, 0));

  /// The last [n] points of a series, clamped to what is actually in memory.
  ///
  /// Charts must not index past the end of their own series: on a fresh install
  /// there are fewer than 14 days of history, and `history['mood']![i - 14]`
  /// threw a RangeError there. Callers get a short list and decide what that
  /// means, rather than a crash or a fabricated point.
  List<double> series(String id, int n) {
    final h = history[id];
    if (h == null || h.isEmpty) return const <double>[];
    final take = n > h.length ? h.length : n;
    return h.sublist(h.length - take);
  }

  /// Days in the last [n] on which *both* series have a real value. Used before
  /// drawing a cross-tracker chart so a missing day becomes a gap, not a zero.
  List<double> paired(String a, String b, int n, double Function(double, double) combine) {
    final x = series(a, n);
    final y = series(b, n);
    final len = x.length < y.length ? x.length : y.length;
    return [
      for (var i = 0; i < len; i++)
        if (x[i] > 0 && y[i] > 0) combine(x[i], y[i]),
    ];
  }

  double best(String id) {
    final h = historyOf(id);
    if (h.isEmpty) return 0;
    final prev = h.sublist(0, h.length - 1);
    return prev.isEmpty ? h.last : prev.reduce((a, b) => a > b ? a : b);
  }

  /// The one streak rule in the app: consecutive days at or above 70 % of the
  /// tracker's goal, counted backwards from today over the loaded projection
  /// (`util/format.dart`'s `streakOf`). It reads the projection rather than running
  /// a query so a chip never flickers mid-write.
  ///
  /// There used to be a second, SQL-side implementation of the same idea on
  /// `EntryRepository`; it treated a run ending yesterday as broken while this one
  /// does not, and nothing called it. One number, one rule.
  int streak(String id) => streakOf(byId(id), historyOf(id));

  /// The longest streak currently running across the visible trackers, computed
  /// from the projection. Zero on a fresh install — which is the honest answer,
  /// not a headline.
  int get bestStreak {
    var best = 0;
    for (final t in visibleTrackers) {
      final s = streak(t.id);
      if (s > best) best = s;
    }
    return best;
  }

  /// Which of the last [n] days have any logged value at all. Drives the streak
  /// dots, so they show the user's real pattern including the gaps.
  List<bool> loggedFlags(int n) {
    final length = history.values.isEmpty ? 0 : history.values.first.length;
    final take = n > length ? length : n;
    return [
      for (var i = length - take; i < length; i++) history.values.any((series) => i < series.length && series[i] > 0),
    ];
  }

  /// Days logged inside the window the user can actually see (free: 7, Pro: 90).
  int loggedDaysInWindow(int n) => loggedFlags(n).where((f) => f).length;

  /// Today's activity buckets for one tracker, or null if none were computed.
  RhythmBuckets? rhythmFor(String trackerId) => _rhythms[trackerId];

  /// Loads today's rhythm buckets for one tracker into the projection.
  ///
  /// `_rhythms` used to be declared, documented ("refreshed with the aggregates")
  /// and read by the detail screen — and never written by anything. The query behind
  /// it ([EntryRepository.rhythm]) had no caller at all, so the "when in the day do
  /// you drink" panel fell through to its empty state for every user, forever, no
  /// matter how much they logged.
  ///
  /// It is filled **on demand, for the screen that is open**, rather than in
  /// `_refreshAggregates`: that runs after every write and would turn one tap into
  /// N event-table queries for N trackers, most of them not on screen.
  Future<void> refreshRhythm(String trackerId) async {
    final buckets = await repo.rhythm(trackerId);
    if (_disposed) return; // the notifier is dead; nobody is left to tell
    _rhythms[trackerId] = buckets;
    notifyListeners();
  }

  /// Completion rate for one habit over the last [days] days.
  ///
  /// Denominator is the number of days the checklist was actually used — not the
  /// full window — so a habit added yesterday cannot read "3% of 30 days".
  int habitRate(int index, int days) {
    final completions = repo.habitCompletions;
    var used = 0;
    var hit = 0;
    for (var back = 0; back < days; back++) {
      // Calendar stepping via `dayKeyFromToday`, not `DateTime.now().subtract(
      // Duration(days:))`: the latter is elapsed time, and on a 23- or 25-hour day
      // it reads the same key twice or skips one, silently rewriting that day's rate.
      final key = dayKeyFromToday(back);
      final day = completions[key];
      if (day == null) continue;
      used++;
      // Indices are positional: a removed habit shifts the ones after it, so a
      // stale index simply stops counting rather than crediting the wrong habit.
      if (index < habits.length && day.contains(index)) hit++;
    }
    if (used == 0) return 0;
    return (hit / used * 100).round();
  }

  /// BMI from the latest logged weight and the user's own height.
  /// Null unless both exist — the UI shows "set height" instead of a guess.
  double? get bmi {
    final h = heightCm;
    final w = history['weight'];
    if (h == null || h <= 0 || w == null) return null;
    final latest = [
      for (final v in w)
        if (v > 0) v,
    ];
    if (latest.isEmpty) return null;
    final meters = h / 100;
    return latest.last / (meters * meters);
  }

  bool isLoggedToday(String id) {
    final t = byId(id);
    if (id == 'period' || id == 'weight') return true;
    return ringPct(t, today(id)) >= .2;
  }

  List<Tracker> get sortedByHealth {
    final list = visibleTrackers.toList();
    list.sort((a, b) => ringPct(b, today(b.id)).compareTo(ringPct(a, today(a.id))));
    return list;
  }

  // ---------------------------------------------------------------- Focus Lock
  // The state layer's job here is narrow on purpose: mirror the repository, own the
  // cached permission state, and hold the small amount of arithmetic the UI needs
  // every frame. Every rule about what a session *is* lives in `FocusEngine`, and
  // every fact about what happened lives in the row — which is why this block has no
  // ability to decide that a session completed.

  /// Ended focus sessions, newest first.
  List<FocusSession> focusHistory = <FocusSession>[];

  /// Aggregate figures, recomputed whenever a session ends. The nullable fields on
  /// [FocusStats] stay null below their sample thresholds.
  FocusStats focusStats = FocusStats.empty;

  /// What the device has granted, refreshed on load, on resume, and before every
  /// start. Never cached beyond a single action: a permission can be revoked from
  /// system settings at any moment, and a stale "granted" would become a false
  /// claim that something was blocked.
  FocusPermissions focusPermissions = FocusPermissions.none;

  /// The platform's view of the running enforcement service.
  FocusNativeState focusNative = FocusNativeState.idle;

  List<FocusProfile> focusProfiles = <FocusProfile>[];
  List<FocusSchedule> focusSchedules = <FocusSchedule>[];

  /// Focus time logged today, from the rows. Shown on Today's card.
  int focusTodayMinutes = 0;

  /// Countdown mirrors, updated by [tickFocus] from the monotonic clock. Kept as
  /// plain fields so a 1 Hz redraw does not rebuild the whole screen tree from a
  /// database read.
  int focusRemainingMs = 0;
  int focusElapsedMs = 0;

  /// True when Track Pro's own reminders are being held for the duration of a session.
  /// Other apps' notifications are **not** touched: silencing them needs Do Not
  /// Disturb access, which this app deliberately never requests.
  bool focusHoldsReminders = false;

  /// Whether the native side exists at all on this build/device.
  bool focusPlatformAvailable = false;

  bool get hasFocusSupport => focusRepo != null;
  bool get focusLive => activeFocusSession != null;
  bool get focusPaused => activeFocusSession?.state == FocusSessionState.paused;

  FocusSession? get activeFocusSession => focusRepo?.liveSession;

  /// The enforcement state of the live session, or `timerOnly` when nothing is
  /// running. The UI prints this rather than deciding anything itself.
  FocusEnforcement get focusEnforcement {
    final session = activeFocusSession;
    if (session == null) return FocusEnforcement.timerOnly;
    // A pause intentionally stops the coverage service. Preserve the state that
    // was evidenced before the pause instead of showing a false "service lost"
    // banner merely because the native service is correctly idle.
    if (session.state == FocusSessionState.paused) return session.enforcement;
    // A live session's enforcement is re-derived from the platform on every tick,
    // so a permission revoked thirty seconds ago is reflected now.
    if (session.enforcement.intendsToBlock) {
      final permissionLostMidSession =
          session.enforcement != FocusEnforcement.unavailable && (!focusNative.overlay || !focusNative.usageAccess);
      final reported = FocusEngine.enforcementFor(
        blockingRequested: true,
        serviceAlive: focusNative.running && focusNative.blocking,
        permissionLostMidSession: permissionLostMidSession,
        overlayGranted: focusNative.overlay,
        usageAccessGranted: focusNative.usageAccess,
        detectionEvents: focusNative.detectionEvents,
        overlayShows: focusNative.overlayShows,
      );
      // Once a live session had an unprotected interval, a later re-grant cannot
      // make that interval disappear from the UI or the eventual record. `armed`
      // remains upgradeable because it is a healthy-but-not-yet-proven service,
      // not evidence of a gap.
      if (session.enforcement == FocusEnforcement.lost) return FocusEnforcement.lost;
      if (session.enforcement == FocusEnforcement.unavailable &&
          reported != FocusEnforcement.unavailable &&
          reported != FocusEnforcement.timerOnly) {
        return FocusEnforcement.lost;
      }
      return reported;
    }
    return session.enforcement;
  }

  /// Whether a session in this mode can actually restrict apps right now.
  bool get focusCanBlock => focusPlatformAvailable && focusPermissions.canBlock;

  /// The apps a session may cover: everything the platform can see that is not
  /// protected (dialer, launcher, system UI, keyboards, Track Pro itself).
  List<FocusAppInfo> focusApps = <FocusAppInfo>[];

  // ------------------------------------------------------------------- limits
  /// Free keeps three covered apps per session; Pro keeps the whole list.
  bool get canBlockMoreApps => isPro || _blockedAppCount < ProConfig.freeBlockedApps;
  bool get canUseFocusProfiles => isPro;
  bool get canUseFocusSchedules => isPro;
  bool get canSeeFocusAnalytics => isPro;

  int _blockedAppCount = 0;

  /// How many apps the session being configured would cover. Set by the setup sheet
  /// so the limit can be explained before the session starts rather than after.
  void setFocusDraftAppCount(int count) {
    if (_blockedAppCount == count) return;
    _blockedAppCount = count < 0 ? 0 : count;
    notifyListeners();
  }

  /// The history a free user sees. Pro sees all of it. Note this gates *reading old
  /// sessions*, never the session that just finished — that summary is shown
  /// immediately, and the row is kept regardless of tier.
  List<FocusSession> get visibleFocusHistory =>
      canSeeFocusAnalytics ? focusHistory : focusHistory.take(ProConfig.freeFocusHistorySessions).toList();

  int get hiddenFocusSessions =>
      canSeeFocusAnalytics ? 0 : (focusHistory.length - ProConfig.freeFocusHistorySessions).clamp(0, 1 << 30).toInt();

  // ------------------------------------------------------------- permissions
  /// Re-reads the device's grants. Never grants anything itself, and never touches
  /// the entitlement: enabling a permission is not a purchase, and treating it as
  /// one would be the single most dishonest thing this app could do.
  Future<void> refreshFocusPermissions() async {
    final repo = focusRepo;
    if (repo == null) return;
    focusPlatformAvailable = await repo.enforcer.isAvailable;
    focusPermissions = await repo.enforcer.permissions();
    if (activeFocusSession != null) {
      focusNative = await repo.enforcer.state();
    }
    notifyListeners();
  }

  Future<void> openUsageAccessSettings() async => focusRepo?.enforcer.openUsageAccessSettings();
  Future<void> openOverlaySettings() async => focusRepo?.enforcer.openOverlaySettings();
  Future<void> openNotificationSettings() async => focusRepo?.enforcer.openNotificationSettings();
  Future<void> openBatterySettings() async => focusRepo?.enforcer.openBatterySettings();

  /// The installed-app list for the picker. Loaded on demand: enumerating the
  /// launcher's apps costs a few hundred milliseconds, and no screen needs it until
  /// the user opens the picker.
  Future<List<FocusAppInfo>> loadFocusApps() async {
    final repo = focusRepo;
    if (repo == null) return const <FocusAppInfo>[];
    if (focusApps.isEmpty) {
      focusApps = await repo.enforcer.installedApps();
      notifyListeners();
    }
    return focusApps;
  }

  // ------------------------------------------------------------------ session
  /// Starts a session. The caller decides the mode; enforcement is whatever the
  /// platform reports, and a session that asked for blocking but cannot have it is
  /// flagged as degraded from the first tick rather than at the end.
  Future<FocusSession?> startFocus({
    required FocusMode mode,
    required int minutes,
    List<String> packages = const <String>[],
    String? commitmentId,
    String? goalLabel,
    int accentArgb = 0xFFFF7A18,
  }) async {
    final repo = focusRepo;
    if (repo == null) return null;
    // Null, not the existing session: every caller turns null into "a session is
    // already running". Returning the live row made that message unreachable while
    // the caller pushed a second copy of the session screen on top of the first.
    if (repo.liveSession != null) return null;
    final session = await repo.start(
      mode: mode,
      minutes: minutes,
      requestedPackages: packages,
      commitmentId: commitmentId,
      goalLabel: goalLabel,
      accentArgb: accentArgb,
    );
    await refreshFocusState();
    await _holdRemindersDuringFocus();
    Haptics.commit();
    return session;
  }

  Future<void> pauseFocus() async {
    await focusRepo?.pause();
    await refreshFocusState();
    Haptics.light();
  }

  Future<void> resumeFocus() async {
    await focusRepo?.resume();
    await refreshFocusState();
    Haptics.light();
  }

  /// Ends the session by hand. The repository decides whether that is a cancelled
  /// session or a completion with the time already served.
  Future<FocusSession?> endFocus({String? reflection}) async {
    final repo = focusRepo;
    if (repo == null) return null;
    final ended = await repo.endByHand(reflection: reflection);
    await refreshFocusState();
    await _releaseHeldReminders();
    Haptics.commit();
    return ended;
  }

  /// The one-second tick the session screen drives. Cheap by construction: it reads
  /// the platform, recomputes the countdown from the monotonic clock, and writes to
  /// SQLite only when something actually moved.
  Future<void> tickFocus() async {
    final repo = focusRepo;
    if (repo == null || repo.liveSession == null) return;
    final session = await repo.syncNative();
    if (session == null) {
      // It ended during this tick: expiry, a stopped service, or a device restart.
      // Re-read the projections once so the history and the figures move together,
      // and release the reminder hold the session was keeping.
      await refreshFocusState(notify: false);
      await _releaseHeldReminders();
      notifyListeners();
      return;
    }
    // `syncNative` has already banked the elapsed figure against the monotonic clock
    // and re-based the segment, so the mirrors are read from it rather than by
    // repeating the same arithmetic (and another database read) every second.
    focusNative = await repo.enforcer.state();
    focusElapsedMs = session.focusMs;
    focusRemainingMs = (session.plannedMs - session.focusMs).clamp(0, session.plannedMs).toInt();
    notifyListeners();
  }

  /// Re-reads the projections and the figures after any focus write.
  Future<void> refreshFocusState({bool notify = true}) async {
    final repo = focusRepo;
    if (repo == null) return;
    focusHistory = repo.history;
    focusProfiles = repo.profiles;
    focusSchedules = repo.schedules;
    focusStats = await repo.stats(todayKey: repo.todayKey);
    focusTodayMinutes = repo.minutesOn(todayKey());

    // Keep the countdown mirrors truthful even when nobody is ticking yet: the first
    // frame after a cold start, or after returning from the background, must not show
    // a stale number.
    final live = repo.liveSession;
    if (live != null) {
      final monotonic = await repo.enforcer.monotonicMs();
      final recovery = FocusEngine.recover(
        session: live,
        nowRealtimeMs: monotonic ?? 0,
        nowWallMs: DateTime.now().millisecondsSinceEpoch,
        monotonicAvailable: monotonic != null,
      );
      focusElapsedMs = recovery.elapsedMs;
      focusRemainingMs = recovery.remainingMs;
      focusNative = await repo.enforcer.state();
    } else {
      focusElapsedMs = 0;
      focusRemainingMs = 0;
      focusNative = FocusNativeState.idle;
    }
    if (notify) notifyListeners();
  }

  /// Called once at load and again on every foreground.
  ///
  /// This is the whole crash-recovery path: a session that was live when the app
  /// died is ended here if it is over, and left running if it is not — with the
  /// elapsed time recomputed from the monotonic clock rather than from whenever the
  /// app last drew a frame.
  Future<void> recoverFocus() async {
    final repo = focusRepo;
    if (repo == null) return;
    await refreshFocusPermissions();
    final repaired = await repo.recover();
    if (repaired != null && repaired.state == FocusSessionState.ended) {
      _lastRecoveredFocusMs = repaired.focusMs;
      _lastRecoveredFocusOutcome = repaired.outcome;
    }
    await refreshFocusState(notify: false);
    await _releaseHeldReminders();
    if (repo.liveSession != null) await _holdRemindersDuringFocus();
    notifyListeners();
  }

  /// The session that recovery ended (if any), so a screen can tell the user their
  /// last session was resolved while they were away instead of silently changing the
  /// history under them.
  int? _lastRecoveredFocusMs;
  FocusOutcome? _lastRecoveredFocusOutcome;

  FocusOutcome? get lastRecoveredFocusOutcome => _lastRecoveredFocusOutcome;
  int get lastRecoveredFocusMs => _lastRecoveredFocusMs ?? 0;

  void acknowledgeRecoveredFocus() {
    _lastRecoveredFocusMs = null;
    _lastRecoveredFocusOutcome = null;
  }

  Future<void> setFocusReflection(String id, String? text) async {
    await focusRepo?.setReflection(id, text);
    await refreshFocusState();
  }

  /// Everything the Focus Lock screen needs to explain the last session it resolved
  /// without the app being open.
  FocusSummary? summaryFor(String id) {
    final session = focusRepo?.byId(id);
    return session == null ? null : FocusEngine.summaryFor(session);
  }

  // ------------------------------------------------------------- profiles/schedules
  Future<void> saveFocusProfile({
    String? id,
    required String name,
    required FocusMode mode,
    required int minutes,
    String? commitmentId,
    List<String> packages = const <String>[],
  }) async {
    await focusRepo?.saveProfile(
      id: id,
      name: name,
      mode: mode,
      minutes: minutes,
      commitmentId: commitmentId,
      packages: packages,
    );
    await refreshFocusState();
  }

  Future<void> deleteFocusProfile(String id) async {
    await focusRepo?.deleteProfile(id);
    await refreshFocusState();
  }

  Future<void> saveFocusSchedule({
    String? id,
    required FocusMode mode,
    required int minutes,
    required int hour,
    required int minute,
    Set<int> weekdays = const <int>{},
    String? commitmentId,
    List<String> packages = const <String>[],
    bool enabled = true,
  }) async {
    await focusRepo?.saveSchedule(
      id: id,
      mode: mode,
      minutes: minutes,
      hour: hour,
      minute: minute,
      weekdays: weekdays,
      commitmentId: commitmentId,
      packages: packages,
      enabled: enabled,
    );
    await syncFocusSchedules();
    await refreshFocusState();
  }

  Future<void> deleteFocusSchedule(String id) async {
    final repo = focusRepo;
    if (repo == null) return;
    // No `firstOrNull`: that extension lives in `package:collection`, which this
    // app does not depend on directly, so importing it would fail the
    // `depend_on_referenced_packages` lint (and, before this fix, would not
    // compile at all).
    final matches = repo.schedules.where((s) => s.id == id);
    final schedule = matches.isEmpty ? null : matches.first;
    if (schedule != null) await notifications?.cancelFocusSchedule(schedule.notificationId);
    await repo.deleteSchedule(id);
    await refreshFocusState();
  }

  /// Re-arms the scheduled-session reminders, honouring both the switch and the
  /// tier. Called from `syncReminders`, so a tier change that lapses (a cancelled
  /// subscription) also lapses the schedules it was entitled to.
  Future<void> syncFocusSchedules() async {
    final n = notifications;
    final repo = focusRepo;
    if (n == null || repo == null) return;
    for (final schedule in repo.schedules) {
      if (!isPro || !schedule.enabled) {
        await n.cancelFocusSchedule(schedule.notificationId);
        continue;
      }
      await n.scheduleFocusSession(
        id: schedule.notificationId,
        title: '${schedule.mode.label} · ${schedule.minutes} min',
        minuteOfDay: schedule.hour * 60 + schedule.minute,
        weekdays: schedule.weekdays,
      );
    }
  }

  /// Holds Track Pro's own reminders for the duration of a focus session.
  ///
  /// This is the honest half of "notification controls": the app can silence *its
  /// own* nudges without any extra permission, and it does. It cannot silence other
  /// apps, because that needs Do Not Disturb access — a permission this app does not
  /// request, and telling a user their notifications are blocked when they are not
  /// would be exactly the kind of claim this feature must never make.
  Future<void> _holdRemindersDuringFocus() async {
    final n = notifications;
    if (n == null || focusHoldsReminders) return;
    focusHoldsReminders = true;
    await n.cancelCheckIn();
    await n.cancelStreakSaver();
  }

  Future<void> _releaseHeldReminders() async {
    if (!focusHoldsReminders) return;
    focusHoldsReminders = false;
    await _syncNotifications();
  }

  /// Deletes focus sessions along with everything else. Routines/profiles survive
  /// "delete my data" for the same reason tracker definitions do: they are
  /// configuration, not history.
  Future<Map<String, int>> deleteAllFocusData({bool keepDefinitions = true}) async {
    final repo = focusRepo;
    if (repo == null) return const <String, int>{};
    final removed = await repo.deleteAllUserData(keepDefinitions: keepDefinitions);
    await refreshFocusState();
    return removed;
  }

  // ---------------------------------------------------------------- lifecycle
  /// Opens the database, writes the tracker catalogue if it is missing, and
  /// hydrates the read cache. It creates **definitions only**: no history, no
  /// streaks, no sample rows. A fresh install genuinely reads zero everywhere
  /// until the user logs something.
  Future<void> load() async {
    final report = await repo.bootstrap();
    integrityOk = report.integrityOk;
    await _reloadFromDb();
    await _loadSettings();

    // The stored health standing is a *cache of the last answer*, never evidence about
    // this launch: a permission can be revoked while the app is closed, and an OEM
    // update can remove Health Connect. Re-asked in the background so the first frame
    // is not blocked on a health read — and so a revoked permission stops being
    // described as connected.
    if (health != null) unawaited(refreshHealthPermission());

    // Momentum first, then the one-time conversion of an install's pre-Momentum
    // habit checklist. Both are idempotent; the conversion is marked in settings so
    // it can never run twice and never duplicates a commitment.
    await commitmentRepo.hydrate();
    legacyImportReport = await commitmentRepo.importLegacyHabits();
    _refreshMomentum();

    // Focus Lock: hydrate, then let recovery decide what happened to a session that
    // was live when the app last stopped. `recoverFocus` is idempotent, so this is
    // safe on every launch, and it is what stops an interrupted session from
    // reappearing as if it had been counting down the whole time.
    final focus = focusRepo;
    if (focus != null) {
      await focus.hydrate();
      await recoverFocus();
      await syncFocusSchedules();
    }

    // Everything the app can be told "no" about, read once before the first frame.
    // `recoverFocus()` above already re-read the two Focus Lock grants; these are the
    // three that used to stay as their last remembered value until something else
    // happened to ask: notification permission, Health Connect and Usage Access.
    await refreshReminders();
    unawaited(refreshScreenTimePermission());

    notifyListeners();
    unawaited(_refreshAggregates());

    // Billing is wired by `reconcileEntitlement()` from `main()`, after
    // `billing.init(cached:)`. It is the slowest dependency and nothing on the
    // first frame depends on it: the cached entitlement has already painted the
    // correct tier (and, being fail-closed, cannot grant Pro on its own).
    bindBilling();
  }

  void _onBillingChanged() {
    // Surface billing errors in Settings without turning them into global state.
    notifyListeners();
  }

  /// The subscription on [BillingService.updates], kept so it can be cancelled.
  /// `dart:async` is imported for exactly this plus `unawaited`.
  StreamSubscription<Entitlement>? _billingUpdates;

  /// True once the billing layer has been wired. Guarding this makes
  /// [bindBilling] idempotent, which it was not: `load()` and
  /// `reconcileEntitlement()` both call it, so every purchase event ran
  /// `applyEntitlement` **twice** — two settings writes, two widget snapshots, two
  /// aggregate refreshes — and `_onBillingChanged` was registered twice on the same
  /// [ChangeNotifier], which calls each listener once per registration.
  bool _billingBound = false;

  bool _disposed = false;

  Future<void> _recordPurchaseIfAny(Entitlement ent) async {
    if (ent.purchaseToken == null) return;
    await repo.dao.recordPurchase(
      productId: ent.productId ?? '',
      purchaseToken: ent.purchaseToken!,
      status: ent.inTrial ? 'trial' : 'active',
      purchasedAt: DateTime.now(),
      expiresAt: ent.expiresAt,
      autoRenew: ent.autoRenew,
      acknowledged: true,
      serverVerified: ent.verified,
      trial: ent.inTrial,
    );
  }

  /// Wires the billing layer into app state: listen for entitlement changes and
  /// push them into the UI + persistence.
  void bindBilling() {
    final b = billing;
    if (b == null || _billingBound) return;
    _billingBound = true;
    b.addListener(_onBillingChanged);
    _billingUpdates = b.updates.listen((ent) async {
      if (_disposed) return;
      await applyEntitlement(ent);
      await _recordPurchaseIfAny(ent);
    });
  }

  /// Called once at start-up, after `billing.init(cached:)`: re-verifies the
  /// stored purchase with the backend and retries anything left pending.
  Future<void> reconcileEntitlement() async {
    bindBilling();
    final b = billing;
    if (b == null) return;
    await b.retryPendingVerification();
    await b.reconcile();
    await applyEntitlement(b.entitlement);
  }

  /// Called on resume: an entitlement that expired while the app was backgrounded
  /// must not survive, and the server may have seen a refund or a cancellation.
  Future<void> onResumed() async {
    unawaited(refreshReminders());
    // Focus Lock first: a permission can be granted or revoked in system settings,
    // and the enforcement service may have been stopped by the OS. Recovering here
    // is what keeps the countdown and the honesty banner truthful after a return.
    if (focusRepo != null) await recoverFocus();

    // Health Connect revocation is a first-class resume event: the Settings row
    // and the tracker tiles must stop saying "connected" the moment the grant is
    // gone, and a re-grant should quietly resume filling the series. (This was
    // the standing gap in docs/PRODUCTION_READINESS.md §11 item 6.) The refresh
    // notifies listeners, so every consumer re-reads `healthConnected` — there
    // is nothing else to do on revocation, and nothing to retry behind the
    // user's back.
    await refreshHealthPermission();

    // Usage Access for the Screen time tracker: same rule, same moment. A grant
    // made in system settings starts auto-filling without a trip back to a
    // settings screen inside the app; a revocation stops it.
    final wasScreenConnected = screenTimeConnected;
    final screenNow = await refreshScreenTimePermission();
    if (screenNow == ScreenTimePermissionState.granted) {
      await syncScreenTime();
    } else if (wasScreenConnected && screenTimeApps.isNotEmpty) {
      // The split shown is the last one the platform reported; clear it rather
      // than keep presenting today's apps under a revoked grant.
      screenTimeApps = <ScreenTimeAppUsage>[];
      notifyListeners();
    }

    final b = billing;
    if (b == null) return;
    b.reevaluate();
    await b.retryPendingVerification();
    await b.reconcile();
    await applyEntitlement(b.entitlement);
  }

  /// True while a purchase is waiting on the backend: the UI shows an honest
  /// "confirming with Google Play" state instead of a spinner that never ends.
  bool get purchaseAwaitingVerification => billing?.hasPendingVerification ?? false;

  /// Re-checks a purchase on demand (Settings → "Check purchase again").
  Future<void> recheckPurchase() async {
    await billing?.recheck();
    await applyEntitlement(billing?.entitlement ?? Entitlement.free);
  }

  Future<void> _reloadFromDb() async {
    final rows = await repo.dao.allTrackers();
    trackers
      ..clear()
      ..addAll(rows.map(_toModel));

    history
      ..clear()
      ..addAll(repo.cache);

    added
      ..clear()
      ..addAll(_decodeList(await repo.dao.getSetting('added')) ?? const <String>[]);

    final habitJson = await repo.dao.getSetting('habits');
    habits.clear();
    if (habitJson != null) {
      try {
        final decoded = (jsonDecode(habitJson) as List).cast<Map<String, dynamic>>();
        habits.addAll([
          for (final h in decoded) Habit(h['name'] as String, h['emoji'] as String, Color(h['color'] as int)),
        ]);
      } catch (_) {
        habits.clear(); // a corrupt config must not brick the tracker
      }
    }
    if (habits.isEmpty) {
      // Starter list: names only. Streaks and ticks are derived from the user's
      // own daily rows, so a fresh install shows a genuine zero.
      habits.addAll(DefaultTrackers.starterHabits());
      await repo.dao.setSetting('habits', jsonEncode([for (final h in habits) h.toJson()]));
    }
    _projectHabitHistory();
  }

  /// Fills each habit's `done` and `streak` from the stored per-day checklist.
  ///
  /// A habit streak counts consecutive days **ending today or yesterday** where
  /// that habit was ticked. Yesterday counts so the streak does not appear broken
  /// all morning before the user has logged — but it is still real history, not a
  /// seeded number.
  void _projectHabitHistory() {
    final completions = repo.habitCompletions;
    final todayKey = dayKey(DateTime.now());
    for (var i = 0; i < habits.length; i++) {
      final h = habits[i];
      h.done = (completions[todayKey] ?? const <int>[]).contains(i);

      var streak = 0;
      // Allow the run to start yesterday, which is how a streak should feel.
      var offset = h.done ? 0 : 1;
      for (var back = offset; back < 400; back++) {
        final key = dayKeyFromToday(back);
        final doneThatDay = (completions[key] ?? const <int>[]).contains(i);
        if (doneThatDay) {
          streak++;
        } else {
          break;
        }
      }
      h.streak = streak;
    }
  }

  Future<void> _loadSettings() async {
    isDark = (await repo.dao.getSetting('dark')) == '1';
    onboarded = (await repo.dao.getSetting('onboarded')) == '1';

    // Cached entitlement: instant correct tier on a cold start, then the billing
    // layer reconciles with Google Play a moment later.
    final raw = await repo.dao.getSetting('pro.entitlement');
    if (raw != null) {
      try {
        entitlement = Entitlement.fromJson((jsonDecode(raw) as Map).cast<String, Object?>());
      } catch (_) {
        entitlement = Entitlement.free;
      }
    }
    final prompted = await repo.dao.getSetting('pro.softPromptShown');
    softPromptLastShown = prompted == null ? null : DateTime.tryParse(prompted);

    // Health Connect's *last known* standing, from the database rather than memory.
    // Re-asked in the background on launch (`refreshHealthPermission`), because a
    // permission revoked in system settings is exactly the case where a remembered
    // "connected" would be a lie on screen.
    lastSync = DateTime.tryParse(await repo.dao.getSetting('health.lastSync') ?? '');
    healthSyncedDays = int.tryParse(await repo.dao.getSetting('health.syncedDays') ?? '') ?? 0;
    healthPermission = HealthPermissionState.values.firstWhere(
      (v) => v.name == (await repo.dao.getSetting('health.permission') ?? ''),
      orElse: () => HealthPermissionState.unknown,
    );

    // Same contract as Health Connect's standing: the stored answer is a hint
    // for the first frame only, and `refreshScreenTimePermission()` replaces it
    // with the OS's answer on the first resume.
    screenTimeLastSync = DateTime.tryParse(await repo.dao.getSetting('screenTime.lastSync') ?? '');
    screenTimePermission = ScreenTimePermissionState.values.firstWhere(
      (v) => v.name == (await repo.dao.getSetting('screenTime.permission') ?? ''),
      orElse: () => ScreenTimePermissionState.unknown,
    );

    final height = double.tryParse(await repo.dao.getSetting('profile.heightCm') ?? '');
    heightCm = (height != null && height >= 50 && height <= 300) ? height : null;

    notifyDaily = (await repo.dao.getSetting('notify.daily')) != '0';
    notifyStreakSaver = (await repo.dao.getSetting('notify.streakSaver')) != '0';
    notifyWeekly = (await repo.dao.getSetting('notify.weekly')) != '0';
    lockScreenDetails = (await repo.dao.getSetting('notify.lockScreenDetails')) == '1';
    notifications?.hideDetails = !lockScreenDetails;
  }

  Future<void> setNotifyDaily(bool on) async {
    notifyDaily = on;
    notifyListeners();
    await repo.dao.setSetting('notify.daily', on ? '1' : '0');
    await _syncNotifications();
  }

  Future<void> setNotifyStreakSaver(bool on) async {
    notifyStreakSaver = on;
    notifyListeners();
    await repo.dao.setSetting('notify.streakSaver', on ? '1' : '0');
    await _syncNotifications();
  }

  Future<void> setNotifyWeekly(bool on) async {
    notifyWeekly = on;
    notifyListeners();
    await repo.dao.setSetting('notify.weekly', on ? '1' : '0');
    await _syncNotifications();
  }

  /// Opt-in, and it says what it costs: with detail on, a reminder can name a
  /// tracker on a locked screen.
  Future<void> setLockScreenDetails(bool on) async {
    lockScreenDetails = on;
    final n = notifications;
    if (n != null) n.hideDetails = !on;
    notifyListeners();
    await repo.dao.setSetting('notify.lockScreenDetails', on ? '1' : '0');
    await _syncNotifications();
  }

  /// Height is user-entered and optional; BMI stays blank without it.
  /// Stores the user's height, returning false when the value was refused.
  ///
  /// A rejection stores nothing: silently keeping the previous height while the
  /// UI shows the new one is how a "206 cm" typo becomes a permanent BMI.
  Future<bool> setHeightCm(double? cm) async {
    if (cm == null) {
      heightCm = null;
      notifyListeners();
      await repo.dao.setSetting('profile.heightCm', '');
      unawaited(_refreshAggregates());
      return true;
    }
    if (cm < 50 || cm > 300) return false;
    heightCm = cm;
    notifyListeners();
    await repo.dao.setSetting('profile.heightCm', heightCm.toString());
    unawaited(_refreshAggregates());
    return true;
  }

  /// Pulls the values that are genuinely cheaper as SQL, and keeps them fresh
  /// after writes. Never blocks the first frame.
  /// Recomputes patterns, correlations, cycle stats, rhythms and the SQL-derived
  /// counts from the stored rows. Exposed because "Recalculate insights" in
  /// Settings must actually recalculate something.
  Future<void> refreshInsights() async {
    await _refreshAggregates();
    notifyListeners();
  }

  Future<void> _refreshAggregates() async {
    try {
      entryCount = await repo.entryCount();
      trackedDays = await repo.trackedDays();
      categories = await repo.categoryTotals(days: 7);
      transactions = await repo.recentTransactions();
      foodEntries = await repo.recentFoodEntries();
      // Provenance and emptiness are part of the same refresh: the Diagnostics
      // panel and every empty state read them, so they must never lag behind a
      // write (a stale "0 entries" next to a filled chart is its own bug).
      demoRowCount = await repo.demoRowCount();
      sourceCounts = await repo.sourceCounts();
      hasAnyData = entryCount > 0;
      trackingSince = await repo.firstLoggedDate();
      _refreshMomentum();
      notifyListeners();
      unawaited(_writeWidgetSnapshot());
    } catch (_) {
      // Aggregates are cosmetic; never let them break a frame.
    }
  }

  Tracker _toModel(TrackerRow r) => Tracker(
    id: r.id,
    name: r.name,
    emoji: r.emoji,
    accent: Color(r.accent),
    accent2: Color(r.accent2),
    kind: MetricKind.values.firstWhere((k) => k.name == r.kind, orElse: () => MetricKind.habits),
    goal: r.goal,
    step: r.step,
    unit: r.unit,
    blurb: r.blurb,
    insight: r.insight,
    hero: r.hero,
    hidden: r.hidden,
    order: r.sort,
  );

  // ---------------------------------------------------------------- momentum
  /// Recomputed from the in-memory projection, so it is cheap enough to run after
  /// every write. No clock is read inside the engine: `today` is passed in, which is
  /// what makes the DST and midnight tests possible.
  void _refreshMomentum() {
    momentum = commitmentRepo.snapshots();
    overallMomentum = commitmentRepo.overall();
    weeklyReview = commitmentRepo.review();
  }

  /// Live commitments, newest last.
  List<Commitment> get commitments => commitmentRepo.active;

  bool get hasCommitments => commitments.isNotEmpty;

  /// Archived commitments. Kept visible in Routines — archiving is a pause in
  /// attention, not a deletion, and the record is still the user's.
  List<Commitment> get archivedCommitments => commitmentRepo.commitments.where((c) => c.archived).toList();

  MomentumSnapshot? momentumFor(String id) => momentum[id];

  /// Today's queue for the Today screen: the commitments that are planned today,
  /// with whatever has been recorded so far. Anything already logged sits at the
  /// bottom, so the top of the screen is always "what is left".
  List<TodayCommitment> get todayCommitments {
    final key = commitmentRepo.todayKey;
    final out = <TodayCommitment>[];
    for (final c in commitments) {
      final planned = MomentumEngine.isPlanned(c, key, commitmentRepo.pauses);
      final rec = commitmentRepo.daysFor(c.id)[key];
      if (!planned && rec == null) continue;
      out.add(
        TodayCommitment(
          commitment: c,
          scheduled: planned,
          outcome: rec?.outcome,
          paused: commitmentRepo.isPaused(c.id),
          snapshot: momentum[c.id],
        ),
      );
    }
    out.sort((a, b) {
      final aDone = a.outcome != null ? 1 : 0;
      final bDone = b.outcome != null ? 1 : 0;
      if (aDone != bDone) return aDone.compareTo(bDone);
      return a.commitment.sort.compareTo(b.commitment.sort);
    });
    return out;
  }

  bool commitmentDayLogged(String id) => commitmentRepo.daysFor(id)[commitmentRepo.todayKey] != null;

  /// Records what actually happened today (or on [day], for a correction).
  /// Returns false when the write did not land, so a caller cannot confirm a day
  /// that SQLite never received. The failure is also put on [writeFailure], which the
  /// shell shows wherever the user happens to be.
  Future<bool> logCommitmentDay(String id, DayOutcome outcome, {double? value, String? note, int? day}) async {
    try {
      await commitmentRepo.record(commitmentId: id, outcome: outcome, day: day, value: value, note: note);
    } catch (_) {
      writeFailure = SaveFailure(
        action: 'Routine day',
        detail: 'Your previous answer is unchanged. Check free space and try again.',
        at: DateTime.now(),
      );
      notifyListeners();
      return false;
    }
    _refreshMomentum();
    notifyListeners();
    await _writeWidgetSnapshot();
    return true;
  }

  Future<bool> clearCommitmentDay(String id, {int? day}) async {
    try {
      await commitmentRepo.clearRecord(id, day: day);
    } catch (_) {
      writeFailure = SaveFailure(
        action: 'Routine day',
        detail: 'That day is still recorded. Check free space and try again.',
        at: DateTime.now(),
      );
      notifyListeners();
      return false;
    }
    _refreshMomentum();
    notifyListeners();
    return true;
  }

  Future<Commitment> addCommitmentFromTemplate(CommitmentTemplate template) async {
    final c = await commitmentRepo.create(
      name: template.name,
      emoji: template.emoji,
      color: template.color.toARGB32(),
      outcome: template.outcome,
      minimumAction: template.minimumAction,
      fullAction: template.fullAction,
      weekdays: template.weekdays,
    );
    _refreshMomentum();
    notifyListeners();
    await _writeWidgetSnapshot();
    return c;
  }

  Future<Commitment> addCommitment({
    required String name,
    required String emoji,
    required Color color,
    required String outcome,
    required String minimumAction,
    required String fullAction,
    required Set<int> weekdays,
  }) async {
    final c = await commitmentRepo.create(
      name: name,
      emoji: emoji,
      color: color.toARGB32(),
      outcome: outcome,
      minimumAction: minimumAction,
      fullAction: fullAction,
      weekdays: weekdays,
    );
    _refreshMomentum();
    notifyListeners();
    await _writeWidgetSnapshot();
    return c;
  }

  Future<void> updateCommitment(Commitment updated, {Set<int>? weekdays}) async {
    await commitmentRepo.update(updated, newWeekdays: weekdays);
    _refreshMomentum();
    notifyListeners();
  }

  Future<void> archiveCommitment(String id, {bool archived = true}) async {
    await commitmentRepo.archive(id, archived: archived);
    _refreshMomentum();
    notifyListeners();
    await _writeWidgetSnapshot();
  }

  /// Deletes the commitment *and* its day records, behind a confirmation dialog in
  /// the UI. This is the one place where habit history is destroyed on purpose, and
  /// the dialog says so.
  Future<void> deleteCommitment(String id) async {
    await commitmentRepo.delete(id);
    _refreshMomentum();
    notifyListeners();
  }

  Future<void> pauseCommitment(String id, {String? reason}) async {
    await commitmentRepo.startPause(id, reason: reason);
    _refreshMomentum();
    notifyListeners();
  }

  Future<void> resumeCommitment(String id) async {
    await commitmentRepo.endPause(id);
    _refreshMomentum();
    notifyListeners();
  }

  bool isCommitmentPaused(String id) => commitmentRepo.isPaused(id);

  List<WeekdayPattern> patternsFor(String id) => commitmentRepo.patternsFor(id);

  Improvement? improvementFor(String id) => commitmentRepo.improvementFor(id);

  /// Longest full-completion streak across live commitments. Zero when there is
  /// nothing running — which is the honest answer, not a headline.
  int get bestCommitmentStreak {
    var best = 0;
    for (final s in momentum.values) {
      if (s.keepGoingStreak > best) best = s.keepGoingStreak;
    }
    return best;
  }

  /// Commitments that have slipped enough to warrant a restart plan right now.
  List<Commitment> get needsRestart => [
    for (final c in commitments)
      if (momentum[c.id]?.restart != null) c,
  ];

  bool canAddCommitment() => isPro || commitments.length < ProConfig.freeCommitmentLimit;

  // ------------------------------------------------------- freemium policy
  /// Single decision point for "is this Pro?". Every lock in the UI reads these,
  /// so the packaging in `ProConfig` can never disagree with the app.
  bool get isPro => entitlement.active;

  bool get atTrackerLimit => !canAddTracker();

  bool canAddTracker() => ProConfig.canAddTracker(isPro: isPro, active: visibleTrackers.length);

  /// Days of history the current tier can see (charts, heatmaps, history lists).
  int get historyWindow => ProConfig.historyWindowDays(isPro: isPro, available: repo.windowDays);

  /// True when day `daysAgo` is past the free window — used to draw the lock
  /// marker on charts instead of silently truncating them.
  bool isHistoryLocked(int daysAgo) => ProConfig.isHistoryLocked(isPro: isPro, daysAgo: daysAgo);

  bool get canUseHealthSync => isPro;

  bool get canUseAdvancedInsights => isPro;

  bool get canUseProNotifications => isPro;

  int get widgetRingCount => ProConfig.widgetRings(isPro: isPro);

  /// Copy for the tier, used by Settings and the paywall.
  String get planStatusLine => entitlement.statusLine;

  void markSoftPromptShown() {
    softPromptLastShown = DateTime.now();
    unawaited(repo.dao.setSetting('pro.softPromptShown', softPromptLastShown!.toIso8601String()));
  }

  /// Applies a fresh entitlement from the billing layer: update the UI now,
  /// persist for the next cold start, and refresh the widget (its ring count and
  /// its "locked" hint both depend on the tier).
  Future<void> applyEntitlement(Entitlement ent) async {
    entitlement = ent;
    // Gates re-evaluate with the new tier: a window that is no longer covered
    // collapses to free immediately, mid-session, without waiting for a restart.
    if (!isPro && _range != 'week') _range = 'week';
    Haptics.commit();
    notifyListeners();
    await repo.dao.setSetting('pro.entitlement', jsonEncode(ent.toJson()));
    await _writeWidgetSnapshot();
    await _syncNotifications();
    // Pro unlocks deeper analysis: recompute now so the newly-unlocked insights
    // are there the moment the paywall closes.
    unawaited(_refreshAggregates());
  }

  /// Notification set = tier **and** user preference.
  ///
  /// The daily check-in is free for everyone (it is the habit loop, not the
  /// upsell); the streak saver and the weekly report are Pro and additionally
  /// switchable. Whatever the combination, exactly one schedule per reminder id
  /// exists afterwards — `schedule*` cancels before it schedules.
  Future<void> _syncNotifications() async {
    final n = notifications;
    if (n == null) return;
    n.hideDetails = !lockScreenDetails;

    // A focus session holds Track Pro's own reminders: a 9pm check-in landing in the
    // middle of a 45-minute session is precisely the interruption the feature exists
    // to remove. The holds are lifted when the session ends.
    if (focusHoldsReminders) {
      await n.cancelCheckIn();
      await n.cancelStreakSaver();
      notificationsAllowed = await n.areEnabled();
      return;
    }

    if (notifyDaily) {
      await n.scheduleDailyCheckIn(this);
    } else {
      await n.cancelCheckIn();
    }

    if (isPro && notifyStreakSaver) {
      await n.syncStreakSaver(this);
    } else {
      await n.cancelStreakSaver();
    }

    if (isPro && notifyWeekly) {
      await n.scheduleWeeklyReport();
    } else {
      await n.cancelWeekly();
    }

    notificationsAllowed = await n.areEnabled();
    notifyListeners();
  }

  /// Public entry point for the post-launch wiring: schedules exactly the set the
  /// user asked for, at the tier they are entitled to.
  ///
  /// That set includes the scheduled focus sessions. They are armed through
  /// [syncFocusSchedules], and they were not armed *here* — so anything that called
  /// `syncReminders` before the notification service was ready (which, until
  /// `main()` was reordered, was every cold start) re-armed the three general
  /// reminders and quietly skipped every session reminder the user had configured.
  Future<void> syncReminders() async {
    await _syncNotifications();
    await syncFocusSchedules();
  }

  /// Called on foreground: a permission can be revoked in system settings and a
  /// time zone can change while the app is in the background, and both silently
  /// break scheduling unless the app notices.
  Future<void> refreshReminders() async {
    final n = notifications;
    if (n == null) return;
    if (await n.ensureTimezone()) {
      // The device moved zones: every scheduled wall-clock time is now wrong.
      await _syncNotifications();
      return;
    }
    notificationsAllowed = await n.areEnabled();
    notifyListeners();
  }

  // ------------------------------------------------------------------ mutators
  void setTab(int i) {
    if (i == tabIndex) return;
    tabIndex = i;
    Haptics.selection();
    notifyListeners();
  }

  /// The insights window. Clamped on **read**, so an entitlement that lapses — or
  /// a value persisted while Pro — cannot leave a free user looking at 90 days of
  /// history. The user's own choice is kept and returns if they re-subscribe.
  String get range => isPro ? _range : 'week';

  void setRange(String r) {
    _range = r;
    notifyListeners();
  }

  Future<void> setTheme(bool dark) async {
    isDark = dark;
    notifyListeners();
    await repo.dao.setSetting('dark', dark ? '1' : '0');
  }

  void toggleTheme() => unawaited(setTheme(!isDark));

  Future<void> completeOnboarding() async {
    onboarded = true;
    notifyListeners();
    await repo.dao.setSetting('onboarded', '1');
    unawaited(_writeWidgetSnapshot());
  }

  void toggleEditing() {
    editing = !editing;
    notifyListeners();
  }

  /// Absolute daily value: validated, cached for the UI, persisted for the record.
  ///
  /// Returns false when the value was rejected (non-finite, negative, or a typo
  /// beyond the plausible range). Nothing is written and nothing is shown as
  /// saved — the caller surfaces that instead of silently dropping it.
  bool log(String id, double value, {String? meta}) {
    // Order matters: refuse an id the catalogue does not know *before* creating a
    // series for it. `log('not-a-tracker', 1)` used to paint a phantom row into the
    // projection and then throw inside `byId`, so the caller got neither a value nor
    // an error — just a chart with a tracker that cannot exist.
    final tracker = trackerOrNull(id);
    if (tracker == null) {
      Haptics.warning();
      return false;
    }
    final safe = ValueValidation.sanitize(id, value);
    if (safe == null) {
      Haptics.warning();
      return false;
    }
    final series = _writableSeries(id);
    series[series.length - 1] = safe;
    Haptics.commit();
    notifyListeners();
    unawaited(_persist(() => repo.setDaily(id, safe, meta: meta), label: tracker.name));
    return true;
  }

  /// Moves today's total by [delta] — which may be **negative**.
  ///
  /// Three separate defects used to live in these lines:
  ///
  ///  1. The delta was validated with [ValueValidation.sanitize], whose contract is
  ///     "a value that can be stored", and which therefore refuses every negative. The
  ///     hero card's swipe-left is "one serving back" (`tracker_card.dart` passes
  ///     `-step`), so the removal gesture did nothing but warn — an affordance the UI
  ///     offered and the state layer silently rejected. What must be refused is a
  ///     *result* below zero, not a negative delta.
  ///  2. The event row recorded the requested delta while the rollup recorded the
  ///     clamped total, so a write clamped by the tracker's ceiling left a feed entry
  ///     describing a change the day's number does not contain.
  ///  3. An unknown tracker id threw out of `byId` after the cache had been painted.
  ///
  /// Returns false when nothing was applied, so a caller never confirms a change that
  /// did not happen.
  bool logAdd(String id, double delta, {String? meta}) {
    final tracker = trackerOrNull(id);
    if (tracker == null || !delta.isFinite) {
      Haptics.warning();
      return false;
    }
    final series = _writableSeries(id);
    final previous = series.last;
    final safeTotal = ValueValidation.sanitize(id, previous + delta);
    if (safeTotal == null) {
      // Refused: NaN, or a removal that would take the day below zero.
      Haptics.warning();
      return false;
    }
    final applied = safeTotal - previous;
    if (applied == 0) {
      // The day is already where the request would put it (already empty, or already
      // at the tracker's ceiling). Reporting that as a success would confirm a write
      // that does not exist, so it is reported as what it is: nothing happened.
      Haptics.warning();
      return false;
    }
    series[series.length - 1] = safeTotal;
    Haptics.commit();
    notifyListeners();
    unawaited(_persist(() => repo.addEvent(id, applied, safeTotal, meta: meta), label: tracker.name));
    return true;
  }

  // ------------------------------------------------------- one day, read and edited
  /// The days this tracker has a real record for, newest first.
  ///
  /// Built from stored rows, never from a gap-filled series: a day the user did not
  /// log is absent, which is a different statement from a logged zero. The history
  /// list, the streaks and the weekly average all have to agree about that.
  Future<List<RecordedDay>> recordedDays(String id, {int limit = 30}) async {
    final rows = await repo.recordedDays(id, limit: limit);
    _lastRecordedDays = rows;
    return rows;
  }

  /// The most recent [recordedDays] result, so the edit sheet can open on a day that
  /// is currently on screen without another round trip.
  List<RecordedDay> _lastRecordedDays = const <RecordedDay>[];
  List<RecordedDay> get lastRecordedDays => _lastRecordedDays;

  /// Writes a value onto a specific day. Returns false when the value was rejected
  /// *or* the write failed — in both cases nothing is shown as saved.
  ///
  /// This is what makes a mistake correctable: until now every write path in the app
  /// wrote *today*, so a value typed on Sunday for Saturday could not be entered at
  /// all, and a mis-tap could not be undone.
  Future<bool> setDayValue(String id, int day, double value) async {
    final t = byId(id);
    final bool accepted;
    try {
      accepted = await repo.setDayValue(id, day, value);
    } catch (error) {
      return _recordFailedWrite('${t.name} entry', error);
    }
    if (!accepted) {
      // Validation refused it (non-finite, negative, a typo past the plausible range).
      Haptics.warning();
      return false;
    }
    Haptics.commit();
    await refreshInsights();
    unawaited(_writeWidgetSnapshot());
    return true;
  }

  /// Deletes one day's record. The day becomes *empty*, not zero.
  ///
  /// `null` means the delete **failed** and nothing was removed; `0` means there was
  /// nothing stored for that day; a positive number is the row count removed. The
  /// distinction matters because the sheet's copy differs in all three cases, and a
  /// "Day cleared" toast over an unchanged day is exactly the kind of lie this pass
  /// exists to remove.
  Future<int?> clearDay(String id, int day) async {
    final t = byId(id);
    final int removed;
    try {
      removed = await repo.clearDay(id, day);
    } catch (error) {
      await _recordFailedWrite('${t.name} entry', error);
      return null;
    }
    if (removed == 0) {
      Haptics.warning();
      return 0;
    }
    Haptics.warning();
    await refreshInsights();
    unawaited(_writeWidgetSnapshot());
    return removed;
  }

  /// Records a failed write that did not go through [_persist], rolls the projection
  /// back to the store, and returns false. The day-level edit and delete go through
  /// the repository directly because the caller needs the row count back, so they
  /// need this path too — otherwise they would be the one place a failure went
  /// unreported.
  Future<bool> _recordFailedWrite(String label, Object error) async {
    writeFailure = SaveFailure(action: label, detail: _describeWriteError(error), at: DateTime.now());
    await _rollbackProjection();
    return false;
  }

  /// Cycle logging writes the day **and** what was actually recorded.
  ///
  /// Flow and symptoms are stored in the day's `meta_json`, which is what the export
  /// reads: the chips the user taps become data rather than decoration. The cycle-day
  /// value itself is unchanged — Track Pro has no "cycle started" concept to advance it,
  /// and inventing one would be inventing a claim about the user's body.
  bool logPeriod({required int flow, required List<String> symptoms}) {
    final meta = jsonEncode({'flow': flow, 'symptoms': symptoms});
    return log('period', today('period'), meta: meta);
  }

  /// Habits are a checklist that rolls up into the `habits` metric.
  ///
  /// The checked indices are stored on the day's own row, so history is
  /// per-habit and per-day: ticking boxes on Tuesday changes Tuesday, and every
  /// streak on screen is computed from those stored days.
  void toggleHabit(int index) {
    habits[index].done = !habits[index].done;
    final doneIndices = [
      for (var i = 0; i < habits.length; i++)
        if (habits[i].done) i,
    ];
    final series = _writableSeries('habits');
    series[series.length - 1] = doneIndices.length.toDouble();
    Haptics.selection();
    notifyListeners();
    unawaited(
      _persist(() async {
        await repo.setDaily('habits', doneIndices.length.toDouble(), meta: encodeHabitMeta(doneIndices));
        await repo.dao.setSetting('habits', jsonEncode([for (final h in habits) h.toJson()]));
        _projectHabitHistory();
        notifyListeners();
      }, label: 'Habit'),
    );
  }

  /// Adds a habit to the checklist (Pro-tier users get unlimited habits).
  void addHabit(String name, String emoji, Color color) {
    if (name.trim().isEmpty) return;
    habits.add(Habit(name.trim(), emoji, color));
    Haptics.commit();
    notifyListeners();
    unawaited(
      _persist(() => repo.dao.setSetting('habits', jsonEncode([for (final h in habits) h.toJson()])), label: 'Habits'),
    );
  }

  void removeHabit(int index) {
    if (index < 0 || index >= habits.length) return;
    habits.removeAt(index);
    Haptics.warning();
    notifyListeners();
    unawaited(
      _persist(() async {
        await repo.dao.setSetting('habits', jsonEncode([for (final h in habits) h.toJson()]));
        // Today's stored indices shift when a habit is removed.
        final done = [
          for (var i = 0; i < habits.length; i++)
            if (habits[i].done) i,
        ];
        await repo.setDaily('habits', done.length.toDouble(), meta: encodeHabitMeta(done));
      }, label: 'Habits'),
    );
  }

  /// Adds one expense to today's running total.
  ///
  /// Returns false when the amount was refused — and this is the only mutator in the
  /// app that used to skip validation entirely. `log` and `logAdd` both run every
  /// value through [ValueValidation]; this path wrote the raw number into the cache
  /// and into SQLite, so a `NaN`, a negative (which the rollup then *subtracted*)
  /// or a 10-digit typo landed in the database and re-scaled every average, ring and
  /// "vs week avg" label built from it. The sheet also reported success from its own
  /// `amount > 0` check instead of from this return value, so a clamped write was
  /// still confirmed as logged.
  bool addExpense(double amount, String category) {
    final tracker = trackerOrNull('expenses');
    if (tracker == null) {
      Haptics.warning();
      return false;
    }
    final safeAmount = ValueValidation.sanitize('expenses', amount);
    if (safeAmount == null || safeAmount <= 0) {
      Haptics.warning();
      return false;
    }
    final series = _writableSeries('expenses');
    final safeTotal = ValueValidation.sanitize('expenses', series.last + safeAmount);
    if (safeTotal == null) {
      Haptics.warning();
      return false;
    }
    // Normalise against the palette the category chart colours from, so an
    // unexpected spelling cannot create an unlabelled slice in `categories`.
    final clean = category.trim();
    final bucket = EntryRepository.categoryPalette.containsKey(clean) ? clean : 'Other';
    final title = '$bucket expense';
    series[series.length - 1] = safeTotal;
    transactions.insert(0, Transaction(title, bucket, safeAmount, 'Just now'));
    Haptics.commit();
    notifyListeners();
    unawaited(
      _persist(() async {
        await repo.addEvent('expenses', safeAmount, safeTotal, meta: jsonEncode({'category': bucket, 'title': title}));
        categories = await repo.categoryTotals(days: 7);
      }, label: tracker.name),
    ); // `tracker` is already promoted by the early return above
    //
    // (It used to read `tracker!`, which the analyzer rejects under this repo's lint set as an
    // unnecessary null assertion on a non-nullable local.)
    return true;
  }

  /// Returns whether the goal reached the database. The sheet that sets it waits for
  /// this: "Goal set to 10 km" over an unchanged goal was a confirmation for a write
  /// that had not landed.
  Future<bool> setGoal(String id, double goal) async {
    final t = byId(id);
    t.goal = goal;
    Haptics.commit();
    notifyListeners();
    return _persist(() => repo.persistGoal(id, goal), label: '${t.name} goal');
  }

  void toggleHidden(String id) {
    final t = byId(id);
    t.hidden = !t.hidden;
    Haptics.selection();
    notifyListeners();
    unawaited(_persist(() => repo.persistHidden(id, t.hidden), label: '${t.name} visibility'));
  }

  /// Pin to the front — the long-press quick action.
  ///
  /// Deliberately does **not** un-hide the tracker. These two facts are independent:
  /// a tracker the user hid is one they asked not to see on Today, and moving it must
  /// not quietly overrule that. Pinning a hidden tracker reorders it and says so; the
  /// visibility switch stays where the user left it.
  void pinToTop(String id) {
    final sorted = trackers.toList()..sort((a, b) => a.order.compareTo(b.order));
    sorted.removeWhere((x) => x.id == id);
    sorted.insert(0, byId(id));
    _applyOrder(sorted);
    Haptics.commit();
    notifyListeners();
    unawaited(_persist(() => repo.persistOrder(sorted), label: 'Order'));
  }

  void move(String id, int direction) {
    final sorted = trackers.toList()..sort((a, b) => a.order.compareTo(b.order));
    final i = sorted.indexWhere((t) => t.id == id);
    final j = i + direction;
    if (i < 0 || j < 0 || j >= sorted.length) return;
    final tmp = sorted[i];
    sorted[i] = sorted[j];
    sorted[j] = tmp;
    _applyOrder(sorted);
    // No `hidden = false` here either: moving a row is not a statement about whether
    // the user wants to see it. See pinToTop for the full reasoning.
    Haptics.selection();
    notifyListeners();
    unawaited(_persist(() => repo.persistOrder(sorted), label: 'Order'));
  }

  void _applyOrder(List<Tracker> sorted) {
    for (var k = 0; k < sorted.length; k++) {
      sorted[k].order = k;
    }
  }

  void toggleAdded(String id) {
    added.contains(id) ? added.remove(id) : added.add(id);
    Haptics.selection();
    notifyListeners();
    unawaited(_persist(() => repo.dao.setSetting('added', jsonEncode(added)), label: 'Added list'));
  }

  /// Health Connect pull: steps, sleep, weight. Never overwrites manual entries.
  ///
  /// [askPermission] is false on launch and on pull-to-refresh: the permission
  /// sheet only appears when the user explicitly asks for it from Settings.
  /// Nothing is more hostile than a system dialog on first frame.
  /// Re-asks the OS where Health Connect stands and stores the answer.
  ///
  /// Called on launch: the previous session's answer is not evidence about this one.
  /// Safe to call when Health Connect is absent or the user is free tier — it reports
  /// the platform's answer either way and grants nothing.
  Future<HealthPermissionState> refreshHealthPermission() async {
    final svc = health;
    if (svc == null) {
      healthPermission = HealthPermissionState.unavailable;
    } else {
      healthPermission = await svc.permissionState();
    }
    await repo.dao.setSetting('health.permission', healthPermission.name);
    notifyListeners();
    return healthPermission;
  }

  /// Re-asks Android where Usage access stands. Called on every foreground: the
  /// user can grant or revoke it in system settings at any moment, and a
  /// remembered answer would be a lie on screen either way.
  Future<ScreenTimePermissionState> refreshScreenTimePermission() async {
    final svc = screenTime;
    if (svc == null) {
      screenTimePermission = ScreenTimePermissionState.unavailable;
    } else {
      screenTimePermission = await svc.permissionState();
    }
    await repo.dao.setSetting('screenTime.permission', screenTimePermission.name);
    notifyListeners();
    return screenTimePermission;
  }

  /// Usage Access pull: the Screen time tracker's auto-fill.
  ///
  /// Free in every tier, deliberately. It reads the user's own device, it costs
  /// nothing to serve, and the friction is already a scary system grant —
  /// putting a paywall on top of "Usage access" would price the honest path.
  /// What it writes are ordinary tracker rows with `source: 'usage'`, so a
  /// value the user typed for that day always wins (the same precedence Health
  /// Connect rows obey), and "delete all data" removes them like any other row.
  ///
  /// Returns the number of days written, `0` when there was nothing to write,
  /// and `-1` when the grant is missing — so a caller can tell "no data" from
  /// "no permission" without reading state back.
  Future<int> syncScreenTime() async {
    final svc = screenTime;
    if (svc == null) {
      screenTimePermission = ScreenTimePermissionState.unavailable;
      return 0;
    }
    if (screenTimeSyncing) return 0; // one pull at a time
    screenTimeSyncing = true;
    try {
      final standing = await svc.permissionState();
      screenTimePermission = standing;
      if (standing != ScreenTimePermissionState.granted) {
        await repo.dao.setSetting('screenTime.permission', standing.name);
        notifyListeners();
        return -1;
      }
      final minutes = await svc.dailyMinutes(days: ScreenTimeService.defaultLookbackDays);
      final written = await repo.mergeHealthSeries('screen', minutes, source: 'usage');
      screenTimeApps = await svc.todayByApp(limit: 6);
      screenTimeLastSync = DateTime.now();
      await repo.dao.setSetting('screenTime.permission', standing.name);
      await repo.dao.setSetting('screenTime.lastSync', screenTimeLastSync!.toIso8601String());
      await _reloadFromDb();
      await _refreshAggregates();
      notifyListeners();
      unawaited(_writeWidgetSnapshot());
      return written;
    } finally {
      screenTimeSyncing = false;
    }
  }

  Future<int> syncHealth({bool askPermission = false}) async {
    final svc = health;
    if (svc == null) {
      healthPermission = HealthPermissionState.unavailable;
      return 0;
    }
    if (!canUseHealthSync) return -2; // Pro feature; the caller opens the paywall

    // Always ask the platform for the current standing. In particular, do not use
    // `isAuthorized` as a reason to call requestAuthorization: a new service instance
    // starts with an empty local cache even when Android has already granted access.
    // Automatic launch/resume/pull-to-refresh sync must read only after a confirmed
    // grant; the platform permission sheet belongs exclusively to an explicit action.
    var standing = await svc.permissionState();
    healthPermission = standing;
    if (standing != HealthPermissionState.granted) {
      if (standing == HealthPermissionState.unavailable || !askPermission) {
        await repo.dao.setSetting('health.permission', standing.name);
        notifyListeners();
        return 0;
      }

      // This branch is reached only by Settings after its contextual explanation.
      // A failed request is checked again so an unavailable provider is never presented
      // as a user denial.
      final requested = await svc.requestPermissions();
      standing = await svc.permissionState();
      healthPermission = standing;
      if (!requested || standing != HealthPermissionState.granted) {
        await repo.dao.setSetting('health.permission', standing.name);
        notifyListeners();
        return standing == HealthPermissionState.unavailable ? 0 : -1;
      }
    }

    var written = 0;
    final steps = await svc.dailySteps(days: 30);
    written += await repo.mergeHealthSeries('steps', steps);
    final sleep = await svc.dailySleep(days: 30);
    written += await repo.mergeHealthSeries('sleep', sleep);
    final weight = await svc.dailyWeight(days: 30);
    written += await repo.mergeHealthSeries('weight', weight);
    healthSyncedDays = written;
    lastSync = DateTime.now();
    // Persisted, not just remembered: the Settings row said "connected" after a
    // restart for the same reason a revoked permission would have — nothing wrote it
    // down and nothing re-asked. Both now happen.
    await repo.dao.setSetting('health.lastSync', lastSync!.toIso8601String());
    await repo.dao.setSetting('health.syncedDays', healthSyncedDays.toString());
    await repo.dao.setSetting('health.permission', healthPermission.name);
    await _reloadFromDb();
    await _refreshAggregates();
    notifyListeners();
    unawaited(_writeWidgetSnapshot());
    return written;
  }

  /// Deletes everything the user produced and restores a clean, empty app.
  ///
  /// Deliberately does **not** re-seed anything: a reset must leave the user with
  /// their own (now empty) trackers, never with synthetic history. If sample rows
  /// are present they go too — that is the entire point of the action.
  ///
  /// Returns per-table counts of what was actually removed, so the screen that
  /// offers this can report the truth instead of a generic "done". What survives is
  /// the shipped catalogue and the user's own settings: tracker definitions and
  /// goals, theme, haptics, notification choices, and OS permissions (which only
  /// Android can revoke).
  Future<Map<String, int>> reset() async {
    final removed = <String, int>{};
    removed.addAll(await repo.deleteAllUserData());
    // Routines are the user's content, not shipped configuration: a wipe that left
    // them, their day records and their pauses behind would understate what the
    // dialog promised.
    removed.addAll(await commitmentRepo.deleteAllUserData());
    // Focus sessions are the user's own history too: "delete my data" that left a
    // year of focus sessions behind would be a lie in the one place it matters most.
    // The saved rule sets go as well — a profile is a name for something the user
    // was doing, and it is theirs to leave behind.
    final focusRemoved = await focusRepo?.deleteAllUserData(keepDefinitions: false);
    if (focusRemoved != null) removed.addAll(focusRemoved);
    await refreshFocusState(notify: false);
    await _reloadFromDb();
    editing = false;
    _range = 'week';
    added.clear();
    await repo.dao.setSetting('added', jsonEncode(added));
    await _refreshAggregates();
    _refreshMomentum();
    Haptics.warning();
    notifyListeners();
    return removed;
  }

  /// Removes only rows that came from a seeder, keeping every real entry.
  Future<int> removeSampleData() async {
    final n = await repo.deleteDemoRows();
    await _reloadFromDb();
    await _refreshAggregates();
    notifyListeners();
    return n;
  }

  /// What the Settings diagnostics screen shows: whether this build is
  /// configured the way a store build must be.
  List<String> get configurationProblems => AppEnvironment.validate();

  /// Export is **deliberately never gated**. It is the clearest signal that the
  /// lock-in comes from accumulated value, not hostage data — and it is the
  /// first thing a one-star review would otherwise attack.
  /// The export the user downloads. Measurements and Momentum routines are
  /// assembled here, so no single repository has to know about the other — and so
  /// "take your data with you" genuinely means all of it.
  Future<String> exportJson() => repo.exportJson(
    sections: {
      'commitments': commitmentRepo.exportPayload(),
      if (focusRepo != null) 'focus': focusRepo!.exportPayload(),
    },
  );

  /// Focus sessions as CSV, one row each.
  String exportFocusCsv() => focusRepo?.exportCsv() ?? 'date,mode,goal';

  Future<String> exportCsv() => repo.exportCsv();

  /// Routine days, one per line: date, routine, outcome, value, note.
  String exportCommitmentsCsv() => commitmentRepo.exportCsv();

  // ------------------------------------------------------------------- plumbing
  /// Write path: persist, then refresh the cheap SQL aggregates and push a new
  /// snapshot to the home-screen widget + reschedule the streak saver.
  ///
  /// **On failure the cache is rebuilt from the store instead of being left alone.**
  /// The optimistic update has already painted by the time this runs, which is what
  /// keeps logging instant; but if the write did not land, the projection is now
  /// describing something that does not exist, and every screen reading it agrees
  /// with the wrong number. So a failure triggers a rollback: re-read the store and
  /// refresh aggregates, so what the user sees is what the database holds. The
  /// failure itself is recorded on [writeFailure] and surfaced by `HomeShell`.
  ///
  /// [label] names the action for the message ("Water", "Routine done"), because
  /// "Something went wrong" tells the user nothing they can act on.
  Future<bool> _persist(Future<void> Function() write, {String? label}) async {
    var failed = false;
    try {
      await write();
    } catch (error) {
      failed = true;
      writeFailure = SaveFailure(
        action: label ?? 'That change',
        detail: _describeWriteError(error),
        at: DateTime.now(),
      );
    }

    if (failed) {
      await _rollbackProjection();
      return false;
    }

    unawaited(_refreshAggregates());
    unawaited(_writeWidgetSnapshot());
    // Streak saver is Pro-only: for free users the daily check-in already runs.
    if (isPro) unawaited(notifications?.syncStreakSaver(this) ?? Future<void>.value());
    return true;
  }

  /// Re-derives everything on screen from the store, after a write failed.
  ///
  /// Rollback, in the order that keeps the screen coherent: the rows are re-read first,
  /// then every derived number is recomputed from them. Best-effort on purpose — a
  /// database that cannot be written often cannot be read either, and a rollback that
  /// throws on top of the original failure would replace a reported failure with a
  /// crash. The banner is raised either way: the one outcome that must never happen is
  /// a silent failure.
  Future<void> _rollbackProjection() async {
    try {
      await _reloadFromDb();
      await _refreshAggregates();
      unawaited(_writeWidgetSnapshot());
    } catch (_) {
      // Deliberately swallowed and reported: see the doc comment.
    }
    notifyListeners();
  }

  /// A database error, in words a person can act on. The raw exception is kept: a
  /// developer reading Diagnostics needs it, and a user reading a banner does not.
  static String _describeWriteError(Object error) {
    final text = error.toString();
    if (text.contains('readonly') || text.contains('read-only')) {
      return 'The database is open read-only — storage may be full or the file may be locked.';
    }
    if (text.contains('disk') || text.contains('SQLITE_FULL') || text.contains('No space')) {
      return 'There is no space left to write to.';
    }
    if (text.contains('locked') || text.contains('busy')) {
      return 'Another part of the app was writing at the same time. Your previous value is unchanged — try again.';
    }
    return 'The change could not be saved. Your previous value is unchanged.';
  }

  Future<void> _writeWidgetSnapshot() => widgetBridge?.writeSnapshot(this) ?? Future<void>.value();

  /// Detaches this object from the layers that outlive it.
  ///
  /// `AppState` is created in `main()` and handed to `ChangeNotifierProvider.value`,
  /// which does not dispose its value — so in the app this is a formality that keeps
  /// the ownership story honest, and in tests it is the difference between a clean
  /// run and a "A ChangeNotifier was used after being disposed" failure from a
  /// purchase event that landed after `tearDown`.
  @override
  void dispose() {
    _disposed = true;
    _billingBound = false;
    final sub = _billingUpdates;
    _billingUpdates = null;
    if (sub != null) unawaited(sub.cancel());
    billing?.removeListener(_onBillingChanged);
    super.dispose();
  }

  List<String>? _decodeList(String? raw) {
    if (raw == null) return null;
    try {
      return (jsonDecode(raw) as List).cast<String>();
    } catch (_) {
      return null;
    }
  }
}
