import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/notification_coordinator.dart';
import 'app/providers.dart';
import 'config/settings_keys.dart';
import 'data/db/codecs.dart';
import 'data/db/seed.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final container = ProviderContainer();
  await seedDefaultIqamahProfiles(
    container.read(iqamahProfileRepositoryProvider),
  );

  final settings = container.read(settingsRepositoryProvider);
  if (await settings.getString(SettingsKeys.firstLaunchDate) == null) {
    await settings.setString(SettingsKeys.firstLaunchDate, Codecs.dateKey(DateTime.now()));
  }

  // Cold-start scheduling (SRS FR-NT-09's "app open" trigger); resuming
  // from background is handled by PrayerApp's lifecycle observer.
  unawaited(NotificationCoordinator.scheduleUpcomingWindow(container));

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const PrayerApp(),
    ),
  );
}
