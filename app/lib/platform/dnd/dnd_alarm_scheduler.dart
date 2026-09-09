import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';

import '../../domain/prayer_engine/prayer.dart';
import '../../domain/schedule/prayer_event.dart';
import 'dnd_service.dart';

/// Runs in a background isolate owned by `android_alarm_manager_plus`, not
/// the main app isolate — must stay a plain top-level/static function (SRS
/// FR-NT-08).
@pragma('vm:entry-point')
void enableDndCallback() {
  DndService().enablePriorityOnly();
}

@pragma('vm:entry-point')
void disableDndCallback() {
  DndService().disable();
}

/// Deterministic, collision-free alarm ids for the two DND alarms per
/// prayer. `android_alarm_manager_plus` schedules through its own native
/// receiver component, entirely separate from `NotificationIds`'
/// `flutter_local_notifications`-backed alarms, so there's no risk of
/// colliding with those even where the raw integers overlap — this scheme
/// exists only for this class's own clarity.
class _DndAlarmIds {
  const _DndAlarmIds._();

  static int _epochDay(DateTime date) => DateTime(
    date.year,
    date.month,
    date.day,
  ).difference(DateTime(1970)).inDays;

  static int _prayerIndex(Prayer prayer) => Prayer.values.indexOf(prayer);

  static int enable(DateTime date, Prayer prayer) =>
      _epochDay(date) * 100 + _prayerIndex(prayer) * 10;

  static int disable(DateTime date, Prayer prayer) =>
      _epochDay(date) * 100 + _prayerIndex(prayer) * 10 + 1;
}

/// Auto-toggles Android Do Not Disturb around iqamah (SRS FR-NT-08, C2:
/// Android-only). Two exact alarms per prayer — enable "priority only" at
/// iqamah, restore "all" after the configured duration — each running
/// [DndService] directly in a background isolate, so they fire even with
/// the app killed (a plain Dart `Timer` wouldn't survive that; `DndService`
/// itself has no scheduling primitive of its own).
///
/// Applies to every prayer uniformly whenever the single global
/// "silence during prayer" setting is on — there's no per-prayer DND
/// toggle, unlike the per-prayer notification preferences.
class DndAlarmScheduler {
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    await AndroidAlarmManager.initialize();
    _initialized = true;
  }

  Future<void> scheduleForDay({
    required List<PrayerEvent> events,
    required bool dndEnabled,
    required int dndDurationMinutes,
  }) async {
    await initialize();
    final now = DateTime.now();

    for (final event in events) {
      final enableId = _DndAlarmIds.enable(event.date, event.prayer);
      final disableId = _DndAlarmIds.disable(event.date, event.prayer);

      if (!dndEnabled) {
        await AndroidAlarmManager.cancel(enableId);
        await AndroidAlarmManager.cancel(disableId);
        continue;
      }

      if (event.iqamahAt.isBefore(now)) {
        await AndroidAlarmManager.cancel(enableId);
      } else {
        await AndroidAlarmManager.oneShotAt(
          event.iqamahAt,
          enableId,
          enableDndCallback,
          exact: true,
          allowWhileIdle: true,
          wakeup: true,
          rescheduleOnReboot: true,
        );
      }

      final disableAt = event.iqamahAt.add(
        Duration(minutes: dndDurationMinutes),
      );
      if (disableAt.isBefore(now)) {
        await AndroidAlarmManager.cancel(disableId);
      } else {
        await AndroidAlarmManager.oneShotAt(
          disableAt,
          disableId,
          disableDndCallback,
          exact: true,
          allowWhileIdle: true,
          wakeup: true,
          rescheduleOnReboot: true,
        );
      }
    }
  }
}
