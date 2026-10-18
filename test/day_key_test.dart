import 'package:flutter_test/flutter_test.dart';
import 'package:track/util/day_key.dart';

/// The calendar rule every day-window in Track sits on.
///
/// Why a file for a dozen small functions: each "day" in this app is a `yyyymmdd` int, and
/// exactly one place is allowed to turn a `DateTime` into one. When that place was wrong the
/// symptoms appeared six files away — a streak that lost a day in November, history labels one
/// day off, an "N of 28 days" tile disagreeing with the chart under it — and no symptom pointed
/// back here. Two of those were live defects found in the 2026-10 audit.
///
/// The case this file exists for is daylight saving, and it must be said plainly what a unit
/// test can do about it: **the host timezone decides whether the run crosses a transition**, so
/// there is no way to force it from inside a Dart test. What these assertions do instead is
/// hold in both worlds and be strictly stronger in a DST zone. `daysBetweenKeys` is the pivot:
/// truncating `Duration.inDays` made the 23-hour day read as "0 days apart", which froze streaks
/// and shrank every window by a day for a few hours; rounding from hours is exact for any
/// 23-to-25-hour day, so the same assertion passes in Asia/Kolkata (where the bug was invisible
/// and stayed invisible) and in Europe/São Paulo (where it was not).
///
/// If you want to see the failure, run this file with a timezone whose next transition falls
/// inside the window the tests build — `TZ=Europe/London flutter test test/day_key_test.dart`
/// straddles the March and October switches through the day-stepping assertions.
///
/// Not executed in the environment that wrote them (no Flutter SDK). Run with:
///   flutter test test/day_key_test.dart
void main() {
  group('a day key is the local calendar day', () {
    test('the key is the date components, not an instant', () {
      expect(dayKey(DateTime(2026, 3, 7)), 20260307);
      expect(dayKey(DateTime(2026, 3, 7, 0, 0, 0, 0)), 20260307);
      // 23:59 belongs to the day the user was living in. This is the whole reason the
      // app keys on a calendar day instead of a UTC timestamp: a UTC day boundary at
      // 05:30 local would move a late entry into yesterday for the app's main market.
      expect(dayKey(DateTime(2026, 3, 7, 23, 59, 59, 999)), 20260307);
      expect(dayKey(DateTime(2026, 3, 8, 0, 0)), 20260308);
    });

    test('a key round-trips through its midnight', () {
      for (final k in [20260101, 20260228, 20280229, 20260307, 20261231, 20261031]) {
        expect(dayKey(dateOfDayKey(k)), k, reason: 'midnight on day $k must still be day $k');
        expect(weekdayOfDayKey(k), inInclusiveRange(1, 7),
            reason: 'weekday is 1..7 — a 0 would index past the label list in `weekdayName`');
      }
    });

    test('the formatting helpers are stable enough to be copy', () {
      expect(isoDayKey(20260307), '2026-03-07');
      expect(shortDayKey(20260307), '7 Mar');
      expect(shortDayKey(20261231), '31 Dec');
      // 2026-01-01 is a Thursday. If this ever fails, it is the *test* that is wrong:
      // a fixed date's weekday does not depend on the machine it runs on.
      expect(weekdayOfDayKey(20260101), 4, reason: 'DateTime.weekday: Monday is 1');
      expect(weekdayName(4), 'Thursday');
      expect(weekdayName(1, short: true), 'Mon');
      expect(weekdayName(7, short: true), 'Sun');
    });
  });

  group('stepping a day is calendar arithmetic', () {
    test('next and previous invert each other across every boundary that matters', () {
      for (final k in [
        20260101, // new year
        20260131, // month end, 31-day month
        20260228, // month end, February in a common year
        20280228, // month end, February in a leap year
        20280229, // the leap day itself
        20260331, // month end, 30-day month
        20261231, // year end
      ]) {
        expect(previousDayKey(nextDayKey(k)), k, reason: 'forward then back must land home on $k');
        expect(nextDayKey(previousDayKey(k)), k, reason: 'back then forward must land home on $k');
      }
    });

    test('the boundaries produce the neighbouring day, not a normalised surprise', () {
      expect(nextDayKey(20261231), 20270101);
      expect(nextDayKey(20260228), 20260301); // 2026 is not a leap year
      expect(nextDayKey(20280228), 20280229);
      expect(nextDayKey(20280229), 20280301);
      expect(previousDayKey(20260101), 20251231);
      expect(shiftDayKey(20260301, -1), 20260228);
      expect(shiftDayKey(20260115, 30), 20260214); // crosses a 31-day month
      expect(shiftDayKey(20260101, 0), 20260101, reason: 'shifting by nothing is the identity');
    });

    test('one day is one day, whatever the clock did in between', () {
      // The regression this pins: `dateOfDayKey(b).difference(dateOfDayKey(a)).inDays` on
      // the spring-forward day is 23 hours, which truncates to **0** — "yesterday" read as
      // "today", so a streak froze and a 28-day window silently covered 27.
      for (final k in [20260101, 20260307, 20260328, 20260329, 20261024, 20261025, 20261231]) {
        expect(daysBetweenKeys(k, nextDayKey(k)), 1, reason: '$k → its next day is 1 apart');
        expect(daysBetweenKeys(previousDayKey(k), k), 1, reason: 'and the day before is -1');
        expect(daysBetweenKeys(nextDayKey(k), k), -1, reason: 'the sign is the direction, not an error');
      }
    });

    test('a window of N days spans N-1 gaps and is symmetric', () {
      for (final n in [1, 2, 7, 28, 60, 365]) {
        final start = dayKeyFromToday(n - 1);
        expect(daysBetweenKeys(start, todayKey()), n - 1,
            reason: 'a $n-day window (the chart width) must cover exactly $n day keys');
        expect(daysBetweenKeys(todayKey(), start), -(n - 1));
      }
      // `series()` builds exactly `days` slots from `dayKeysEndingToday`; the invariant
      // that makes its gap-filling line up with the rollup table is this one.
      expect(daysBetweenKeys(dayKeyFromToday(6), todayKey()), 6);
    });

    test('dayKeyFromToday(0) is today at any hour', () {
      expect(dayKeyFromToday(0), todayKey());
      expect(todayKey(), dayKey(DateTime.now()));
    });
  });

  group('the week runs Monday to Sunday on every device', () {
    test('weekStartKey is the Monday of the day it was handed', () {
      // 2026-01-05 is a Monday; the whole week from it must map back to it, and the
      // Sunday after it must belong to that week — not to the next one.
      final monday = 20260105;
      var d = monday;
      for (var i = 0; i < 7; i++) {
        expect(weekStartKey(d), monday, reason: 'day ${i + 1} of the week must anchor to Monday');
        expect(weekdayOfDayKey(monday), 1);
        d = nextDayKey(d);
      }
      expect(weekStartKey(d), d, reason: 'the following Monday starts its own week');
    });

    test('the anchor never points forward, and never more than six days back', () {
      for (final k in [20260101, 20260214, 20260331, 20261225, 20280229]) {
        final start = weekStartKey(k);
        expect(daysBetweenKeys(start, k), inInclusiveRange(0, 6));
        expect(weekdayOfDayKey(start), 1, reason: 'a weekly review anchored to a non-Monday is two reviews');
      }
    });
  });
}
