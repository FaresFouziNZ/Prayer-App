import 'package:hijri/hijri_calendar.dart';

/// Thin wrapper around the `hijri` package's tabular Umm al-Qura conversion
/// (SRS FR-PT-07, FR-RM-01). Kept separate so the rest of the domain layer
/// doesn't depend on the third-party calendar API directly.
class HijriDate {
  final int year;
  final int month;
  final int day;

  const HijriDate({required this.year, required this.month, required this.day});

  factory HijriDate.fromGregorian(DateTime date) {
    final calendar = HijriCalendar.fromDate(date);
    return HijriDate(year: calendar.hYear, month: calendar.hMonth, day: calendar.hDay);
  }

  /// Ramadan is the 9th Hijri month.
  bool get isRamadan => month == 9;
}
