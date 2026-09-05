import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_app/domain/prayer_engine/prayer.dart';
import 'package:prayer_app/domain/prayer_engine/prayer_day.dart';

void main() {
  final day = PrayerDay(
    date: DateTime(2026, 3, 6), // a Friday
    adhan: {
      Prayer.fajr: DateTime(2026, 3, 6, 5, 0),
      Prayer.dhuhr: DateTime(2026, 3, 6, 12, 15),
      Prayer.asr: DateTime(2026, 3, 6, 15, 30),
      Prayer.maghrib: DateTime(2026, 3, 6, 18, 10),
      Prayer.isha: DateTime(2026, 3, 6, 19, 40),
    },
    sunrise: DateTime(2026, 3, 6, 6, 25),
    islamicMidnight: DateTime(2026, 3, 6, 23, 55),
  );

  test('windowEnd maps each prayer to the next boundary (FR-PT-04)', () {
    expect(day.windowEnd(Prayer.fajr), day.sunrise);
    expect(day.windowEnd(Prayer.dhuhr), day.adhanAt(Prayer.asr));
    expect(day.windowEnd(Prayer.asr), day.adhanAt(Prayer.maghrib));
    expect(day.windowEnd(Prayer.maghrib), day.adhanAt(Prayer.isha));
    expect(day.windowEnd(Prayer.isha), day.islamicMidnight);
  });

  test('isJumuah is true only on Friday (FR-PT-05)', () {
    expect(day.isJumuah, isTrue);

    final saturday = PrayerDay(
      date: DateTime(2026, 3, 7),
      adhan: day.adhan,
      sunrise: day.sunrise,
      islamicMidnight: day.islamicMidnight,
    );
    expect(saturday.isJumuah, isFalse);
  });
}
