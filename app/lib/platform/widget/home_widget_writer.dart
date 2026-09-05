import '../../domain/schedule/prayer_event.dart';

/// Writes the next [PrayerEvent] and today's log status to shared storage
/// for the home screen widget (SRS FR-WD, §2.8).
///
/// Not implemented in this skeleton. Needs the `home_widget` package plus a
/// WidgetKit (iOS) / Glance (Android) extension.
abstract class HomeWidgetWriter {
  Future<void> writeNextEvent(PrayerEvent event);
}

class UnimplementedHomeWidgetWriter implements HomeWidgetWriter {
  const UnimplementedHomeWidgetWriter();

  @override
  Future<void> writeNextEvent(PrayerEvent event) async {}
}
