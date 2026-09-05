import 'prayer.dart';

/// The five adhan times, sunrise, and Islamic midnight for one calendar day.
///
/// Pure data, no I/O (SRS §2.3). All times are local `DateTime`s.
class PrayerDay {
  final DateTime date;
  final Map<Prayer, DateTime> adhan;
  final DateTime sunrise;
  final DateTime islamicMidnight;

  const PrayerDay({
    required this.date,
    required this.adhan,
    required this.sunrise,
    required this.islamicMidnight,
  });

  DateTime adhanAt(Prayer prayer) => adhan[prayer]!;

  /// Window end times per SRS FR-PT-04:
  /// Fajr → sunrise; Dhuhr → Asr; Asr → Maghrib; Maghrib → Isha;
  /// Isha → Islamic midnight.
  DateTime windowEnd(Prayer prayer) {
    switch (prayer) {
      case Prayer.fajr:
        return sunrise;
      case Prayer.dhuhr:
        return adhan[Prayer.asr]!;
      case Prayer.asr:
        return adhan[Prayer.maghrib]!;
      case Prayer.maghrib:
        return adhan[Prayer.isha]!;
      case Prayer.isha:
        return islamicMidnight;
    }
  }

  /// True on Fridays, when Dhuhr is presented as Jumu'ah (FR-PT-05).
  bool get isJumuah => date.weekday == DateTime.friday;
}
