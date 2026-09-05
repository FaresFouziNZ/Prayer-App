import '../../domain/schedule/prayer_event.dart';

/// Starts, repairs, and ends the iOS Live Activity / Android live
/// notification for the current prayer (SRS FR-LA, §2.7).
///
/// Not implemented in this skeleton. Needs a Swift ActivityKit extension
/// (iOS) and an `ExactAlarmReceiver` + ongoing notification (Android); see
/// 02-Architecture.md §2.7 for the content model both platforms share.
abstract class LiveActivityBridge {
  Future<void> startOrRepair(PrayerEvent event);

  Future<void> end(PrayerEvent event);
}

class UnimplementedLiveActivityBridge implements LiveActivityBridge {
  const UnimplementedLiveActivityBridge();

  @override
  Future<void> startOrRepair(PrayerEvent event) async {}

  @override
  Future<void> end(PrayerEvent event) async {}
}
