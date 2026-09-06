import '../prayer_engine/prayer.dart';
import '../prayer_engine/prayer_day.dart';
import 'iqamah_profile.dart';
import 'prayer_event.dart';

/// Settings consumed by [ScheduleBuilder] that are not part of the prayer
/// times or the iqamah profile.
class ScheduleSettings {
  final int closingOffsetMinutes;
  final int preAdhanOffsetMinutes;

  const ScheduleSettings({
    required this.closingOffsetMinutes,
    required this.preAdhanOffsetMinutes,
  });
}

/// Turns a [PrayerDay] and [IqamahProfile] into the list of [PrayerEvent]s
/// consumed by every surface (SRS §2.3). This is the single function that
/// turns times into events.
class ScheduleBuilder {
  const ScheduleBuilder._();

  static List<PrayerEvent> build(
    PrayerDay day,
    IqamahProfile profile,
    ScheduleSettings settings,
  ) {
    return Prayer.values.map((prayer) {
      final adhanAt = day.adhanAt(prayer);
      final preAdhanAt = adhanAt.subtract(
        Duration(minutes: settings.preAdhanOffsetMinutes),
      );
      final iqamahAt = adhanAt.add(Duration(minutes: profile.offsetFor(prayer)));
      final endAt = day.windowEnd(prayer);
      final closingAt = endAt.subtract(
        Duration(minutes: settings.closingOffsetMinutes),
      );

      return PrayerEvent(
        prayer: prayer,
        date: day.date,
        preAdhanAt: preAdhanAt,
        adhanAt: adhanAt,
        iqamahAt: iqamahAt,
        closingAt: closingAt.isBefore(iqamahAt) ? iqamahAt : closingAt,
        endAt: endAt,
      );
    }).toList(growable: false);
  }
}
