import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/models.dart';
import '../state/app_state.dart';
import '../util/format.dart';

/// Notifications are the retention loop, not decoration:
///
/// | notification      | when            | why it works |
/// |-------------------|-----------------|--------------|
/// | Daily check-in    | 21:00 daily     | one sheet, every tracker — reinforces "this is my dashboard for everything" |
/// | Streak saver      | 21:45, only if  | loss aversion: fires *only* when a real streak is about to break |
/// | Weekly report     | Sun 19:00       | the "look how much I've accumulated" moment that makes the app feel irreplaceable |
///
/// Android specifics that matter:
/// - `POST_NOTIFICATIONS` runtime permission on 13+.
/// - We schedule with `AndroidScheduleMode.inexactAllowWhileIdle` by default:
///   a 9pm nudge does not need alarm-clock precision, and inexact scheduling
///   avoids the `SCHEDULE_EXACT_ALARM` / Play-policy conversation entirely.
///   `setExactScheduling(true)` opts into exact alarms if you declare them.
/// - Everything is re-scheduled on boot via `RECEIVE_BOOT_COMPLETED` (the plugin
///   persists pending notifications, the receiver lives in the manifest overlay).
/// - **Lock screen:** bodies are generic by default. "3 still open: period, mood,
///   sleep" is health information, and a notification is readable by anyone
///   holding the phone. The user can opt into detail in Settings, and the choice
///   is stored — an opt-in that does not survive a restart is not an opt-in.
class NotificationService {
  NotificationService({this.exactScheduling = false});

  bool exactScheduling;

  /// When true (the default) notification bodies never name a tracker that could
  /// be sensitive; the detail lives inside the app, behind the app's own locks.
  bool hideDetails = true;

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  /// Payloads the app reacts to (routing: 'today', 'quickadd', 'insights').
  final StreamController<String> _taps = StreamController<String>.broadcast();
  Stream<String> get onTap => _taps.stream;

  static const _checkInId = 1001;
  static const _streakSaverId = 1002;
  static const _weeklyId = 1003;

  /// Scheduled focus sessions use a *base* id per schedule, and the service adds the
  /// weekday (1–7) to it, because `dayOfWeekAndTime` matching covers exactly one
  /// weekday per scheduled notification. An every-day schedule uses the base id with
  /// time matching. `cancelFocusSchedule` therefore cancels the whole base..base+7
  /// range, which is the only way to be certain nothing is left behind — a stale
  /// focus reminder firing at the wrong time is worse than no reminder.
  static const int focusScheduleIdBase = 3900;

  static const _checkInChannel = AndroidNotificationChannel(
    'track.checkin',
    'Daily check-in',
    description: 'One sheet for everything you track, once a day.',
    importance: Importance.defaultImportance,
  );

  static const _streakChannel = AndroidNotificationChannel(
    'track.streak',
    'Streak saver',
    description: 'Only fires when a streak is genuinely about to break.',
    importance: Importance.high,
  );

  static const _weeklyChannel = AndroidNotificationChannel(
    'track.weekly',
    'Weekly report',
    description: 'Sunday recap: trends, averages and what changed.',
    importance: Importance.low,
  );

  /// A *scheduled* focus session — a reminder at the time the user chose. Its own
  /// channel, so a user who finds these intrusive can turn them off without losing
  /// the daily check-in, and so the app can explain them on their own terms.
  static const _focusScheduleChannel = AndroidNotificationChannel(
    'track.focus.scheduled',
    'Scheduled focus',
    description: 'Reminds you when a focus session you scheduled is due to start.',
    importance: Importance.defaultImportance,
  );

  String? _zone;

  /// Re-reads the device time zone and reports whether it moved.
  ///
  /// `zonedSchedule` resolves a wall-clock time in the zone that was current when
  /// it was scheduled. Fly from IST to GMT and a 21:00 reminder fires at 01:30
  /// local unless the app notices. DST inside one zone is handled by the tz
  /// database; a *zone change* is not.
  Future<bool> ensureTimezone() async {
    try {
      tzdata.initializeTimeZones();
      final zone = (await FlutterTimezone.getLocalTimezone()).identifier;
      tz.setLocalLocation(tz.getLocation(zone));
      final changed = _zone != null && _zone != zone;
      _zone = zone;
      return changed;
    } catch (_) {
      return false;
    }
  }

  Future<void> init() async {
    try {
      await ensureTimezone();

      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      await _plugin.initialize(
        const InitializationSettings(android: android),
        onDidReceiveNotificationResponse: (response) {
          if (response.payload != null) _taps.add(response.payload!);
        },
        onDidReceiveBackgroundNotificationResponse: _backgroundTap,
      );

      final androidImpl = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidImpl?.createNotificationChannel(_checkInChannel);
      await androidImpl?.createNotificationChannel(_streakChannel);
      await androidImpl?.createNotificationChannel(_weeklyChannel);
      await androidImpl?.createNotificationChannel(_focusScheduleChannel);
      _ready = true;
    } catch (e) {
      debugPrint('NotificationService.init failed: $e');
      _ready = false;
    }
  }

