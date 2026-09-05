import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' as intl;

import '../config/settings_keys.dart';
import '../l10n/app_localizations.dart';
import 'notification_coordinator.dart';
import 'providers.dart';
import 'router.dart';
import 'theme.dart';

/// Root widget: MaterialApp.router with theme and localisation bootstrap
/// (SRS FR-UI-01, FR-UI-02), plus refreshing the notification rolling
/// window on resume (SRS FR-NT-09 — the "app foreground" trigger).
class PrayerApp extends ConsumerStatefulWidget {
  const PrayerApp({super.key});

  @override
  ConsumerState<PrayerApp> createState() => _PrayerAppState();
}

class _PrayerAppState extends ConsumerState<PrayerApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      NotificationCoordinator.scheduleUpcomingWindow(ProviderScope.containerOf(context));
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageCodeAsync = ref.watch(_languageCodeProvider);

    return MaterialApp.router(
      title: 'Prayer Discipline',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: appRouter,
      locale: languageCodeAsync.whenOrNull(
        data: (code) => Locale(code),
      ),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}

/// Also syncs `intl`'s default locale so `DateFormat` calls throughout the
/// app (history dates, prayer times) follow the in-app language choice
/// rather than only the OS locale (FR-UI-01).
final _languageCodeProvider = FutureProvider<String>((ref) async {
  final settings = ref.watch(settingsRepositoryProvider);
  final code = await settings.getString(SettingsKeys.languageCode) ?? 'en';
  intl.Intl.defaultLocale = code;
  return code;
});
