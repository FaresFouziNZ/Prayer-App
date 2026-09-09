import '../prayer_engine/prayer.dart';
import '../tracker/prayer_log_entry.dart';
import '../tracker/prayer_status.dart';
import 'qada_payment.dart';

/// Derives qada balances. Balances are never stored (SRS FR-QD-02) — only
/// missed records, payments, and opening balances are, and this function
/// recomputes the balance from them every time.
class QadaBalance {
  const QadaBalance._();

  /// Balance per prayer (SRS FR-QD-01): opening balance + missed count -
  /// payments made for that prayer. [excludedDays] (period days, product
  /// decision 2026-09-07) drops any log falling on one of those dates —
  /// a woman isn't obligated to pray then, so a `missed` record from before
  /// the day was marked shouldn't inflate the qada backlog either.
  static Map<Prayer, int> compute({
    required List<PrayerLogEntry> logs,
    required List<QadaPayment> payments,
    required Map<Prayer, int> openingBalances,
    Set<DateTime> excludedDays = const {},
  }) {
    final balances = <Prayer, int>{
      for (final prayer in Prayer.values) prayer: openingBalances[prayer] ?? 0,
    };

    for (final log in logs) {
      final day = DateTime(log.date.year, log.date.month, log.date.day);
      if (excludedDays.contains(day)) continue;
      if (log.status == PrayerStatus.missed) {
        balances[log.prayer] = (balances[log.prayer] ?? 0) + 1;
      }
    }

    for (final payment in payments) {
      balances[payment.prayer] =
          (balances[payment.prayer] ?? 0) - payment.count;
    }

    return balances;
  }
}
