import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_app/domain/prayer_engine/prayer.dart';
import 'package:prayer_app/domain/stats/period_stats.dart';
import 'package:prayer_app/domain/tracker/prayer_log_entry.dart';
import 'package:prayer_app/domain/tracker/prayer_status.dart';

PrayerLogEntry _log(DateTime date, Prayer prayer, PrayerStatus status) {
  return PrayerLogEntry(
    id: '$date-${prayer.name}',
    date: date,
    prayer: prayer,
    status: status,
    loggedAt: date,
    source: LogSource.manual,
  );
}

void main() {
  test('rates exclude not-logged prayers from the denominator (FR-ST-05)', () {
    final day1 = DateTime(2026, 1, 1);
    final day2 = DateTime(2026, 1, 2);
    final logs = [
      _log(day1, Prayer.fajr, PrayerStatus.jamaah),
      _log(day1, Prayer.dhuhr, PrayerStatus.onTimeAlone),
      _log(day1, Prayer.asr, PrayerStatus.late),
      _log(day1, Prayer.maghrib, PrayerStatus.missed),
      // day1 isha not logged
      // day2: nothing logged at all
    ];

    final metrics = PeriodStats.compute(days: [day1, day2], logs: logs);

    // 10 slots total (2 days x 5 prayers), 4 logged, 6 not logged.
    expect(metrics.notLoggedCount, 6);
    expect(metrics.loggedCount, 4);
    expect(metrics.jamaahRate, 1 / 4);
    expect(metrics.onTimeRate, 2 / 4);
    expect(metrics.lateCount, 1);
    expect(metrics.missedCount, 1);
  });

  test('per-prayer breakdown isolates each prayer (FR-ST-02)', () {
    final day1 = DateTime(2026, 1, 1);
    final logs = [
      _log(day1, Prayer.fajr, PrayerStatus.missed),
      _log(day1, Prayer.dhuhr, PrayerStatus.jamaah),
    ];

    final perPrayer = PeriodStats.computePerPrayer(days: [day1], logs: logs);

    expect(perPrayer[Prayer.fajr]!.missedCount, 1);
    expect(perPrayer[Prayer.dhuhr]!.jamaahCount, 1);
    expect(perPrayer[Prayer.asr]!.notLoggedCount, 1);
  });
}
