import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:track/data/commitment_repository.dart';
import 'package:track/data/db/database.dart';
import 'package:track/data/entry_repository.dart';
import 'package:track/services/screen_time_service.dart';
import 'package:track/state/app_state.dart';
import 'package:track/util/day_key.dart';

/// Fake `ScreenTimeService` seam — no platform channel required in unit tests.
class FakeScreenTimeService extends ScreenTimeService {
  FakeScreenTimeService({
    this.available = true,
    this.standing = ScreenTimePermissionState.granted,
    this.minutesByDay = const <int, double>{},
    this.appsToday = const <ScreenTimeAppUsage>[],
    this.canOpenSettings = true,
  });

  bool available;
  ScreenTimePermissionState standing;
  Map<int, double> minutesByDay;
  List<ScreenTimeAppUsage> appsToday;
  bool canOpenSettings;
  int openCalls = 0;

  @override
  Future<bool> get isAvailable async => available;

  @override
  Future<ScreenTimePermissionState> permissionState() async =>
      available ? standing : ScreenTimePermissionState.unavailable;

  @override
  Future<bool> openUsageAccessSettings() async {
    openCalls++;
    return canOpenSettings;
  }

  @override
  Future<Map<int, double>> dailyMinutes({int days = ScreenTimeService.defaultLookbackDays}) async =>
      standing == ScreenTimePermissionState.granted ? minutesByDay : const <int, double>{};

  @override
  Future<List<ScreenTimeAppUsage>> todayByApp({int limit = 6}) async =>
      standing == ScreenTimePermissionState.granted
          ? appsToday.take(limit).toList()
          : const <ScreenTimeAppUsage>[];
}

void main() {
  final fixedNow = DateTime(2026, 10, 18, 15, 30);

  group('ScreenTimeService pure parsers — bounds, windows, and labels', () {
    test('parseDailyMinutes filters out-of-window days, sums split buckets, and clamps to 1440', () {
      final today = dayKey(fixedNow);
      final yesterday = previousDayKey(today);
      final tooOld = shiftDayKey(today, -30);
      final future = nextDayKey(today);

      final parsed = ScreenTimeService.parseDailyMinutes(
        <Object?>[
          <String, Object?>{'day': today, 'minutes': 120.0},
          <String, Object?>{'day': today, 'minutes': 45.5},
          <String, Object?>{'day': yesterday, 'minutes': 1900.0},
          <String, Object?>{'day': tooOld, 'minutes': 90.0},
          <String, Object?>{'day': future, 'minutes': 60.0},
          <String, Object?>{'day': yesterday, 'minutes': -20.0},
          <String, Object?>{'day': yesterday, 'minutes': double.nan},
          'malformed',
        ],
        now: fixedNow,
        days: 14,
      );

      expect(parsed[today], 165.5, reason: 'same-day buckets are summed');
      expect(parsed[yesterday], 1440.0, reason: 'clamped to 24 hours');
      expect(parsed.containsKey(tooOld), isFalse, reason: 'outside lookback window');
      expect(parsed.containsKey(future), isFalse, reason: 'future day dropped');
    });

    test('parseTodayByApp sorts most-used first, falls back to package name, and caps at limit', () {
      final apps = ScreenTimeService.parseTodayByApp(
        <Object?>[
          <String, Object?>{'package': 'com.b.app', 'label': 'Browser', 'minutes': 42.0},
          <String, Object?>{'package': 'com.a.app', 'label': '   ', 'minutes': 95.0},
          <String, Object?>{'package': 'com.c.app', 'label': 'Camera', 'minutes': 15.0},
          <String, Object?>{'package': 'com.zero.app', 'label': 'Zero', 'minutes': 0.0},
          <String, Object?>{'package': '', 'label': 'EmptyPkg', 'minutes': 50.0},
        ],
        limit: 2,
      );

      expect(apps.length, 2);
      expect(apps.first.packageName, 'com.a.app');
      expect(apps.first.label, 'com.a.app', reason: 'blank label falls back to packageName');
      expect(apps.first.minutes, 95.0);
      expect(apps.last.label, 'Browser');
    });
  });

  group('Usage Access sync, manual precedence, and revocation on resume', () {
    late TrackDatabase db;
    late EntryRepository repo;
    late CommitmentRepository commitments;
    late FakeScreenTimeService fakeScreen;
    late AppState state;

    setUp(() async {
      db = TrackDatabase.forTesting(NativeDatabase.memory());
      repo = EntryRepository(db);
      commitments = CommitmentRepository(db, now: () => fixedNow);
      fakeScreen = FakeScreenTimeService(
        standing: ScreenTimePermissionState.granted,
        minutesByDay: <int, double>{todayKey(): 185.0},
        appsToday: const <ScreenTimeAppUsage>[
          ScreenTimeAppUsage(packageName: 'com.social.app', label: 'Social', minutes: 110.0),
          ScreenTimeAppUsage(packageName: 'com.video.app', label: 'Video', minutes: 75.0),
        ],
      );
      state = AppState(
        repo: repo,
        commitmentRepo: commitments,
        screenTime: fakeScreen,
      );
      await state.load();
    });

    tearDown(() async => db.close());

    test('syncScreenTime writes source=usage rows and populates today per-app breakdown', () async {
      final written = await state.syncScreenTime();
      expect(written, 1);
      expect(state.screenTimeConnected, isTrue);
      expect(state.today('screen'), 185.0);
      expect(state.screenTimeApps.length, 2);
      expect(state.screenTimeLastSync, isNotNull);

      final recorded = await repo.recordedDays('screen');
      expect(recorded.length, 1);
      expect(recorded.first.source, 'usage');
    });

    test('a manual screen-time entry is never overwritten by Usage Access sync', () async {
      await repo.setDaily('screen', 120.0, source: 'manual');
      final written = await state.syncScreenTime();
      expect(written, 0, reason: 'manual wins over usage sync');
      expect((await repo.dao.series('screen', days: 1)).last, 120.0);
      expect(EntryRepository.sourceRank['manual']!, greaterThan(EntryRepository.sourceRank['usage']!));
    });

    test('revoking Usage Access in system settings is detected on resume and clears app breakdown', () async {
      await state.syncScreenTime();
      expect(state.screenTimeConnected, isTrue);
      expect(state.screenTimeApps, isNotEmpty);

      // User revokes Usage Access in Android Settings and returns to the app.
      fakeScreen.standing = ScreenTimePermissionState.denied;
      await state.onResumed();

      expect(state.screenTimeConnected, isFalse);
      expect(state.screenTimePermission, ScreenTimePermissionState.denied);
      expect(state.screenTimeApps, isEmpty, reason: 'revoked grant stops showing today app list');
      expect(await state.syncScreenTime(), -1, reason: 'sync refuses without grant');
    });
  });
}
