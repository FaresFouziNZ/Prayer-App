import 'package:adhan_dart/adhan_dart.dart' as adhan;
import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_app/domain/prayer_engine/prayer.dart';
import 'package:prayer_app/domain/prayer_engine/prayer_time_calculator.dart';

// Structural sanity checks for the Adhan library wrapper. Full validation
// against official Umm al-Qura published times (SRS AC-PT-1: 30 consecutive
// Jeddah dates, ±1 minute) needs real reference data and is tracked
// separately — not something this offline unit test can assert.
void main() {
  const jeddah = adhan.Coordinates(21.5433, 39.1728);

  test('computes times in the expected daily order', () {
    final calculator = PrayerTimeCalculator(coordinates: jeddah);
    final day = calculator.computeForDate(DateTime(2026, 6, 15));

    expect(day.adhanAt(Prayer.fajr).isBefore(day.sunrise), isTrue);
    expect(day.sunrise.isBefore(day.adhanAt(Prayer.dhuhr)), isTrue);
    expect(day.adhanAt(Prayer.dhuhr).isBefore(day.adhanAt(Prayer.asr)), isTrue);
    expect(day.adhanAt(Prayer.asr).isBefore(day.adhanAt(Prayer.maghrib)), isTrue);
    expect(day.adhanAt(Prayer.maghrib).isBefore(day.adhanAt(Prayer.isha)), isTrue);
  });

  test('Islamic midnight falls between Maghrib and the next day (FR-PT-02)', () {
    final calculator = PrayerTimeCalculator(coordinates: jeddah);
    final day = calculator.computeForDate(DateTime(2026, 6, 15));

    expect(day.islamicMidnight.isAfter(day.adhanAt(Prayer.maghrib)), isTrue);
    expect(
      day.islamicMidnight.difference(day.adhanAt(Prayer.maghrib)).inHours,
      lessThan(12),
    );
  });

  test('Ramadan mode pushes Isha later than normal mode (FR-PT-06, C7)', () {
    final date = DateTime(2026, 3, 20);
    final normal = PrayerTimeCalculator(coordinates: jeddah)
        .computeForDate(date);
    final ramadan = PrayerTimeCalculator(coordinates: jeddah, ramadanMode: true)
        .computeForDate(date);

    final delta = ramadan.adhanAt(Prayer.isha).difference(normal.adhanAt(Prayer.isha));
    expect(delta.inMinutes, 30);
  });

  test('is deterministic offline (NFR-01, AC-PT-2)', () {
    final calculator = PrayerTimeCalculator(coordinates: jeddah);
    final date = DateTime(2026, 1, 10);
    final first = calculator.computeForDate(date);
    final second = calculator.computeForDate(date);

    expect(first.adhanAt(Prayer.fajr), second.adhanAt(Prayer.fajr));
    expect(first.adhanAt(Prayer.isha), second.adhanAt(Prayer.isha));
  });
}
