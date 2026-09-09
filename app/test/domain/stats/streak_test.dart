import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_app/domain/prayer_engine/prayer.dart';
import 'package:prayer_app/domain/stats/streak.dart';
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

List<PrayerLogEntry> _fullDay(DateTime date, {PrayerStatus status = PrayerStatus.jamaah}) {
  return Prayer.values.map((p) => _log(date, p, status)).toList();
}

void main() {
  test('consecutive logged, non-missed prayers extend the streak (FR-ST-03)', () {
    final days = List.generate(3, (i) => DateTime(2026, 1, 1 + i));
    final logs = days.expand(_fullDay).toList();

    final result = Streak.compute(days: days, logs: logs);

    expect(result.current, 15);
    expect(result.best, 15);
  });

  test('an unlogged prayer is neutral, not a break (AC-ST-2)', () {
    final day1 = DateTime(2026, 1, 1);
    final day2 = DateTime(2026, 1, 2); // only 2 of 5 logged
    final day3 = DateTime(2026, 1, 3);
    final logs = [
      ..._fullDay(day1),
      _log(day2, Prayer.fajr, PrayerStatus.jamaah),
      _log(day2, Prayer.dhuhr, PrayerStatus.onTimeAlone),
      ..._fullDay(day3),
    ];

    final result = Streak.compute(days: [day1, day2, day3], logs: logs);

    expect(result.current, 12);
  });

  test('a missed prayer breaks the streak, unrelated prayers that day keep counting', () {
    final day1 = DateTime(2026, 1, 1);
    final day2 = DateTime(2026, 1, 2);
    final day2Logs = _fullDay(day2)
      ..[0] = _log(day2, Prayer.fajr, PrayerStatus.missed);
    final logs = [..._fullDay(day1), ...day2Logs];

    final result = Streak.compute(days: [day1, day2], logs: logs);

    // Fajr (missed) resets the run; Dhuhr..Isha that same day rebuild it.
    expect(result.current, 4);
    expect(result.best, 5);
  });

  test('a late prayer is neutral: it neither extends nor breaks the streak', () {
    final day1 = DateTime(2026, 1, 1);
    final day2 = DateTime(2026, 1, 2);
    final day2Logs = _fullDay(day2)..[0] = _log(day2, Prayer.fajr, PrayerStatus.late);
    final logs = [..._fullDay(day1), ...day2Logs];

    final result = Streak.compute(days: [day1, day2], logs: logs);

    // Fajr (late) doesn't add to the run and doesn't reset it either, so
    // day1's 5 plus day2's remaining 4 (Dhuhr..Isha) carry straight through.
    expect(result.current, 9);
    expect(result.best, 9);
  });

  test(
      'a period-exempt day does not break the streak, but a prayer logged '
      'before the period began that day still counts', () {
    final day1 = DateTime(2026, 1, 1);
    final periodDay = DateTime(2026, 1, 2);
    final day3 = DateTime(2026, 1, 3);
    final logs = [
      ..._fullDay(day1),
      // Fajr logged before the period started; the rest of the day has no
      // record because the period-exemption UI hides further logging.
      _log(periodDay, Prayer.fajr, PrayerStatus.jamaah),
      ..._fullDay(day3),
    ];

    // Callers pass the *unfiltered* day range for the streak (see Streak's
    // doc comment) — the period day is included here, not dropped.
    final result = Streak.compute(days: [day1, periodDay, day3], logs: logs);

    expect(result.current, 5 + 1 + 5);
    expect(result.best, 5 + 1 + 5);
  });
}
