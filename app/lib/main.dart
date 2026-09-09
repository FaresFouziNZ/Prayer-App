import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/notification_coordinator.dart';
import 'app/providers.dart';
import 'app/router.dart';
import 'config/settings_keys.dart';
import 'data/db/codecs.dart';
import 'data/db/seed.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Best-effort (SRS §1 principle 1: the phone is the source of truth) —
  // a failed/offline init must never block local scheduling or the UI.
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (_) {}

  final container = ProviderContainer();
  await seedDefaultIqamahProfiles(
    container.read(iqamahProfileRepositoryProvider),
  );

  final settings = container.read(settingsRepositoryProvider);
  if (await settings.getString(SettingsKeys.firstLaunchDate) == null) {
    await settings.setString(
      SettingsKeys.firstLaunchDate,
      Codecs.dateKey(DateTime.now()),
    );
  }
  final onboardingComplete =
      await settings.getBool(SettingsKeys.onboardingComplete) ?? false;
  if (!onboardingComplete) {
    appRouter.go('/onboarding');
  }

  // Cold-start scheduling (SRS FR-NT-09's "app open" trigger); resuming
  // from background is handled by PrayerApp's lifecycle observer.
  unawaited(NotificationCoordinator.scheduleUpcomingWindow(container));

  runApp(
    UncontrolledProviderScope(container: container, child: const PrayerApp()),
  );
}
