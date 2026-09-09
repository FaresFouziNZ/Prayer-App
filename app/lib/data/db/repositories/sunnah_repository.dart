import 'package:drift/drift.dart';

import '../../../domain/tracker/sunnah.dart';
import '../app_database.dart';
import '../codecs.dart';

/// Persists [SunnahLogEntry] rows (SRS FR-SN-01, AC-SN-1).
class SunnahRepository {
  final AppDatabase _db;

  SunnahRepository(this._db);

  Future<void> setDone({
    required DateTime date,
    required SunnahItem item,
    required bool done,
    DateTime? now,
  }) {
    return _db
        .into(_db.sunnahLogTable)
        .insertOnConflictUpdate(
          SunnahLogTableCompanion.insert(
            date: Codecs.dateKey(date),
            item: Codecs.sunnahItemToDb(item),
            done: Value(done),
            loggedAt: (now ?? DateTime.now()).toIso8601String(),
          ),
        );
  }

  Future<List<SunnahLogEntry>> getForDay(DateTime date) async {
    final rows = await (_db.select(
      _db.sunnahLogTable,
    )..where((t) => t.date.equals(Codecs.dateKey(date)))).get();
    return rows.map(_toDomain).toList();
  }

  Future<List<SunnahLogEntry>> getAll() async {
    final rows = await _db.select(_db.sunnahLogTable).get();
    return rows.map(_toDomain).toList();
  }

  Stream<List<SunnahLogEntry>> watchForDay(DateTime date) {
    return (_db.select(_db.sunnahLogTable)
          ..where((t) => t.date.equals(Codecs.dateKey(date))))
        .watch()
        .map((rows) => rows.map(_toDomain).toList());
  }

  Stream<List<SunnahLogEntry>> watchAll() {
    return _db
        .select(_db.sunnahLogTable)
        .watch()
        .map((rows) => rows.map(_toDomain).toList());
  }

  SunnahLogEntry _toDomain(SunnahLogRow row) {
    return SunnahLogEntry(
      date: Codecs.parseDateKey(row.date),
      item: Codecs.sunnahItemFromDb(row.item),
      done: row.done,
      loggedAt: DateTime.parse(row.loggedAt),
    );
  }
}
