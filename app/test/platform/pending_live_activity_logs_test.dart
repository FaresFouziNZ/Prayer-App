import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_app/app/providers.dart';
import 'package:prayer_app/data/db/app_database.dart';
import 'package:prayer_app/data/db/repositories/prayer_log_repository.dart';
import 'package:prayer_app/domain/prayer_engine/prayer.dart';
import 'package:prayer_app/domain/tracker/prayer_status.dart';
import 'package:prayer_app/platform/live_activity/pending_live_activity_logs.dart';
import 'package:prayer_app/platform/live_notification/live_notification_scheduler.dart';
import 'package:prayer_app/platform/notifications/notification_scheduler.dart';

const _channel = MethodChannel('live_activity');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        notificationSchedulerProvider.overrideWithValue(
          const UnimplementedNotificationScheduler(),
        ),
        liveNotificationSchedulerProvider.overrideWithValue(
          const UnimplementedLiveNotificationScheduler(),
        ),
      ],
    );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
    container.dispose();
    await db.close();
  });

  test(
    'drains a pending Jama\'ah log and applies it via the tracker rules (FR-LA-01)',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_channel, (call) async {
            expect(call.method, 'drainPendingLogs');
            return [
              {
                'date': '2026-03-01',
                'prayer': 'fajr',
                'status': 'log_jamaah',
                'loggedAt': '2026-03-01T05:10:00Z',
              },
            ];
          });

      await PendingLiveActivityLogs.drainAndApply(container);

      final entry = await PrayerLogRepository(
        db,
      ).getForDate(DateTime(2026, 3, 1), Prayer.fajr);
      expect(entry, isNotNull);
      expect(entry!.status, PrayerStatus.jamaah);
      expect(entry.source, LogSource.liveActivity);
    },
  );

  test('a Friday Dhuhr log is forced to Jama\'ah (FR-TR-07)', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          return [
            {
              'date': '2026-03-06', // a Friday
              'prayer': 'dhuhr',
              'status': 'log_alone',
              'loggedAt': '2026-03-06T12:30:00Z',
            },
          ];
        });

    await PendingLiveActivityLogs.drainAndApply(container);

    final entry = await PrayerLogRepository(
      db,
    ).getForDate(DateTime(2026, 3, 6), Prayer.dhuhr);
    expect(entry!.status, PrayerStatus.jamaah);
  });

  test('re-draining the same prayer edits the existing entry in place (AC-TR-1)', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          return [
            {
              'date': '2026-03-01',
              'prayer': 'asr',
              'status': 'log_alone',
              'loggedAt': '2026-03-01T15:30:00Z',
            },
          ];
        });
    await PendingLiveActivityLogs.drainAndApply(container);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          return [
            {
              'date': '2026-03-01',
              'prayer': 'asr',
              'status': 'log_jamaah',
              'loggedAt': '2026-03-01T15:35:00Z',
            },
          ];
        });
    await PendingLiveActivityLogs.drainAndApply(container);

    final repo = PrayerLogRepository(db);
    final entries = await repo.getForDay(DateTime(2026, 3, 1));
    expect(entries.where((e) => e.prayer == Prayer.asr), hasLength(1));
    final entry = await repo.getForDate(DateTime(2026, 3, 1), Prayer.asr);
    expect(entry!.status, PrayerStatus.jamaah);
  });

  test('"not yet" is a no-op', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          return [
            {
              'date': '2026-03-01',
              'prayer': 'asr',
              'status': 'not_yet',
              'loggedAt': '2026-03-01T15:30:00Z',
            },
          ];
        });

    await PendingLiveActivityLogs.drainAndApply(container);

    final entry = await PrayerLogRepository(
      db,
    ).getForDate(DateTime(2026, 3, 1), Prayer.asr);
    expect(entry, isNull);
  });

  test('an empty queue is a no-op', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async => <Object?>[]);

    await PendingLiveActivityLogs.drainAndApply(container);
    // No assertion beyond "doesn't throw" — nothing was queued.
  });

  test(
    'a missing native handler (Android, or before the iOS channel exists) is silently ignored',
    () async {
      // No mock handler installed — invokeMethod throws MissingPluginException.
      await PendingLiveActivityLogs.drainAndApply(container);
    },
  );
}
