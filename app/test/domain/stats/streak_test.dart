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
  test('consecutive fully-logged, non-missed days extend the streak (FR-ST-03)', () {
    final days = List.generate(3, (i) => DateTime(2026, 1, 1 + i));
    final logs = days.expand(_fullDay).toList();

    final result = Streak.compute(days: days, logs: logs);

    expect(result.current, 3);
    expect(result.best, 3);
  });

  test('a day with fewer than five logs is neutral, not a break (AC-ST-2)', () {
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

    expect(result.current, 2);
  });

  test('any missed record on a day breaks the streak', () {
    final day1 = DateTime(2026, 1, 1);
    final day2 = DateTime(2026, 1, 2);
    final day2Logs = _fullDay(day2)
      ..[0] = _log(day2, Prayer.fajr, PrayerStatus.missed);
    final logs = [..._fullDay(day1), ...day2Logs];

    final result = Streak.compute(days: [day1, day2], logs: logs);

    expect(result.current, 0);
    expect(result.best, 1);
  });
}
