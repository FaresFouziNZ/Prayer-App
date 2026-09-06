import 'package:adhan_dart/adhan_dart.dart' as adhan;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/prayer_config.dart';
import '../config/settings_keys.dart';
import '../data/backup/backup_service.dart';
import '../data/db/app_database.dart';
import '../data/db/codecs.dart';
import '../data/db/repositories/iqamah_profile_repository.dart';
import '../data/db/repositories/prayer_log_repository.dart';
import '../data/db/repositories/qada_repository.dart';
import '../data/db/repositories/settings_repository.dart';
import '../data/db/repositories/sunnah_repository.dart';
import '../domain/prayer_engine/hijri_date.dart';
import '../domain/prayer_engine/prayer_day.dart';
import '../domain/prayer_engine/prayer_time_calculator.dart';
import '../domain/schedule/iqamah_profile.dart';
import '../domain/schedule/prayer_event.dart';
import '../domain/schedule/schedule_builder.dart';
import '../domain/tracker/prayer_log_entry.dart';
import '../domain/tracker/sunnah.dart';
import '../platform/notifications/notification_scheduler.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(appDatabaseProvider)),
);

final iqamahProfileRepositoryProvider = Provider<IqamahProfileRepository>(
  (ref) => IqamahProfileRepository(ref.watch(appDatabaseProvider)),
);

final prayerLogRepositoryProvider = Provider<PrayerLogRepository>(
  (ref) => PrayerLogRepository(ref.watch(appDatabaseProvider)),
);

final sunnahRepositoryProvider = Provider<SunnahRepository>(
  (ref) => SunnahRepository(ref.watch(appDatabaseProvider)),
);

final qadaRepositoryProvider = Provider<QadaRepository>(
  (ref) => QadaRepository(ref.watch(appDatabaseProvider)),
);

final backupServiceProvider = Provider<BackupService>(
  (ref) => BackupService(ref.watch(appDatabaseProvider)),
);

/// A single scheduler instance for the app's lifetime, so
/// `flutter_local_notifications`' plugin channel and its notification
/// response callbacks are only registered once (SRS FR-NT).
final notificationSchedulerProvider = Provider<NotificationScheduler>(
  (ref) => FlutterLocalNotificationsScheduler(),
);

/// Today's date at midnight, local time.
final todayProvider = Provider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

/// Everything needed to render one calendar day: its computed prayer times,
/// events, active profile, and Ramadan state — reused by Home (today) and
/// History (arbitrary past days) alike.
class DaySnapshot {
  final PrayerDay prayerDay;
  final List<PrayerEvent> events;
  final IqamahProfile activeProfile;
  final bool ramadanMode;
  final HijriDate hijriDate;

  const DaySnapshot({
    required this.prayerDay,
    required this.events,
    required this.activeProfile,
    required this.ramadanMode,
    required this.hijriDate,
  });

  /// Suggest turning Ramadan mode on when the Hijri month is Ramadan but the
  /// setting doesn't reflect it yet (FR-RM-01).
  bool get suggestRamadanMode => hijriDate.isRamadan && !ramadanMode;
}

/// Jeddah — used only until FR-PT-03 location settings have a value.
const _defaultCoordinates = adhan.Coordinates(21.5433, 39.1728);

/// Reads the location settings written by FR-PT-03 (automatic GPS fix or
/// manual coordinates, see [LocationService]/Settings), falling back to
/// Jeddah so the app is usable before any location has been set.
final coordinatesProvider = FutureProvider<adhan.Coordinates>((ref) async {
  final settings = ref.watch(settingsRepositoryProvider);
  final lat = await settings.getDouble(SettingsKeys.latitude);
  final lng = await settings.getDouble(SettingsKeys.longitude);
  if (lat == null || lng == null) return _defaultCoordinates;
  return adhan.Coordinates(lat, lng);
});

