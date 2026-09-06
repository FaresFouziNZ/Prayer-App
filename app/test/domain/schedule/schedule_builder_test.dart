import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_app/domain/prayer_engine/prayer.dart';
import 'package:prayer_app/domain/prayer_engine/prayer_day.dart';
import 'package:prayer_app/domain/schedule/iqamah_profile.dart';
import 'package:prayer_app/domain/schedule/schedule_builder.dart';

void main() {
  final day = PrayerDay(
    date: DateTime(2026, 3, 5),
    adhan: {
      Prayer.fajr: DateTime(2026, 3, 5, 5, 0),
      Prayer.dhuhr: DateTime(2026, 3, 5, 12, 15),
      Prayer.asr: DateTime(2026, 3, 5, 15, 30),
      Prayer.maghrib: DateTime(2026, 3, 5, 18, 10),
      Prayer.isha: DateTime(2026, 3, 5, 19, 40),
    },
    sunrise: DateTime(2026, 3, 5, 6, 25),
    islamicMidnight: DateTime(2026, 3, 6, 0, 0),
  );

  final profile = IqamahProfile(
    id: 'normal',
    name: 'Normal',
    offsetMinutes: const {
      Prayer.fajr: 25,
      Prayer.dhuhr: 20,
      Prayer.asr: 20,
      Prayer.maghrib: 10,
      Prayer.isha: 15,
    },
  );

  const settings = ScheduleSettings(
    closingOffsetMinutes: 30,
    preAdhanOffsetMinutes: 10,
  );

  test('pre-adhan is adhan minus the configured offset (FR-NT-03)', () {
    final events = ScheduleBuilder.build(day, profile, settings);
    final fajr = events.firstWhere((e) => e.prayer == Prayer.fajr);

    expect(fajr.preAdhanAt, fajr.adhanAt.subtract(const Duration(minutes: 10)));
  });

  test('iqamah is adhan plus the profile offset (FR-IQ-01)', () {
    final events = ScheduleBuilder.build(day, profile, settings);
    final dhuhr = events.firstWhere((e) => e.prayer == Prayer.dhuhr);

    expect(dhuhr.iqamahAt, day.adhanAt(Prayer.dhuhr).add(const Duration(minutes: 20)));
  });

  test('closing is the window end minus the closing offset (FR-NT-05)', () {
    final events = ScheduleBuilder.build(day, profile, settings);
    final fajr = events.firstWhere((e) => e.prayer == Prayer.fajr);

    expect(fajr.endAt, day.sunrise);
    expect(fajr.closingAt, day.sunrise.subtract(const Duration(minutes: 30)));
  });

  test('closing never lands before iqamah on a very short window', () {
    final tightProfile = profile.copyWith(
      offsetMinutes: const {
        Prayer.fajr: 80, // pushes iqamah close to sunrise
        Prayer.dhuhr: 20,
        Prayer.asr: 20,
        Prayer.maghrib: 10,
        Prayer.isha: 15,
      },
    );
    final events = ScheduleBuilder.build(day, tightProfile, settings);
    final fajr = events.firstWhere((e) => e.prayer == Prayer.fajr);

    expect(fajr.closingAt.isBefore(fajr.iqamahAt), isFalse);
  });
}
