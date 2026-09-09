import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_app/domain/prayer_engine/prayer.dart';
import 'package:prayer_app/domain/qada/qada_balance.dart';
import 'package:prayer_app/domain/qada/qada_payment.dart';
import 'package:prayer_app/domain/tracker/prayer_log_entry.dart';
import 'package:prayer_app/domain/tracker/prayer_status.dart';

PrayerLogEntry _log(Prayer prayer, PrayerStatus status, DateTime date) {
  return PrayerLogEntry(
    id: '${prayer.name}-${date.toIso8601String()}',
    date: date,
    prayer: prayer,
    status: status,
    loggedAt: date,
    source: LogSource.manual,
  );
}

void main() {
  test('balance = opening + missed - payments (FR-QD-01)', () {
    final logs = [
      _log(Prayer.fajr, PrayerStatus.missed, DateTime(2026, 1, 1)),
      _log(Prayer.fajr, PrayerStatus.missed, DateTime(2026, 1, 2)),
      _log(Prayer.dhuhr, PrayerStatus.jamaah, DateTime(2026, 1, 1)),
    ];
    final payments = [
      QadaPayment(
        id: 'p1',
        prayer: Prayer.fajr,
        count: 1,
        date: DateTime(2026, 1, 3),
        loggedAt: DateTime(2026, 1, 3),
      ),
    ];

    final balances = QadaBalance.compute(
      logs: logs,
      payments: payments,
      openingBalances: const {Prayer.fajr: 3},
    );

    expect(balances[Prayer.fajr], 3 + 2 - 1);
    expect(balances[Prayer.dhuhr], 0);
  });

  test('late prayers never count toward qada', () {
    final logs = [
      _log(Prayer.asr, PrayerStatus.late, DateTime(2026, 1, 1)),
    ];

    final balances = QadaBalance.compute(
      logs: logs,
      payments: const [],
      openingBalances: const {},
    );

    expect(balances[Prayer.asr], 0);
  });

  test('a missed record on an excluded (period) day does not count', () {
    final logs = [
      _log(Prayer.dhuhr, PrayerStatus.missed, DateTime(2026, 1, 1)),
      _log(Prayer.dhuhr, PrayerStatus.missed, DateTime(2026, 1, 2)),
    ];

    final balances = QadaBalance.compute(
      logs: logs,
      payments: const [],
      openingBalances: const {},
      excludedDays: {DateTime(2026, 1, 1)},
    );

    expect(balances[Prayer.dhuhr], 1);
  });
}
