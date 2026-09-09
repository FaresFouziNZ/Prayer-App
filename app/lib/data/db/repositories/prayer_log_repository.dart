import 'package:drift/drift.dart';

import '../../../domain/prayer_engine/prayer.dart';
import '../../../domain/tracker/prayer_log_entry.dart';
import '../../../domain/tracker/prayer_status.dart';
import '../app_database.dart';
import '../codecs.dart';

/// Persists [PrayerLogEntry] rows. Enforces the SRS AC-TR-1 uniqueness rule
/// (one record per date+prayer).
///
/// `insertOnConflictUpdate` only resolves conflicts on the primary key
/// (`id`), not on the table's `(date, prayer)` unique index — see
/// https://drift.simonbinder.eu/faq/#how-do-i-use-multiple-primary-keys.
/// Logging the same prayer twice always builds a fresh `id`, so the upsert
/// here targets `(date, prayer)` explicitly and leaves `id` untouched on
/// conflict, giving a record a stable identity across edits.
class PrayerLogRepository {
  final AppDatabase _db;

  PrayerLogRepository(this._db);

  Future<void> upsert(PrayerLogEntry entry) {
    final table = _db.prayerLogTable;
    return _db
        .into(table)
        .insert(
          PrayerLogTableCompanion.insert(
            id: entry.id,
            date: Codecs.dateKey(entry.date),
            prayer: Codecs.prayerToDb(entry.prayer),
            status: Codecs.statusToDb(entry.status),
            prayedAt: Value(entry.prayedAt?.toIso8601String()),
            loggedAt: entry.loggedAt.toIso8601String(),
            source: entry.source.name,
            travelling: Value(entry.travelling),
            combinedWith: Value(entry.combinedWith),
            excuse: Value(Codecs.excuseToDb(entry.excuse)),
          ),
          onConflict: DoUpdate(
            (old) => PrayerLogTableCompanion(
              status: Value(Codecs.statusToDb(entry.status)),
              prayedAt: Value(entry.prayedAt?.toIso8601String()),
              loggedAt: Value(entry.loggedAt.toIso8601String()),
              source: Value(entry.source.name),
              travelling: Value(entry.travelling),
              combinedWith: Value(entry.combinedWith),
              excuse: Value(Codecs.excuseToDb(entry.excuse)),
            ),
            target: [table.date, table.prayer],
          ),
        );
  }

  Future<void> delete(String id) {
    return (_db.delete(_db.prayerLogTable)..where((t) => t.id.equals(id))).go();
  }

  Future<PrayerLogEntry?> getForDate(DateTime date, Prayer prayer) async {
    final row =
        await (_db.select(_db.prayerLogTable)..where(
              (t) =>
                  t.date.equals(Codecs.dateKey(date)) &
                  t.prayer.equals(Codecs.prayerToDb(prayer)),
            ))
            .getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  Future<List<PrayerLogEntry>> getForDay(DateTime date) async {
    final rows = await (_db.select(
      _db.prayerLogTable,
    )..where((t) => t.date.equals(Codecs.dateKey(date)))).get();
    return rows.map(_toDomain).toList();
  }

  Future<List<PrayerLogEntry>> getBetween(DateTime start, DateTime end) async {
    final rows =
        await (_db.select(_db.prayerLogTable)..where(
              (t) =>
                  t.date.isBiggerOrEqualValue(Codecs.dateKey(start)) &
                  t.date.isSmallerOrEqualValue(Codecs.dateKey(end)),
            ))
            .get();
    return rows.map(_toDomain).toList();
  }

  Stream<List<PrayerLogEntry>> watchBetween(DateTime start, DateTime end) {
    return (_db.select(_db.prayerLogTable)..where(
          (t) =>
              t.date.isBiggerOrEqualValue(Codecs.dateKey(start)) &
              t.date.isSmallerOrEqualValue(Codecs.dateKey(end)),
        ))
        .watch()
        .map((rows) => rows.map(_toDomain).toList());
  }

  Stream<List<PrayerLogEntry>> watchForDay(DateTime date) {
    return (_db.select(_db.prayerLogTable)
          ..where((t) => t.date.equals(Codecs.dateKey(date))))
        .watch()
        .map((rows) => rows.map(_toDomain).toList());
  }

  PrayerLogEntry _toDomain(PrayerLogRow row) {
    return PrayerLogEntry(
      id: row.id,
      date: Codecs.parseDateKey(row.date),
      prayer: Codecs.prayerFromDb(row.prayer),
      status: Codecs.statusFromDb(row.status),
      prayedAt: row.prayedAt == null ? null : DateTime.parse(row.prayedAt!),
      loggedAt: DateTime.parse(row.loggedAt),
      source: LogSource.values.firstWhere((s) => s.name == row.source),
      travelling: row.travelling,
      combinedWith: row.combinedWith,
      excuse: Codecs.excuseFromDb(row.excuse),
    );
  }
}
