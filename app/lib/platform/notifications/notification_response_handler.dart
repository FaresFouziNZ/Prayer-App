import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../data/db/app_database.dart';
import '../../data/db/repositories/prayer_log_repository.dart';
import '../../domain/tracker/prayer_status.dart';
import '../../domain/tracker/tracker_rules.dart';
import 'notification_action_ids.dart';
import 'notification_payload.dart';

/// Handles a tap on the end-of-window prompt's Jama'ah/Alone/Not yet
/// actions (SRS FR-NT-06, AC-NT-3): "Actions log without opening the app."
///
/// Used for both the foreground callback and the background one — the
/// background callback runs in its own isolate with no access to the app's
/// running providers, so this opens its own short-lived database
/// connection either way rather than assuming a shared one exists.
Future<void> handleNotificationResponse(NotificationResponse response) async {
  final status = NotificationActionIds.statusFor(response.actionId);
  if (status == null) return; // "Not yet" or a plain tap: no write.

  final payload = response.payload;
  if (payload == null) return;
  final decoded = NotificationPayload.decode(payload);

  final db = AppDatabase();
  try {
    final repo = PrayerLogRepository(db);
    final existing = await repo.getForDate(decoded.date, decoded.prayer);
    final entry = existing == null
        ? TrackerRules.buildEntry(
            prayer: decoded.prayer,
            date: decoded.date,
            status: status,
            isFriday: decoded.date.weekday == DateTime.friday,
            source: LogSource.notificationAction,
            prayedAt: DateTime.now(),
          )
        : TrackerRules.edit(existing, status: status);
    await repo.upsert(entry);
  } finally {
    await db.close();
  }
}

/// Registered with `onDidReceiveBackgroundNotificationResponse`. Needs the
/// `vm:entry-point` pragma so the background isolate's snapshot keeps this
/// function even though nothing in the main isolate calls it directly.
@pragma('vm:entry-point')
void notificationBackgroundHandler(NotificationResponse response) {
  handleNotificationResponse(response);
}
