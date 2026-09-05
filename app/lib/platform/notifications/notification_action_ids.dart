import '../../domain/tracker/prayer_status.dart';

/// Action identifiers for the end-of-window prompt (SRS FR-NT-06):
/// "Did you pray X?" with Jama'ah / Alone / Not yet.
class NotificationActionIds {
  const NotificationActionIds._();

  static const String logJamaah = 'log_jamaah';
  static const String logAlone = 'log_alone';
  static const String notYet = 'not_yet';

  /// The status to log for [actionId], or null for "Not yet" (no-op) or an
  /// unrecognized id.
  static PrayerStatus? statusFor(String? actionId) {
    switch (actionId) {
      case logJamaah:
        return PrayerStatus.jamaah;
      case logAlone:
        return PrayerStatus.onTimeAlone;
      default:
        return null;
    }
  }
}
