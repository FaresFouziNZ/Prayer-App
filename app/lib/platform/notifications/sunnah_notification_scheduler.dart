import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../app/sunnah_labels.dart';
import '../../config/prayer_config.dart';
import '../../domain/prayer_engine/prayer.dart';
import '../../domain/schedule/prayer_event.dart';
import '../../domain/tracker/sunnah.dart';
import '../../l10n/app_localizations.dart';
import 'notification_ids.dart';

const String _sunnahChannelId = 'sunnah';

/// Reminders for the rawatib checklist (SRS FR-SN). Rawatib aren't
/// independently timed — the "before" ones are prayed in the adhan-to-iqamah
/// gap, so the reminder fires at adhan itself; the "after" ones (plus Witr,
/// prayed after Isha's own "after" pair) fire a fixed buffer past iqamah,
/// approximating when the fard prayer is likely finished (see
/// [PrayerConfig.sunnahAfterOffsetMinutes]/[PrayerConfig.sunnahWitrOffsetMinutes]
/// — exact completion isn't tracked). One global on/off toggle
/// (`SettingsKeys.sunnahRemindersEnabled`) rather than per-item settings,
/// matching how lightweight this feature is meant to be next to the full
/// per-prayer control the five fard prayers get.
abstract class SunnahNotificationScheduler {
  Future<void> initialize();

  /// [doneToday] skips (or cancels) the reminder for anything already
  /// checked off — no point nagging about a rawatib already prayed.
  Future<void> scheduleForDay({
    required DateTime date,
    required List<PrayerEvent> events,
    required bool enabled,
    required Set<SunnahItem> doneToday,
    required AppLocalizations l10n,
  });

  Future<void> cancelItem(DateTime date, SunnahItem item);

  Future<void> cancelAllForDay(DateTime date);
}

/// A no-op stand-in for tests, matching [UnimplementedNotificationScheduler]
/// and [UnimplementedLiveNotificationScheduler] — the real implementation
/// talks to `flutter_local_notifications`' platform channel, which isn't
/// registered (and would throw) under `flutter_test`.
class UnimplementedSunnahNotificationScheduler
    implements SunnahNotificationScheduler {
  const UnimplementedSunnahNotificationScheduler();

  @override
  Future<void> initialize() async {}

  @override
  Future<void> scheduleForDay({
    required DateTime date,
    required List<PrayerEvent> events,
    required bool enabled,
    required Set<SunnahItem> doneToday,
    required AppLocalizations l10n,
  }) async {}

  @override
  Future<void> cancelItem(DateTime date, SunnahItem item) async {}

  @override
  Future<void> cancelAllForDay(DateTime date) async {}
}

class FlutterLocalNotificationsSunnahScheduler
    implements SunnahNotificationScheduler {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _sunnahChannelId,
        'Sunnah reminders',
        description: 'Reminders for rawatib (sunnah) prayers',
        importance: Importance.defaultImportance,
      ),
    );
    _initialized = true;
  }

  @override
  Future<void> scheduleForDay({
    required DateTime date,
    required List<PrayerEvent> events,
    required bool enabled,
    required Set<SunnahItem> doneToday,
    required AppLocalizations l10n,
  }) async {
    await initialize();
    if (!enabled) {
      await cancelAllForDay(date);
      return;
    }

    final now = DateTime.now();
    final eventsByPrayer = {for (final e in events) e.prayer: e};
    final labels = sunnahLabels(l10n);

    for (final item in SunnahItem.values) {
      if (doneToday.contains(item)) {
        await cancelItem(date, item);
        continue;
      }
      final at = _triggerFor(item, eventsByPrayer);
      if (at == null) continue;
      await _scheduleOne(
        date: date,
        item: item,
        at: at,
        now: now,
        title: labels[item]!,
        body: l10n.sunnahReminderBody(labels[item]!),
      );
    }
  }

  DateTime? _triggerFor(
    SunnahItem item,
    Map<Prayer, PrayerEvent> eventsByPrayer,
  ) {
    switch (item) {
      case SunnahItem.fajrBefore:
        return eventsByPrayer[Prayer.fajr]?.adhanAt;
      case SunnahItem.dhuhrBefore:
        return eventsByPrayer[Prayer.dhuhr]?.adhanAt;
      case SunnahItem.dhuhrAfter:
        return eventsByPrayer[Prayer.dhuhr]?.iqamahAt.add(
          const Duration(minutes: PrayerConfig.sunnahAfterOffsetMinutes),
        );
      case SunnahItem.maghribAfter:
        return eventsByPrayer[Prayer.maghrib]?.iqamahAt.add(
          const Duration(minutes: PrayerConfig.sunnahAfterOffsetMinutes),
        );
      case SunnahItem.ishaAfter:
        return eventsByPrayer[Prayer.isha]?.iqamahAt.add(
          const Duration(minutes: PrayerConfig.sunnahAfterOffsetMinutes),
        );
      case SunnahItem.witr:
        return eventsByPrayer[Prayer.isha]?.iqamahAt.add(
          const Duration(minutes: PrayerConfig.sunnahWitrOffsetMinutes),
        );
    }
  }

  Future<void> _scheduleOne({
    required DateTime date,
    required SunnahItem item,
    required DateTime at,
    required DateTime now,
    required String title,
    required String body,
  }) async {
    final id = NotificationIds.forSunnahItem(date, item);
    if (at.isBefore(now)) {
      await _plugin.cancel(id: id);
      return;
    }
    await _plugin.zonedSchedule(
      id: id,
      scheduledDate: tz.TZDateTime.from(at, tz.local),
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _sunnahChannelId,
          'Sunnah reminders',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  @override
  Future<void> cancelItem(DateTime date, SunnahItem item) async {
    await _plugin.cancel(id: NotificationIds.forSunnahItem(date, item));
  }

  @override
  Future<void> cancelAllForDay(DateTime date) async {
    for (final id in NotificationIds.allSunnahForDay(date)) {
      await _plugin.cancel(id: id);
    }
  }
}
