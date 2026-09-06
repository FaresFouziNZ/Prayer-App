import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_app/domain/prayer_engine/hijri_date.dart';

void main() {
  test('recognizes Ramadan 1447 (2026-02-18 to 2026-03-19)', () {
    expect(HijriDate.fromGregorian(DateTime(2026, 2, 18)).isRamadan, isTrue);
    expect(HijriDate.fromGregorian(DateTime(2026, 3, 5)).isRamadan, isTrue);
    expect(HijriDate.fromGregorian(DateTime(2026, 2, 17)).isRamadan, isFalse);
    expect(HijriDate.fromGregorian(DateTime(2026, 3, 20)).isRamadan, isFalse);
  });

  test('longMonthName names Ramadan in English and Arabic', () {
    final ramadan = HijriDate.fromGregorian(DateTime(2026, 3, 5));

    expect(ramadan.longMonthName(arabic: false), 'Ramadan');
    expect(ramadan.longMonthName(arabic: true), 'رمضان');
  });
}
