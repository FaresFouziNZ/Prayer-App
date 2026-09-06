import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_app/app/app.dart';
import 'package:prayer_app/app/providers.dart';
import 'package:prayer_app/app/router.dart';
import 'package:prayer_app/config/settings_keys.dart';
import 'package:prayer_app/data/db/app_database.dart';
import 'package:prayer_app/data/db/repositories/iqamah_profile_repository.dart';
import 'package:prayer_app/data/db/repositories/settings_repository.dart';
import 'package:prayer_app/data/db/seed.dart';
import 'package:prayer_app/features/home/widgets/today_prayer_list.dart';
import 'package:prayer_app/platform/notifications/notification_scheduler.dart';

// End-to-end smoke test through the real widget tree, Riverpod providers,
// and an in-memory Drift database. This stands in for manual device
// testing, which this environment can't do (no Visual Studio for Windows
// desktop, no configured Android emulator, no macOS for iOS).
//
// Bounded pumps are used instead of pumpAndSettle(): Drift's query-stream
// bookkeeping schedules a zero-duration Timer on every stream cancellation,
// which keeps pumpAndSettle's "no frames scheduled" condition from ever
// being true and makes it spin until its internal timeout.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

// Unmounts the app tree ourselves (instead of relying on testWidgets'
// automatic end-of-test teardown) so the resulting zero-duration Timer has
// a chance to fire under our own pump before the framework's "no pending
// timers" invariant check runs. A bare pump() only flushes microtasks and
// does not advance FakeAsync's clock, so the zero-duration Timer needs a
// pump with a non-zero duration to actually elapse and fire.
//
// Called from a `finally` block in every test below (not just as the last
// statement) so it still runs when an earlier `expect()` throws — otherwise
// a failing assertion skips disposal and the test hangs for 10 minutes on
// the framework's own pending-timer teardown check instead of failing fast.
Future<void> _disposeCleanly(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 1));
  await tester.pump(const Duration(milliseconds: 1));
}

// Prayer names render bilingually (Arabic script + English transliteration,
// FR-UI-03) even in the English locale used by these tests.
const _fajr = 'الفجر (Fajr)';
const _dhuhr = 'الظهر (Dhuhr)';
const _asr = 'العصر (Asr)';
const _maghrib = 'المغرب (Maghrib)';
const _isha = 'العشاء (Isha)';

