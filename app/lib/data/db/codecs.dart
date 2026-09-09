import 'dart:convert';

import '../../domain/prayer_engine/prayer.dart';
import '../../domain/tracker/prayer_excuse.dart';
import '../../domain/tracker/prayer_status.dart';
import '../../domain/tracker/sunnah.dart';

/// String/JSON conversions shared by the repositories, matching the storage
/// format documented in SRS §2.4.
class Codecs {
  const Codecs._();

  static String dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static DateTime parseDateKey(String key) {
    final parts = key.split('-');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  static String prayerToDb(Prayer prayer) => prayer.name;

  static Prayer prayerFromDb(String value) =>
      Prayer.values.firstWhere((p) => p.name == value);

  static String? excuseToDb(PrayerExcuse? excuse) => excuse?.name;

  static PrayerExcuse? excuseFromDb(String? value) => value == null
      ? null
      : PrayerExcuse.values.firstWhere((e) => e.name == value);

  static String statusToDb(PrayerStatus status) {
    switch (status) {
      case PrayerStatus.jamaah:
        return 'jamaah';
      case PrayerStatus.onTimeAlone:
        return 'on_time_alone';
      case PrayerStatus.late:
        return 'late';
      case PrayerStatus.missed:
        return 'missed';
    }
  }

  static PrayerStatus statusFromDb(String value) {
    switch (value) {
      case 'jamaah':
        return PrayerStatus.jamaah;
      case 'on_time_alone':
        return PrayerStatus.onTimeAlone;
      case 'late':
        return PrayerStatus.late;
      case 'missed':
        return PrayerStatus.missed;
      default:
        throw ArgumentError('Unknown prayer status: $value');
    }
  }

  static String sunnahItemToDb(SunnahItem item) {
    switch (item) {
      case SunnahItem.fajrBefore:
        return 'fajr_before';
      case SunnahItem.dhuhrBefore:
        return 'dhuhr_before';
      case SunnahItem.dhuhrAfter:
        return 'dhuhr_after';
      case SunnahItem.maghribAfter:
        return 'maghrib_after';
      case SunnahItem.ishaAfter:
        return 'isha_after';
      case SunnahItem.witr:
        return 'witr';
    }
  }

  static SunnahItem sunnahItemFromDb(String value) {
    switch (value) {
      case 'fajr_before':
        return SunnahItem.fajrBefore;
      case 'dhuhr_before':
        return SunnahItem.dhuhrBefore;
      case 'dhuhr_after':
        return SunnahItem.dhuhrAfter;
      case 'maghrib_after':
        return SunnahItem.maghribAfter;
      case 'isha_after':
        return SunnahItem.ishaAfter;
      case 'witr':
        return SunnahItem.witr;
      default:
        throw ArgumentError('Unknown sunnah item: $value');
    }
  }

  static Map<Prayer, int> offsetsFromJson(String json) {
    final map = jsonDecode(json) as Map<String, dynamic>;
    return map.map((key, value) => MapEntry(prayerFromDb(key), value as int));
  }

  static String offsetsToJson(Map<Prayer, int> offsets) {
    return jsonEncode(offsets.map((key, value) => MapEntry(key.name, value)));
  }
}
