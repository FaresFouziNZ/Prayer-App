import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_app/domain/tracker/prayer_status.dart';
import 'package:prayer_app/platform/notifications/notification_action_ids.dart';

void main() {
  test('maps action ids to the status to log (AC-NT-3)', () {
    expect(NotificationActionIds.statusFor(NotificationActionIds.logJamaah), PrayerStatus.jamaah);
    expect(
      NotificationActionIds.statusFor(NotificationActionIds.logAlone),
      PrayerStatus.onTimeAlone,
    );
    expect(NotificationActionIds.statusFor(NotificationActionIds.notYet), isNull);
    expect(NotificationActionIds.statusFor(null), isNull);
    expect(NotificationActionIds.statusFor('unknown'), isNull);
  });
}