// NextPrayerCard shows whichever prayer is chronologically next using the
// same bilingual name, which can collide with that same prayer's row below
// depending on the real wall-clock time the tests happen to run at — scope
// prayer-row lookups to TodayPrayerList so taps/assertions never depend on
// which prayer is currently "next".
Finder _prayerRow(String name) =>
    find.descendant(of: find.byType(TodayPrayerList), matching: find.text(name));

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await seedDefaultIqamahProfiles(IqamahProfileRepository(db));
    // The app defaults to Arabic (see SettingsKeys.languageCode's fallback),
    // but most of these tests assert against the bilingual name constants
    // below (FR-UI-03's transliteration, only shown outside Arabic) — pin
    // English here so only the dedicated Arabic test needs to opt in.
    await SettingsRepository(db).setString(SettingsKeys.languageCode, 'en');
    // appRouter is a module-level singleton, so its current location and
    // "loaded branches" state (StatefulShellRoute branches build lazily)
    // would otherwise leak between tests — always start each test at Home.
    appRouter.go('/home');
  });

  tearDown(() => db.close());

  Widget buildApp() {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        // The real scheduler talks to a platform channel that flutter_test
        // doesn't mock; PrayerLogActions calls it on every log/combine.
        notificationSchedulerProvider.overrideWithValue(
          const UnimplementedNotificationScheduler(),
        ),
      ],
      child: const PrayerApp(),
    );
  }

  testWidgets('home screen lists all five prayers, unlogged by default',
      (tester) async {
    try {
      await tester.pumpWidget(buildApp());
      await _settle(tester);

      expect(_prayerRow(_fajr), findsOneWidget);
      expect(_prayerRow(_dhuhr), findsOneWidget);
      expect(_prayerRow(_asr), findsOneWidget);
      expect(_prayerRow(_maghrib), findsOneWidget);
      expect(_prayerRow(_isha), findsOneWidget);
      expect(find.text('Not logged'), findsNWidgets(5));
    } finally {
      await _disposeCleanly(tester);
    }
  });

  testWidgets('logging Fajr as Jama\'ah updates its status chip',
      (tester) async {
    try {
      await tester.pumpWidget(buildApp());
      await _settle(tester);

      await tester.tap(_prayerRow(_fajr));
      await _settle(tester);
      await tester.tap(find.text('Jama\'ah').last);
      await _settle(tester);
      await tester.tap(find.text('Save'));
      await _settle(tester);

      expect(find.text('Jama\'ah'), findsOneWidget);
      expect(find.text('Not logged'), findsNWidgets(4));
    } finally {
      await _disposeCleanly(tester);
    }
  });

  testWidgets('re-logging Fajr edits it in place instead of crashing on '
      'the unique-constraint conflict (AC-TR-1)', (tester) async {
    try {
      await tester.pumpWidget(buildApp());
      await _settle(tester);

      await tester.tap(_prayerRow(_fajr));
      await _settle(tester);
      await tester.tap(find.text('Late'));
      await _settle(tester);
      await tester.tap(find.text('Save'));
      await _settle(tester);
      expect(find.text('Late'), findsOneWidget);

      // Re-open the same prayer and change its status — this is the path
      // that used to hit the (date, prayer) unique constraint directly.
      await tester.tap(_prayerRow(_fajr));
      await _settle(tester);
      await tester.tap(find.text('Jama\'ah').last);
      await _settle(tester);
      await tester.tap(find.text('Save'));
      await _settle(tester);

      expect(find.text('Jama\'ah'), findsOneWidget);
      expect(find.text('Late'), findsNothing);
      expect(find.text('Not logged'), findsNWidgets(4));
    } finally {
      await _disposeCleanly(tester);
    }
  });

  testWidgets('deleting a logged prayer returns it to Not logged',
      (tester) async {
    try {
      await tester.pumpWidget(buildApp());
      await _settle(tester);

      await tester.tap(_prayerRow(_fajr));
      await _settle(tester);
      await tester.tap(find.text('Missed'));
      await _settle(tester);
      await tester.tap(find.text('Save'));
      await _settle(tester);
      expect(find.text('Not logged'), findsNWidgets(4));

      await tester.tap(_prayerRow(_fajr));
      await _settle(tester);
      await tester.tap(find.text('Delete'));
      await _settle(tester);

      expect(find.text('Not logged'), findsNWidgets(5));
    } finally {
      await _disposeCleanly(tester);
    }
  });

  testWidgets('toggling a Sunnah item persists it', (tester) async {
    // The Sunnah checklist sits below the prayer list, past the default
    // 800x600 test surface — use a taller virtual screen so the whole page
    // is built and hit-testable without a scroll gesture.
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    try {
      await tester.pumpWidget(buildApp());
      await _settle(tester);

      await tester.tap(find.text('Witr'));
      await _settle(tester);

      final checkbox = tester.widget<CheckboxListTile>(
        find.widgetWithText(CheckboxListTile, 'Witr'),
      );
      expect(checkbox.value, isTrue);
    } finally {
      await _disposeCleanly(tester);
    }
  });

  testWidgets('history, stats, and qada tabs render without crashing',
      (tester) async {
    try {
      await tester.pumpWidget(buildApp());
      await _settle(tester);

      await tester.tap(find.byIcon(Icons.history));
      await _settle(tester);
      expect(find.text('History'), findsWidgets);

      await tester.tap(find.byIcon(Icons.bar_chart));
      await _settle(tester);
      expect(find.text('Overall'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.balance));
      await _settle(tester);
      // Qada-specific text: other visited tabs (Home) stay mounted inside
      // the IndexedStack, so a bare prayer name would match there too.
      expect(find.text('Plan: qada per day'), findsOneWidget);
    } finally {
      await _disposeCleanly(tester);
    }
  });

  testWidgets('toggling Ramadan mode in settings persists to the database',
      (tester) async {
    try {
      await tester.pumpWidget(buildApp());
      await _settle(tester);

      await tester.tap(find.byIcon(Icons.settings));
      await _settle(tester);

      await tester.tap(find.widgetWithText(SwitchListTile, 'Ramadan mode'));
      await _settle(tester);

      final settings = SettingsRepository(db);
      expect(await settings.getBool(SettingsKeys.ramadanMode), isTrue);
    } finally {
      await _disposeCleanly(tester);
    }
  });

  testWidgets('setting a manual location persists its coordinates (FR-PT-03)',
      (tester) async {
    try {
      await tester.pumpWidget(buildApp());
      await _settle(tester);

      await tester.tap(find.byIcon(Icons.settings));
      await _settle(tester);

      await tester.tap(find.text('Manual'));
      await _settle(tester);

      // Manual mode is the only state that builds any TextFields on this
      // screen: label, latitude, longitude, in that order.
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Madinah');
      await tester.enterText(fields.at(1), '24.4667');
      await tester.enterText(fields.at(2), '39.6111');
      await _settle(tester);
      await tester.tap(find.text('Save location'));
      await _settle(tester);

      final settings = SettingsRepository(db);
      expect(await settings.getString(SettingsKeys.locationMode), 'manual');
      expect(await settings.getDouble(SettingsKeys.latitude), 24.4667);
      expect(await settings.getDouble(SettingsKeys.longitude), 39.6111);
    } finally {
      await _disposeCleanly(tester);
    }
  });

  testWidgets('combining Dhuhr with Asr while travelling logs both (FR-TR-06)',
      (tester) async {
    try {
      await tester.pumpWidget(buildApp());
      await _settle(tester);

      await tester.tap(_prayerRow(_dhuhr));
      await _settle(tester);
      await tester.tap(find.text('Travelling — combine with $_asr'));
      await _settle(tester);
      await tester.tap(find.text('Jama\'ah').last);
      await _settle(tester);
      await tester.tap(find.text('Save'));
      await _settle(tester);

      expect(find.text('Jama\'ah'), findsNWidgets(2));
      expect(find.textContaining('Combined with'), findsNWidgets(2));
    } finally {
      await _disposeCleanly(tester);
    }
  });

  testWidgets('suggests enabling Ramadan mode during Ramadan (FR-RM-01)',
      (tester) async {
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            todayProvider.overrideWithValue(DateTime(2026, 3, 5)), // Ramadan 1447
          ],
          child: const PrayerApp(),
        ),
      );
      await _settle(tester);

      expect(find.text('It looks like Ramadan has begun'), findsOneWidget);

      await tester.tap(find.text('Enable'));
      await _settle(tester);

      final settings = SettingsRepository(db);
      expect(await settings.getBool(SettingsKeys.ramadanMode), isTrue);
    } finally {
      await _disposeCleanly(tester);
    }
  });

  testWidgets('turning off Fajr notifications persists the setting (FR-NT-01)',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    try {
      await tester.pumpWidget(buildApp());
      await _settle(tester);

      await tester.tap(find.byIcon(Icons.settings));
      await _settle(tester);

      final fajrTile = find.ancestor(
        of: find.text(_fajr),
        matching: find.byType(ListTile),
      );
      await tester.tap(find.descendant(of: fajrTile, matching: find.byType(Switch)));
      await _settle(tester);

      final settings = SettingsRepository(db);
      expect(await settings.getBool(SettingsKeys.notifyEnabled('fajr')), isFalse);
    } finally {
      await _disposeCleanly(tester);
    }
  });

  testWidgets(
      'switching to Arabic shows prayer names in script only, no transliteration '
      '(FR-UI-01, FR-UI-03)', (tester) async {
    try {
      await SettingsRepository(db).setString(SettingsKeys.languageCode, 'ar');

      await tester.pumpWidget(buildApp());
      await _settle(tester);

      expect(_prayerRow('الفجر'), findsOneWidget);
      expect(_prayerRow(_fajr), findsNothing);
    } finally {
      await _disposeCleanly(tester);
    }
  });

  testWidgets('onboarding: skipping marks it complete and lands on Home',
      (tester) async {
    try {
      appRouter.go('/onboarding');
      await tester.pumpWidget(buildApp());
      await _settle(tester);

      expect(find.text('Welcome to My Prayer'), findsOneWidget);

      await tester.tap(find.text('Skip'));
      await _settle(tester);

      expect(find.byType(TodayPrayerList), findsOneWidget);
      expect(
        await SettingsRepository(db).getBool(SettingsKeys.onboardingComplete),
        isTrue,
      );
    } finally {
      await _disposeCleanly(tester);
    }
  });

  testWidgets(
      'onboarding: paging to the last page and tapping Get Started completes it',
      (tester) async {
    try {
      appRouter.go('/onboarding');
      await tester.pumpWidget(buildApp());
      await _settle(tester);

      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text('Next'));
        await _settle(tester);
      }

      expect(find.text('Get Started'), findsOneWidget);
      await tester.tap(find.text('Get Started'));
      await _settle(tester);

      expect(find.byType(TodayPrayerList), findsOneWidget);
      expect(
        await SettingsRepository(db).getBool(SettingsKeys.onboardingComplete),
        isTrue,
      );
    } finally {
      await _disposeCleanly(tester);
    }
  });
}