  /// Called from onboarding's notification step or Settings, never silently.
  Future<bool> requestPermission() async {
    if (!_ready) return false;
    try {
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final granted = await androidImpl?.requestNotificationsPermission() ?? false;
      if (exactScheduling) await androidImpl?.requestExactAlarmsPermission();
      return granted;
    } catch (_) {
      return false;
    }
  }

  /// The 9pm "one sheet" check-in. Body is built from the user's own state, so
  /// it reads like the app knows them: "3 of 10 trackers still open today" —
  /// unless the user has left detail off the lock screen, in which case it says
  /// how many are left and nothing about which.
  Future<void> scheduleDailyCheckIn(AppState state, {int hour = 21, int minute = 0}) async {
    if (!_ready) return;
    final open = _openTrackerNames(state);
    final body = hideDetails
        ? (open.isEmpty
            ? 'Everything is logged for today. See you tomorrow.'
            : '${open.length} ${open.length == 1 ? 'tracker is' : 'trackers are'} still open today.')
        : (open.isEmpty
            ? 'Everything is logged. Nice — see you tomorrow.'
            : '${open.length} still open today: ${open.take(3).join(', ')}${open.length > 3 ? '…' : ''}');

    // Cancel first: a stale instance from a previous schedule must never survive
    // as a second reminder.
    await _plugin.cancel(_checkInId);
    await _scheduleDaily(
      id: _checkInId,
      channel: _checkInChannel,
      title: 'Check in with Track Pro',
      body: body,
      hour: hour,
      minute: minute,
      payload: 'quickadd',
      style: const BigTextStyleInformation(''),
    );
  }

  /// Re-evaluated after every write. Only fires when a streak is actually at
  /// risk, which is what makes it feel like a coach instead of spam.
  Future<void> syncStreakSaver(AppState state) async {
    if (!_ready) return;
    await _plugin.cancel(_streakSaverId);

    final atRisk = _streakAtRisk(state);
    if (atRisk == null) return;

    final (tracker, days) = atRisk;
    await _scheduleDaily(
      id: _streakSaverId,
      channel: _streakChannel,
      title: '🔥 Your $days-day streak is at risk',
      body: hideDetails
          ? 'One tap keeps it alive. Open Track Pro to see which one.'
          : '${tracker.emoji} ${tracker.name} is still open today. One tap keeps it alive.',
      hour: 21,
      minute: 45,
      payload: 'quickadd',
    );
  }

