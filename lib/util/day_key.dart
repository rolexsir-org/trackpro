import 'package:flutter/material.dart';

/// Day-key helpers, in one place.
///
/// A "day key" is the local calendar day as `yyyymmdd` — an int, so it sorts and
/// ranges cheaply in SQLite. Every date in this app is a *local* calendar day,
/// which is what makes a 23:59 entry belong to the day the user was living in,
/// and what makes a DST change a non-event: keys are built from the date
/// components, never from millisecond arithmetic.
library;

int dayKey(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

/// Midnight local time on the day a key refers to.
DateTime dateOfDayKey(int day) => DateTime(day ~/ 10000, (day ~/ 100) % 100, day % 100);

/// The calendar day before [day]. Add/subtract days through [dateOfDayKey] so a
/// DST shift cannot skip or repeat a day.
int previousDayKey(int day) => dayKey(dateOfDayKey(day).subtract(const Duration(days: 1)));

int nextDayKey(int day) => dayKey(dateOfDayKey(day).add(const Duration(days: 1)));

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
int daysBetweenKeys(int from, int to) => dateOfDayKey(to).difference(dateOfDayKey(from)).inDays;

/// The Monday that starts the week containing [day] — the anchor for weekly
/// reviews. Weeks in this app run Monday to Sunday regardless of locale, so the
/// review is stable across devices.
int weekStartKey(int day) {
  final d = dateOfDayKey(day);
  return dayKey(DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1)));
}

/// Human name for a weekday index, 1 = Monday.
String weekdayName(int weekday, {bool short = false}) {
  const long = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  const brief = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final i = (weekday - 1).clamp(0, 6);
  return short ? brief[i] : long[i];
}

/// A colour from an ARGB int stored in the database.
Color colorFromArgb(int argb) => Color(argb);
