import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/settings_keys.dart';
import '../domain/prayer_engine/prayer.dart';
import '../l10n/app_localizations.dart';
import '../platform/notifications/notification_scheduler.dart';
import 'providers.dart';

/// Rebuilds and (re)schedules the rolling notification window (SRS FR-NT-09:
/// "refreshed on app open, on background refresh"). This pass implements
/// the "app open" trigger — cold start and resume-from-background — via
/// [NotificationCoordinator.scheduleUpcomingWindow]; BGAppRefresh and a
/// silent push both need infrastructure (background fetch registration,
/// the Firebase backend) that's out of scope here.
class NotificationCoordinator {
  const NotificationCoordinator._();

  static Future<void> scheduleUpcomingWindow(ProviderContainer container) async {
    final settings = container.read(settingsRepositoryProvider);
    final scheduler = container.read(notificationSchedulerProvider);
    await scheduler.initialize();

    final today = container.read(todayProvider);
    final tomorrow = today.add(const Duration(days: 1));

    final preferences = <Prayer, PrayerNotificationPreference>{
      for (final prayer in Prayer.values)
        prayer: PrayerNotificationPreference(
          enabled: await settings.getBool(SettingsKeys.notifyEnabled(prayer.name)) ?? true,
          silent:
              (await settings.getString(SettingsKeys.notifySound(prayer.name)) ?? 'default') ==
                  'silent',
        ),
    };

    final languageCode = await settings.getString(SettingsKeys.languageCode) ?? 'ar';
    final l10n = lookupAppLocalizations(Locale(languageCode));
    final isArabicLocale = languageCode == 'ar';

    for (final date in [today, tomorrow]) {
      final snapshot = await container.read(daySnapshotProvider(date).future);
      await scheduler.scheduleForDay(
        events: snapshot.events,
        isFriday: snapshot.prayerDay.isJumuah,
        preferences: preferences,
        l10n: l10n,
        isArabicLocale: isArabicLocale,
      );
    }
  }
}
