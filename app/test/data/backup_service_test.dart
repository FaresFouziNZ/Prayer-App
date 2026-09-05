import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_app/config/settings_keys.dart';
import 'package:prayer_app/data/backup/backup_service.dart';
import 'package:prayer_app/data/db/app_database.dart';
import 'package:prayer_app/data/db/repositories/prayer_log_repository.dart';
import 'package:prayer_app/data/db/repositories/settings_repository.dart';
import 'package:prayer_app/domain/prayer_engine/prayer.dart';
import 'package:prayer_app/domain/tracker/prayer_log_entry.dart';
import 'package:prayer_app/domain/tracker/prayer_status.dart';

PrayerLogEntry _entry({
  required DateTime date,
  required Prayer prayer,
  required PrayerStatus status,
  required DateTime loggedAt,
  String id = 'fixed-id',
}) {
  return PrayerLogEntry(
    id: id,
    date: date,
    prayer: prayer,
    status: status,
    loggedAt: loggedAt,
    source: LogSource.manual,
  );
}

void main() {
  test('export then import into a fresh database round-trips settings and logs (FR-BK-01/02)', () async {
    final source = AppDatabase(NativeDatabase.memory());
    await SettingsRepository(source).setString(SettingsKeys.languageCode, 'ar');
    await PrayerLogRepository(source).upsert(
      _entry(
        date: DateTime(2026, 3, 1),
        prayer: Prayer.fajr,
        status: PrayerStatus.jamaah,
        loggedAt: DateTime(2026, 3, 1, 5, 10),
      ),
    );

    final json = await BackupService(source).exportToJsonString();
    await source.close();

    final target = AppDatabase(NativeDatabase.memory());
    await BackupService(target).applyImport(json);

    expect(await SettingsRepository(target).getString(SettingsKeys.languageCode), 'ar');
    final logs = await PrayerLogRepository(target).getForDay(DateTime(2026, 3, 1));
    expect(logs, hasLength(1));
    expect(logs.single.status, PrayerStatus.jamaah);

    await target.close();
  });

  test('dryRunImport reports rows to add into an empty database', () async {
    final source = AppDatabase(NativeDatabase.memory());
    await PrayerLogRepository(source).upsert(
      _entry(
        date: DateTime(2026, 3, 1),
        prayer: Prayer.asr,
        status: PrayerStatus.late,
        loggedAt: DateTime(2026, 3, 1, 15, 45),
      ),
    );
    final json = await BackupService(source).exportToJsonString();
    await source.close();

    final target = AppDatabase(NativeDatabase.memory());
    final diff = await BackupService(target).dryRunImport(json);

    expect(diff.rowsToAdd, 1);
    expect(diff.rowsConflicting, 0);
    expect(diff.rowsIdentical, 0);

    await target.close();
  });

  test('dryRunImport reports identical rows once already imported', () async {
    final source = AppDatabase(NativeDatabase.memory());
    await PrayerLogRepository(source).upsert(
      _entry(
        date: DateTime(2026, 3, 1),
        prayer: Prayer.isha,
        status: PrayerStatus.jamaah,
        loggedAt: DateTime(2026, 3, 1, 19, 50),
      ),
    );
    final json = await BackupService(source).exportToJsonString();
    await source.close();

    final target = AppDatabase(NativeDatabase.memory());
    final service = BackupService(target);
    await service.applyImport(json);

    final diff = await service.dryRunImport(json);
    expect(diff.rowsToAdd, 0);
    expect(diff.rowsConflicting, 0);
    expect(diff.rowsIdentical, 1);

    await target.close();
  });

  test('dryRunImport reports a conflict when the same date+prayer differs', () async {
    final target = AppDatabase(NativeDatabase.memory());
    await PrayerLogRepository(target).upsert(
      _entry(
        id: 'existing',
        date: DateTime(2026, 3, 1),
        prayer: Prayer.maghrib,
        status: PrayerStatus.onTimeAlone,
        loggedAt: DateTime(2026, 3, 1, 18, 20),
      ),
    );

    final incoming = AppDatabase(NativeDatabase.memory());
    await PrayerLogRepository(incoming).upsert(
      _entry(
        id: 'incoming',
        date: DateTime(2026, 3, 1),
        prayer: Prayer.maghrib,
        status: PrayerStatus.jamaah,
        loggedAt: DateTime(2026, 3, 1, 18, 25),
      ),
    );
    final json = await BackupService(incoming).exportToJsonString();
    await incoming.close();

    final diff = await BackupService(target).dryRunImport(json);
    expect(diff.rowsToAdd, 0);
    expect(diff.rowsConflicting, 1);
    expect(diff.rowsIdentical, 0);

    await target.close();
  });
}
