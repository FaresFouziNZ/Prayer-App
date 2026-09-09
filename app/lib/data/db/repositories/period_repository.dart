import '../app_database.dart';
import '../codecs.dart';

/// Persists which days are marked as a menstrual period day (product
/// decision 2026-09-07) — a row's presence means the day is marked, so
/// marking/unmarking is a plain insert/delete rather than a boolean flag.
class PeriodRepository {
  final AppDatabase _db;

  PeriodRepository(this._db);

  Future<void> setPeriodDay(DateTime date, bool marked) {
    final dateKey = Codecs.dateKey(date);
    if (marked) {
      return _db
          .into(_db.periodDayTable)
          .insertOnConflictUpdate(
            PeriodDayTableCompanion.insert(date: dateKey),
          );
    }
    return (_db.delete(
      _db.periodDayTable,
    )..where((t) => t.date.equals(dateKey))).go();
  }

  Stream<bool> watchIsPeriodDay(DateTime date) {
    return (_db.select(_db.periodDayTable)
          ..where((t) => t.date.equals(Codecs.dateKey(date))))
        .watchSingleOrNull()
        .map((row) => row != null);
  }

  /// All marked days, for excluding them from Stats/Qada calculations that
  /// span an arbitrary or unbounded period.
  Stream<Set<DateTime>> watchAll() {
    return _db
        .select(_db.periodDayTable)
        .watch()
        .map((rows) => rows.map((r) => Codecs.parseDateKey(r.date)).toSet());
  }
}
