import 'dart:async' show unawaited;
import 'dart:io' show Platform;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/settings_keys.dart';
import '../data/db/repositories/settings_repository.dart';
import '../data/firebase/firebase_sync_service.dart';
import '../domain/prayer_engine/prayer.dart';
import '../domain/tracker/prayer_status.dart';
import '../domain/tracker/sunnah.dart';
import '../l10n/app_localizations.dart';
import '../domain/schedule/prayer_event.dart';
import '../platform/dnd/dnd_service.dart';
import '../platform/live_activity/pending_live_activity_logs.dart';
import '../platform/notifications/notification_scheduler.dart';
import '../platform/widget/home_widget_scheduler.dart';
import 'providers.dart';

/// Rebuilds and (re)schedules the rolling notification window (SRS FR-NT-09:
/// "refreshed on app open, on background refresh"). This pass implements
/// the "app open" trigger — cold start and resume-from-background — via
/// [NotificationCoordinator.scheduleUpcomingWindow]; BGAppRefresh and a
/// silent push both need infrastructure (background fetch registration,
/// the Firebase backend) that's out of scope here.
class NotificationCoordinator {
  const NotificationCoordinator._();

  static Future<void> scheduleUpcomingWindow(
    ProviderContainer container,
  ) async {
    // Apply any prayer logged from the iOS Live Activity's buttons while
    // this app wasn't running (§2.7's "Buttons" row), before anything below
    // reads today's logs or re-schedules per-prayer notifications.
    await PendingLiveActivityLogs.drainAndApply(container);

    final settings = container.read(settingsRepositoryProvider);
    final scheduler = container.read(notificationSchedulerProvider);
    await scheduler.initialize();
    final liveScheduler = container.read(liveNotificationSchedulerProvider);
    await liveScheduler.initialize();
    final sunnahScheduler = container.read(sunnahNotificationSchedulerProvider);
    await sunnahScheduler.initialize();
    final sunnahRemindersEnabled =
        await settings.getBool(SettingsKeys.sunnahRemindersEnabled) ?? false;

    final today = container.read(todayProvider);
    final tomorrow = today.add(const Duration(days: 1));

    final preferences = <Prayer, PrayerNotificationPreference>{
      for (final prayer in Prayer.values)
        prayer: await _preferenceFor(settings, prayer),
    };

    final languageCode =
        await settings.getString(SettingsKeys.languageCode) ?? 'ar';
    final l10n = lookupAppLocalizations(Locale(languageCode));
    final isArabicLocale = languageCode == 'ar';

    // FR-NT-08, C2: Android-only, and android_alarm_manager_plus itself
    // only works on Android — everything here is skipped elsewhere. Re-check
    // the permission (not just the stored setting) every pass, since it can
    // be revoked from system settings without the app being told directly.
    final dndSettingOn =
        await settings.getBool(SettingsKeys.dndDuringPrayer) ?? false;
    final dndEnabled =
        Platform.isAndroid &&
        dndSettingOn &&
        await DndService().isPermissionGranted();
    final dndDurationMinutes =
        await settings.getInt(SettingsKeys.dndDurationMinutes) ?? 15;
    final dndScheduler = Platform.isAndroid
        ? container.read(dndAlarmSchedulerProvider)
        : null;

    final widgetEvents = <({PrayerEvent event, bool isJumuah})>[];

    for (final date in [today, tomorrow]) {
      final snapshot = await container.read(daySnapshotProvider(date).future);
      await scheduler.scheduleForDay(
        events: snapshot.events,
        isFriday: snapshot.prayerDay.isJumuah,
        preferences: preferences,
        l10n: l10n,
        isArabicLocale: isArabicLocale,
      );
      await liveScheduler.scheduleForDay(
        events: snapshot.events,
        isFriday: snapshot.prayerDay.isJumuah,
        preferences: preferences,
        l10n: l10n,
        isArabicLocale: isArabicLocale,
      );
      if (dndScheduler != null) {
        await dndScheduler.scheduleForDay(
          events: snapshot.events,
          dndEnabled: dndEnabled,
          dndDurationMinutes: dndDurationMinutes,
        );
      }
      final sunnahDoneToday = sunnahRemindersEnabled
          ? (await container.read(sunnahRepositoryProvider).getForDay(date))
                .where((entry) => entry.done)
                .map((entry) => entry.item)
                .toSet()
          : const <SunnahItem>{};
      await sunnahScheduler.scheduleForDay(
        date: date,
        events: snapshot.events,
        enabled: sunnahRemindersEnabled,
        doneToday: sunnahDoneToday,
        l10n: l10n,
      );
      for (final event in snapshot.events) {
        widgetEvents.add((
          event: event,
          isJumuah: snapshot.prayerDay.isJumuah && event.prayer == Prayer.dhuhr,
        ));
      }
    }

    final todayLogs = await container
        .read(prayerLogRepositoryProvider)
        .getForDay(today);
    final todayStatuses = <Prayer, PrayerStatus?>{
      for (final log in todayLogs) log.prayer: log.status,
    };

    await HomeWidgetScheduler.refresh(
      events: widgetEvents,
      todayStatuses: todayStatuses,
      l10n: l10n,
      isArabicLocale: isArabicLocale,
    );

    // FR-SY-02/03: publish settings, tokens, and the 30-day schedule to
    // Firebase. Fire-and-forget — a slow or failed network call must never
    // delay local scheduling, which is already done by this point.
    unawaited(FirebaseSyncService.sync(container));
  }

  static Future<PrayerNotificationPreference> _preferenceFor(
    SettingsRepository settings,
    Prayer prayer,
  ) async {
    final soundValue =
        await settings.getString(SettingsKeys.notifySound(prayer.name)) ??
        'default';
    final soundMode = NotificationSoundMode.fromSettingsValue(soundValue);
    return PrayerNotificationPreference(
      enabled:
          await settings.getBool(SettingsKeys.notifyEnabled(prayer.name)) ??
          true,
      soundMode: soundMode,
      customSoundUri: soundMode == NotificationSoundMode.custom
          ? await settings.getString(SettingsKeys.notifySoundUri(prayer.name))
          : null,
    );
  }
}
