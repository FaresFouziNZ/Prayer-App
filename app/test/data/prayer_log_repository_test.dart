import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_app/data/db/app_database.dart';
import 'package:prayer_app/data/db/repositories/prayer_log_repository.dart';
import 'package:prayer_app/domain/prayer_engine/prayer.dart';
import 'package:prayer_app/domain/tracker/prayer_excuse.dart';
import 'package:prayer_app/domain/tracker/prayer_log_entry.dart';
import 'package:prayer_app/domain/tracker/prayer_status.dart';
import 'package:uuid/uuid.dart';

void main() {
  late AppDatabase db;
  late PrayerLogRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = PrayerLogRepository(db);
  });

  tearDown(() => db.close());

  PrayerLogEntry entry({
    required DateTime date,
    required Prayer prayer,
    required PrayerStatus status,
    PrayerExcuse? excuse,
  }) {
    return PrayerLogEntry(
      id: const Uuid().v4(),
      date: date,
      prayer: prayer,
      status: status,
      prayedAt: date,
      loggedAt: date,
      source: LogSource.manual,
      excuse: excuse,
    );
  }

  test('re-logging the same date+prayer with a fresh id updates in place '
      'instead of throwing a unique-constraint error (AC-TR-1)', () async {
    final date = DateTime(2026, 3, 1);

    await repo.upsert(entry(date: date, prayer: Prayer.fajr, status: PrayerStatus.late));
    await repo.upsert(
      entry(date: date, prayer: Prayer.fajr, status: PrayerStatus.jamaah),
    );

    final rows = await repo.getForDay(date);
    expect(rows, hasLength(1));
    expect(rows.single.status, PrayerStatus.jamaah);
  });

  test('editing an existing entry keeps its original id stable', () async {
    final date = DateTime(2026, 3, 1);
    final first = entry(date: date, prayer: Prayer.asr, status: PrayerStatus.late);
    await repo.upsert(first);

    await repo.upsert(
      entry(date: date, prayer: Prayer.asr, status: PrayerStatus.jamaah),
    );

    final stored = await repo.getForDate(date, Prayer.asr);
    expect(stored!.id, first.id);
  });

  test('excuse round-trips through upsert and read', () async {
    final date = DateTime(2026, 3, 1);
    await repo.upsert(
      entry(
        date: date,
        prayer: Prayer.isha,
        status: PrayerStatus.missed,
        excuse: PrayerExcuse.travel,
      ),
    );

    final stored = await repo.getForDate(date, Prayer.isha);
    expect(stored!.excuse, PrayerExcuse.travel);
  });
}
