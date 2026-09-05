import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_app/domain/prayer_engine/prayer.dart';
import 'package:prayer_app/domain/schedule/iqamah_profile.dart';

void main() {
  test('offsetFor prefers the mosque override when set (FR-IQ-03)', () {
    final profile = IqamahProfile(
      id: 'p1',
      name: 'Test',
      offsetMinutes: const {Prayer.fajr: 25},
      mosqueOverride: const {Prayer.fajr: 30},
    );

    expect(profile.offsetFor(Prayer.fajr), 30);
  });

  test('copyWith with mosqueOverride: null clears an existing override', () {
    final profile = IqamahProfile(
      id: 'p1',
      name: 'Test',
      offsetMinutes: const {Prayer.fajr: 25},
      mosqueOverride: const {Prayer.fajr: 30},
    );

    final cleared = profile.copyWith(mosqueOverride: null);

    expect(cleared.mosqueOverride, isNull);
    expect(cleared.offsetFor(Prayer.fajr), 25);
  });

  test('copyWith without touching mosqueOverride leaves it as-is', () {
    final profile = IqamahProfile(
      id: 'p1',
      name: 'Test',
      offsetMinutes: const {Prayer.fajr: 25},
      mosqueOverride: const {Prayer.fajr: 30},
    );

    final renamed = profile.copyWith(name: 'Renamed');

    expect(renamed.mosqueOverride, const {Prayer.fajr: 30});
  });
}
