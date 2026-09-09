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

class _PrayerAppState extends ConsumerState<PrayerApp>
    with WidgetsBindingObserver {
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
      NotificationCoordinator.scheduleUpcomingWindow(
        ProviderScope.containerOf(context),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageCodeAsync = ref.watch(_languageCodeProvider);
    final themeModeAsync = ref.watch(_themeModeProvider);

    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode:
          themeModeAsync.whenOrNull(data: (mode) => mode) ?? ThemeMode.system,
      routerConfig: appRouter,
      locale: languageCodeAsync.whenOrNull(data: (code) => Locale(code)),
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
///
/// A [StreamProvider] over the live setting (rather than a one-shot
/// [FutureProvider]) so switching languages in Settings takes effect
/// immediately, without every settings-writing call site needing to
/// remember to invalidate this provider too.
final _languageCodeProvider = StreamProvider<String>((ref) {
  final settings = ref.watch(settingsRepositoryProvider);
  return settings.watchString(SettingsKeys.languageCode).map((code) {
    final resolved = code ?? 'ar';
    intl.Intl.defaultLocale = resolved;
    return resolved;
  });
});

/// SRS FR-UI-02: the app follows the system theme by default, but a manual
/// override ('light'/'dark') stored under [SettingsKeys.themeMode] wins over
/// it — anything else (including no value yet) means "follow system".
final _themeModeProvider = StreamProvider<ThemeMode>((ref) {
  final settings = ref.watch(settingsRepositoryProvider);
  return settings
      .watchString(SettingsKeys.themeMode)
      .map(
        (mode) => switch (mode) {
          'light' => ThemeMode.light,
          'dark' => ThemeMode.dark,
          _ => ThemeMode.system,
        },
      );
});
