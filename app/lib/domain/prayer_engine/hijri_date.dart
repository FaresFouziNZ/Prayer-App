import 'package:hijri/hijri_calendar.dart';

/// Thin wrapper around the `hijri` package's tabular Umm al-Qura conversion
/// (SRS FR-PT-07, FR-RM-01). Kept separate so the rest of the domain layer
/// doesn't depend on the third-party calendar API directly.
class HijriDate {
  final int year;
  final int month;
  final int day;
  final DateTime _gregorian;

  const HijriDate({
    required this.year,
    required this.month,
    required this.day,
    required this._gregorian,
  });

  factory HijriDate.fromGregorian(DateTime date) {
    final calendar = HijriCalendar.fromDate(date);
    return HijriDate(
      year: calendar.hYear,
      month: calendar.hMonth,
      day: calendar.hDay,
      gregorian: date,
    );
  }

  /// Ramadan is the 9th Hijri month.
  bool get isRamadan => month == 9;

  /// The month's name in English or Arabic, from the `hijri` package's
  /// built-in locale tables (SRS FR-UI-01). Re-derives from the source
  /// Gregorian date rather than calling `HijriCalendar().hDate(...)`
  /// directly — that path leaves the weekday index unset and throws.
  String longMonthName({required bool arabic}) {
    HijriCalendar.language = arabic ? 'ar' : 'en';
    return HijriCalendar.fromDate(_gregorian).longMonthName;
  }
}