final daySnapshotProvider =
    FutureProvider.family<DaySnapshot, DateTime>((ref, date) async {
  final settings = ref.watch(settingsRepositoryProvider);
  final profiles = ref.watch(iqamahProfileRepositoryProvider);
  final coordinates = await ref.watch(coordinatesProvider.future);

  final ramadanMode = await settings.getBool(SettingsKeys.ramadanMode) ?? false;
  final profileSettingKey = ramadanMode
      ? SettingsKeys.ramadanIqamahProfileId
      : SettingsKeys.normalIqamahProfileId;
  final defaultProfileId = ramadanMode
      ? IqamahProfileRepository.ramadanProfileId
      : IqamahProfileRepository.normalProfileId;
  final activeProfileId =
      await settings.getString(profileSettingKey) ?? defaultProfileId;
  final activeProfile = await profiles.getById(activeProfileId) ??
      IqamahProfile(
        id: IqamahProfileRepository.normalProfileId,
        name: 'Normal',
        offsetMinutes: PrayerConfig.normalIqamahOffsets,
        isBuiltin: true,
      );

  final closingOffsetMinutes =
      await settings.getInt(SettingsKeys.closingOffsetMinutes) ??
          PrayerConfig.defaultClosingOffsetMinutes;
  final preAdhanOffsetMinutes =
      await settings.getInt(SettingsKeys.preAdhanOffsetMinutes) ??
          PrayerConfig.defaultPreAdhanOffsetMinutes;

  final calculator = PrayerTimeCalculator(
    coordinates: coordinates,
    ramadanMode: ramadanMode,
  );
  final prayerDay = calculator.computeForDate(date);
  final events = ScheduleBuilder.build(
    prayerDay,
    activeProfile,
    ScheduleSettings(
      closingOffsetMinutes: closingOffsetMinutes,
      preAdhanOffsetMinutes: preAdhanOffsetMinutes,
    ),
  );

  return DaySnapshot(
    prayerDay: prayerDay,
    events: events,
    activeProfile: activeProfile,
    ramadanMode: ramadanMode,
    hijriDate: HijriDate.fromGregorian(date),
  );
});

/// A day's prayer log entries, updated live as logs are written (Drift
/// streams re-emit automatically — no manual invalidation needed).
final dayLogsProvider = StreamProvider.family((ref, DateTime date) {
  final repo = ref.watch(prayerLogRepositoryProvider);
  return repo.watchForDay(date);
});

/// A day's rawatib toggles (SRS FR-SN-01), live-updated like [dayLogsProvider].
final daySunnahProvider = StreamProvider.family((ref, DateTime date) {
  final repo = ref.watch(sunnahRepositoryProvider);
  return repo.watchForDay(date);
});

/// The date this install first ran, or null if never recorded (shouldn't
/// happen post-launch — main() writes it before the first frame). Lets
/// History tell "no data because the app didn't exist yet" apart from
/// "not logged".
final firstLaunchDateProvider = FutureProvider<DateTime?>((ref) async {
  final settings = ref.watch(settingsRepositoryProvider);
  final key = await settings.getString(SettingsKeys.firstLaunchDate);
  return key == null ? null : Codecs.parseDateKey(key);
});

/// Whether the user dismissed History's "days before you installed" notice.
final historyPreInstallDismissedProvider = FutureProvider<bool>((ref) async {
  final settings = ref.watch(settingsRepositoryProvider);
  return await settings.getBool(SettingsKeys.historyPreInstallDismissed) ?? false;
});

/// The last 30 days of logs, for the History screen's day list.
const int historyWindowDays = 30;

final historyLogsProvider = StreamProvider<List<PrayerLogEntry>>((ref) {
  final repo = ref.watch(prayerLogRepositoryProvider);
  final today = ref.watch(todayProvider);
  final start = today.subtract(const Duration(days: historyWindowDays - 1));
  return repo.watchBetween(start, today);
});

/// Logs for a statistics period. `periodDays == null` means "all time",
/// starting from the earliest logged date (SRS FR-ST-01).
final periodLogsProvider =
    FutureProvider.family<List<PrayerLogEntry>, int?>((ref, periodDays) async {
  final repo = ref.watch(prayerLogRepositoryProvider);
  final today = ref.watch(todayProvider);
  if (periodDays != null) {
    final start = today.subtract(Duration(days: periodDays - 1));
    return repo.getBetween(start, today);
  }
  return repo.getBetween(DateTime(1970), today);
});

/// All iqamah profiles (built-in and custom), for the profile editor and
/// the Settings pickers (SRS FR-IQ-02).
final iqamahProfilesProvider = FutureProvider<List<IqamahProfile>>((ref) {
  return ref.watch(iqamahProfileRepositoryProvider).getAll();
});

/// Sunnah entries for the same statistics period (SRS FR-ST-04).
final periodSunnahProvider =
    FutureProvider.family<List<SunnahLogEntry>, int?>((ref, periodDays) async {
  final repo = ref.watch(sunnahRepositoryProvider);
  final all = await repo.getAll();
  if (periodDays == null) return all;
  final today = ref.watch(todayProvider);
  final start = today.subtract(Duration(days: periodDays - 1));
  return all
      .where((e) =>
          !e.date.isBefore(start) && !e.date.isAfter(today))
      .toList();
});
