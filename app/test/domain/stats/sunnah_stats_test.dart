import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_app/domain/stats/sunnah_stats.dart';
import 'package:prayer_app/domain/tracker/sunnah.dart';

SunnahLogEntry _entry(DateTime date, SunnahItem item, bool done) {
  return SunnahLogEntry(date: date, item: item, done: done, loggedAt: date);
}

void main() {
  test('completion rate is done-days over total days per item', () {
    final day1 = DateTime(2026, 1, 1);
    final day2 = DateTime(2026, 1, 2);
    final entries = [
      _entry(day1, SunnahItem.witr, true),
      _entry(day2, SunnahItem.witr, false),
      _entry(day1, SunnahItem.fajrBefore, true),
    ];

    final rates = SunnahStats.completionRate(days: [day1, day2], entries: entries);

    expect(rates[SunnahItem.witr], 0.5);
    expect(rates[SunnahItem.fajrBefore], 0.5); // done day1, no row day2 = not done
    expect(rates[SunnahItem.maghribAfter], 0.0);
  });

  test('empty day list yields zero rates without dividing by zero', () {
    final rates = SunnahStats.completionRate(days: const [], entries: const []);
    expect(rates[SunnahItem.witr], 0.0);
  });
}
