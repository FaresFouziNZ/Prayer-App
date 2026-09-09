import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/db/codecs.dart';
import '../../domain/prayer_engine/prayer.dart';
import '../../domain/tracker/prayer_status.dart';
import '../../domain/tracker/tracker_rules.dart';
import '../notifications/notification_action_ids.dart';

const MethodChannel _liveActivityChannel = MethodChannel('live_activity');

/// Applies prayer-log actions tapped on iOS's Live Activity closing-phase
/// buttons (SRS FR-LA-01, docs/02-Architecture.md §2.7's "Buttons" row)
/// while the app wasn't running to receive them directly.
///
/// The Swift side (`LogPrayerIntent`, in `ios/PrayerLiveActivity/`) can't
/// safely apply the tracker's write rules itself — Friday-is-Jama'ah
/// (FR-TR-07), re-log-as-edit (AC-TR-1), etc. all live in [TrackerRules] —
/// without duplicating them in Swift, so it only queues a raw
/// `{date, prayer, status}` record into the shared App Group's
/// `UserDefaults`. This drains that queue through the exact same logging
/// path `notification_response_handler.dart` uses for Android's end-prompt
/// actions, the one time this app can reliably run Dart again: on
/// foreground. See [NotificationCoordinator.scheduleUpcomingWindow], which
/// calls this first, before it rebuilds anything that reads today's logs.
///
/// A no-op on Android (and on iOS until the native side of this channel
/// exists) — `invokeMethod` throws `MissingPluginException` when nothing
/// answers the channel, which this swallows same as
/// [FirebaseSyncService]'s best-effort pattern.
class PendingLiveActivityLogs {
  const PendingLiveActivityLogs._();

  static Future<void> drainAndApply(ProviderContainer container) async {
    List<Object?>? pending;
    try {
      pending = await _liveActivityChannel.invokeMethod<List<Object?>>(
        'drainPendingLogs',
      );
    } catch (_) {
      return;
    }
    if (pending == null || pending.isEmpty) return;

    final repo = container.read(prayerLogRepositoryProvider);
    final scheduler = container.read(notificationSchedulerProvider);
    final liveScheduler = container.read(liveNotificationSchedulerProvider);

    for (final raw in pending) {
      final map = Map<Object?, Object?>.from(raw! as Map);
      final status = NotificationActionIds.statusFor(
        map['status'] as String?,
      );
      if (status == null) continue; // "Not yet" or an unrecognized action.

      final prayerName = map['prayer'] as String?;
      final dateKey = map['date'] as String?;
      if (prayerName == null || dateKey == null) continue;
      final prayer = Prayer.values.asNameMap()[prayerName];
      if (prayer == null) continue;

      final date = Codecs.parseDateKey(dateKey);
      final existing = await repo.getForDate(date, prayer);
      final entry = existing == null
          ? TrackerRules.buildEntry(
              prayer: prayer,
              date: date,
              status: status,
              isFriday: date.weekday == DateTime.friday,
              source: LogSource.liveActivity,
              prayedAt: DateTime.now(),
            )
          : TrackerRules.edit(existing, status: status);
      await repo.upsert(entry);
      await scheduler.cancelForPrayer(date, prayer);
      await liveScheduler.cancelForPrayer(date, prayer);
    }
  }
}
