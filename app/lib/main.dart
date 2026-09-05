import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/notification_coordinator.dart';
import 'app/providers.dart';
import 'data/db/seed.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final container = ProviderContainer();
  await seedDefaultIqamahProfiles(
    container.read(iqamahProfileRepositoryProvider),
  );

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
