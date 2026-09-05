import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../domain/prayer_engine/prayer.dart';
import '../../../domain/qada/qada_payment.dart';
import '../app_database.dart';
import '../codecs.dart';

/// Persists qada payments and opening balances (SRS FR-QD-02, FR-QD-03).
/// Balances themselves are derived, never stored — see [QadaBalance].
class QadaRepository {
  final AppDatabase _db;
  static const Uuid _uuid = Uuid();

  QadaRepository(this._db);

  Future<void> recordPayment({
    required Prayer prayer,
    required int count,
    required DateTime date,
    String? note,
    DateTime? now,
  }) {
    return _db.into(_db.qadaPaymentTable).insert(
          QadaPaymentTableCompanion.insert(
            id: _uuid.v4(),
            prayer: Codecs.prayerToDb(prayer),
            count: count,
            date: Codecs.dateKey(date),
            loggedAt: (now ?? DateTime.now()).toIso8601String(),
            note: Value(note),
          ),
        );
  }

  Future<void> deletePayment(String id) {
    return (_db.delete(_db.qadaPaymentTable)..where((t) => t.id.equals(id)))
        .go();
  }

  Future<List<QadaPayment>> getAllPayments() async {
    final rows = await _db.select(_db.qadaPaymentTable).get();
    return rows
        .map((row) => QadaPayment(
              id: row.id,
              prayer: Codecs.prayerFromDb(row.prayer),
              count: row.count,
              date: Codecs.parseDateKey(row.date),
              loggedAt: DateTime.parse(row.loggedAt),
              note: row.note,
            ))
        .toList();
  }

  Future<void> setOpeningBalance(Prayer prayer, int count) {
    return _db.into(_db.qadaOpeningBalanceTable).insertOnConflictUpdate(
          QadaOpeningBalanceTableCompanion.insert(
            prayer: Codecs.prayerToDb(prayer),
            count: Value(count),
          ),
        );
  }

  Future<Map<Prayer, int>> getOpeningBalances() async {
    final rows = await _db.select(_db.qadaOpeningBalanceTable).get();
    return {
      for (final row in rows) Codecs.prayerFromDb(row.prayer): row.count,
    };
  }
}
