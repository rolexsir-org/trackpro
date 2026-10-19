import 'package:flutter/material.dart';

/// Day-key helpers, in one place.
///
/// A "day key" is the local calendar day as `yyyymmdd` — an int, so it sorts and
/// ranges cheaply in SQLite. Every date in this app is a *local* calendar day,
/// which is what makes a 23:59 entry belong to the day the user was living in,
/// and what makes a DST change a non-event: keys are built from the date
/// components, never from millisecond arithmetic.
///
/// The last clause is a rule, not a style preference, and it is why every
/// day-stepping helper below adds to the **day component** rather than
/// subtracting a `Duration`:
///
///   * `DateTime.now().subtract(Duration(days: 1))` is 24 hours of *elapsed*
///     time. On a 23- or 25-hour day that lands inside the day it started from,
///     or one day further back, so "yesterday" stops being yesterday;
///   * `DateTime(y, m, d - 1)` is calendar arithmetic. Dart normalises
///     out-of-range components, so it is exactly one row back in the month
///     whatever the clock did.
///
/// Getting this wrong is not cosmetic: the day keys written by `upsertDaily`
/// and the window read back by `series()` would disagree, which moves a value
/// into the wrong slot of every chart, streak and average for the hours around
/// a transition.
library;

int dayKey(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

/// Midnight local time on the day a key refers to.
DateTime dateOfDayKey(int day) => DateTime(day ~/ 10000, (day ~/ 100) % 100, day % 100);

/// Today's key, from the local clock.
int todayKey() => dayKey(DateTime.now());

/// Shifts a day key by [days] calendar days (negative goes back in time).
///
/// Component arithmetic — see the library comment for why `Duration` is the wrong
/// tool for this.
int shiftDayKey(int day, int days) {
  final d = dateOfDayKey(day);
  return dayKey(DateTime(d.year, d.month, d.day + days));
}

/// The key for the day [days] before today. `dayBefore(0)` is today.
int dayKeyFromToday(int days) => shiftDayKey(todayKey(), -days);

/// The calendar day before [day].
int previousDayKey(int day) => shiftDayKey(day, -1);

/// The calendar day after [day].
int nextDayKey(int day) => shiftDayKey(day, 1);

/// `2026-03-07`. ISO for exports and logs.
String isoDayKey(int day) =>
    '${day ~/ 10000}-${((day ~/ 100) % 100).toString().padLeft(2, '0')}-${(day % 100).toString().padLeft(2, '0')}';

/// `7 Mar`. For anything a person reads.
String shortDayKey(int day) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final d = dateOfDayKey(day);
  return '${d.day} ${months[d.month - 1]}';
}

/// ISO weekday of a key: 1 = Monday … 7 = Sunday.
int weekdayOfDayKey(int day) => DateTime(day ~/ 10000, (day ~/ 100) % 100, day % 100).weekday;

/// Whole days from [from] to [to] (negative when `to` is earlier).
///
/// Rounded from hours rather than truncated from a `Duration`: on the day a clock
/// jumps forward, midnight-to-midnight is 23 hours, and `inDays` on 23 hours is
/// **0** — which reads as "same day" to every streak, window and "days since"
/// label in the app. A 25-hour day would read as 1 instead of 2 going the other
/// way. Rounding is exact for any 23-to-25-hour span.
int daysBetweenKeys(int from, int to) =>
    (dateOfDayKey(to).difference(dateOfDayKey(from)).inHours / 24).round();

/// The Monday that starts the week containing [day] — the anchor for weekly
/// reviews. Weeks in this app run Monday to Sunday regardless of locale, so the
/// review is stable across devices.
int weekStartKey(int day) {
  final d = dateOfDayKey(day);
  return dayKey(DateTime(d.year, d.month, d.day - (d.weekday - 1)));
}

/// Human name for a weekday index, 1 = Monday.
String weekdayName(int weekday, {bool short = false}) {
  const long = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  const brief = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final i = (weekday - 1).clamp(0, 6).toInt();
  return short ? brief[i] : long[i];
}

/// A colour from an ARGB int stored in the database.
Color colorFromArgb(int argb) => Color(argb);