  Future<void> scheduleWeeklyReport({int weekday = DateTime.sunday, int hour = 19}) async {
    if (!_ready) return;
    await _plugin.cancel(_weeklyId);
    await _plugin.zonedSchedule(
      _weeklyId,
      'Your week in review',
      hideDetails
          ? 'Your weekly summary is ready inside Track Pro.'
          : 'Trends, averages and what changed across every tracker.',
      _nextInstanceOf(weekday, hour, 0),
      _details(_weeklyChannel, payload: 'insights'),
      androidScheduleMode: _mode,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  /// Arms a scheduled focus session.
  ///
  /// This is a reminder, not an auto-start: the notification carries a one-tap
  /// action, and the session begins when the person taps it. Starting to cover other
  /// apps while nobody is holding the phone is the behaviour users correctly call
  /// malware, and Android restricts launching that kind of work from the background
  /// anyway. Stating it here because "scheduled deep focus" could otherwise be read
  /// as "Track Pro will block your apps at 9am whether you are there or not".
  Future<void> scheduleFocusSession({
    required int id,
    required String title,
    required int minuteOfDay,
    Set<int> weekdays = const <int>{},
  }) async {
    if (!_ready) return;
    await cancelFocusSchedule(id);

    final hour = (minuteOfDay ~/ 60) % 24;
    final minute = minuteOfDay % 60;
    final body = hideDetails
        ? 'A focus session you scheduled is due. Open Track Pro to start it.'
        : '$title is due. Tap to start it — nothing is blocked until you do.';

    if (weekdays.isEmpty) {
      // Every day, at this time.
      await _plugin.zonedSchedule(
        id,
        'Time to focus',
        body,
        _nextInstanceOf(DateTime.now().weekday, hour, minute),
        _focusDetails(payload: 'focus'),
        androidScheduleMode: _mode,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      return;
    }

    for (final weekday in weekdays) {
      if (weekday < 1 || weekday > 7) continue;
      await _plugin.zonedSchedule(
        id + weekday,
        'Time to focus',
        body,
        _nextInstanceOf(weekday, hour, minute),
        _focusDetails(payload: 'focus'),
        androidScheduleMode: _mode,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  /// Cancels a schedule completely: the every-day slot and all seven weekday slots.
  Future<void> cancelFocusSchedule(int id) async {
    if (!_ready) return;
    for (var offset = 0; offset <= 7; offset++) {
      await _plugin.cancel(id + offset);
    }
  }

  /// Drops the Pro-only reminders when a subscription lapses. The daily check-in
  /// deliberately survives: it is the habit loop, not the upsell — killing it
  /// would cost more in retention than it could ever earn in revenue.
  Future<void> cancelProOnly() async {
    if (!_ready) return;
    await _plugin.cancel(_streakSaverId);
    await _plugin.cancel(_weeklyId);
  }

  /// Cancels a single reminder. Used by the per-notification switches, so a user
  /// who turns off the streak saver keeps the daily check-in.
  Future<void> cancelCheckIn() async {
    if (!_ready) return;
    await _plugin.cancel(_checkInId);
  }

  Future<void> cancelStreakSaver() async {
    if (!_ready) return;
    await _plugin.cancel(_streakSaverId);
  }

  Future<void> cancelWeekly() async {
    if (!_ready) return;
    await _plugin.cancel(_weeklyId);
  }

  /// Whether the OS currently lets us post at all (revoked in system settings,
  /// or never granted). Settings uses this instead of assuming permission.
  Future<bool> areEnabled() async {
    if (!_ready) return false;
    try {
      final impl = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      return await impl?.areNotificationsEnabled() ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Cancel everything (used by the "pause reminders" switch in Settings).
  Future<void> cancelAll() async {
    if (!_ready) return;
    await _plugin.cancel(_checkInId);
    await _plugin.cancel(_streakSaverId);
    await _plugin.cancel(_weeklyId);
  }

  Future<List<PendingNotificationRequest>> pending() async {
    if (!_ready) return const [];
    return _plugin.pendingNotificationRequests();
  }

  /// Pays off the "smart nudges" promise: the reminder body reflects real state.
  List<String> _openTrackerNames(AppState state) {
    final open = <String>[];
    for (final t in state.visibleTrackers) {
      if (t.id == 'weight' || t.id == 'period' || t.id == 'screen') continue;
      if (ringPct(t, state.today(t.id)) >= .5) continue;
      open.add(t.name.toLowerCase());
    }
    return open;
  }

  /// (tracker, streakDays) when today's log is missing and the streak is ≥ 3.
  (Tracker, int)? _streakAtRisk(AppState state) {
    for (final t in state.visibleTrackers) {
      if (state.isLoggedToday(t.id)) continue;
      final s = state.streak(t.id);
      if (s >= 3) return (t, s);
    }
    return null;
  }

  AndroidScheduleMode get _mode =>
      exactScheduling ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle;

  Future<void> _scheduleDaily({
    required int id,
    required AndroidNotificationChannel channel,
    required String title,
    required String body,
    required int hour,
    required int minute,
    required String payload,
    StyleInformation? style,
  }) {
    final next = _nextInstanceOf(DateTime.now().weekday, hour, minute);
    return _plugin.zonedSchedule(
      id,
      title,
      body,
      next,
      _details(channel, payload: payload, style: style),
      androidScheduleMode: _mode,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  NotificationDetails _details(AndroidNotificationChannel channel, {required String payload, StyleInformation? style}) =>
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: channel.importance,
          priority: Priority.defaultPriority,
          styleInformation: style,
          category: AndroidNotificationCategory.reminder,
          // Hidden on a secure lock screen. The content is personal (streaks,
          // trackers, sleep), and a phone on a table should not become a report.
          visibility: NotificationVisibility.private,
          // Grouped under one app-level group so three reminders never stack into
          // a wall of noise.
          groupKey: 'com.track.app.reminders',
          // iOS-like presentation: no huge icon, title + body + one action.
          actions: const [AndroidNotificationAction('log', 'Log now', showsUserInterface: true)],
        ),
      );

  NotificationDetails _focusDetails({required String payload}) => NotificationDetails(
        android: AndroidNotificationDetails(
          _focusScheduleChannel.id,
          _focusScheduleChannel.name,
          channelDescription: _focusScheduleChannel.description,
          importance: _focusScheduleChannel.importance,
          priority: Priority.defaultPriority,
          category: AndroidNotificationCategory.reminder,
          // A scheduled focus session names the goal, which can be personal
          // ("revision for the exam"). Private, like every other Track Pro reminder.
          visibility: NotificationVisibility.private,
          groupKey: 'com.track.app.reminders',
          actions: const [AndroidNotificationAction('start', 'Start now', showsUserInterface: true)],
        ),
      );

  tz.TZDateTime _nextInstanceOf(int weekday, int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    while (scheduled.weekday != weekday || scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}

/// Notification tapped while the app was dead — the payload is parked here so
/// the very first frame can route straight to the right sheet instead of
/// dumping the user on the dashboard.
String? pendingNotificationPayload;

Future<void> _backgroundTap(NotificationResponse response) async {
  pendingNotificationPayload = response.payload;
}
