import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_app/app/app.dart';
import 'package:prayer_app/app/providers.dart';
import 'package:prayer_app/app/router.dart';
import 'package:prayer_app/config/settings_keys.dart';
import 'package:prayer_app/data/db/app_database.dart';
import 'package:prayer_app/data/db/codecs.dart';
import 'package:prayer_app/data/db/repositories/iqamah_profile_repository.dart';
import 'package:prayer_app/data/db/repositories/settings_repository.dart';
import 'package:prayer_app/data/db/seed.dart';
import 'package:prayer_app/features/history/history_screen.dart';
import 'package:prayer_app/features/home/widgets/sunnah_checklist.dart';
import 'package:prayer_app/features/home/widgets/today_prayer_list.dart';
import 'package:prayer_app/platform/live_notification/live_notification_scheduler.dart';
import 'package:prayer_app/platform/notifications/notification_scheduler.dart';
import 'package:prayer_app/platform/notifications/sunnah_notification_scheduler.dart';

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
Finder _prayerRow(String name) => find.descendant(
  of: find.byType(TodayPrayerList),
  matching: find.text(name),
);

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
        // The real schedulers talk to platform channels that flutter_test
        // doesn't mock; PrayerLogActions calls both on every log/combine.
        // liveNotificationSchedulerProvider already resolves to its
        // Unimplemented variant off-Android, but pin it explicitly in case
        // this suite is ever run on an Android-hosted test runner.
        notificationSchedulerProvider.overrideWithValue(
          const UnimplementedNotificationScheduler(),
        ),
        liveNotificationSchedulerProvider.overrideWithValue(
          const UnimplementedLiveNotificationScheduler(),
        ),
        sunnahNotificationSchedulerProvider.overrideWithValue(
          const UnimplementedSunnahNotificationScheduler(),
        ),
      ],
      child: const PrayerApp(),
    );
  }

  testWidgets('home screen lists all five prayers, unlogged by default', (
    tester,
  ) async {
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

  testWidgets('logging Fajr as Jama\'ah updates its status chip', (
    tester,
  ) async {
    try {
      await tester.pumpWidget(buildApp());
      await _settle(tester);

      await tester.tap(_prayerRow(_fajr));
      await _settle(tester);
      await tester.tap(find.text('Jama\'ah').last);
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
      await tester.tap(find.text('Overslept'));
      await _settle(tester);
      expect(find.text('Late'), findsOneWidget);

      // Re-open the same prayer and change its status — this is the path
      // that used to hit the (date, prayer) unique constraint directly.
      await tester.tap(_prayerRow(_fajr));
      await _settle(tester);
      await tester.tap(find.text('Jama\'ah').last);
      await _settle(tester);

      expect(find.text('Jama\'ah'), findsOneWidget);
      expect(find.text('Late'), findsNothing);
      expect(find.text('Not logged'), findsNWidgets(4));
    } finally {
      await _disposeCleanly(tester);
    }
  });

  testWidgets('deleting a logged prayer returns it to Not logged', (
    tester,
  ) async {
    try {
      await tester.pumpWidget(buildApp());
      await _settle(tester);

      await tester.tap(_prayerRow(_fajr));
      await _settle(tester);
      await tester.tap(find.text('Missed'));
      await _settle(tester);
      await tester.tap(find.text('Forgot'));
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

  testWidgets('collapsing the Sunnah checklist hides its items and persists', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    try {
      await tester.pumpWidget(buildApp());
      await _settle(tester);

      expect(find.widgetWithText(CheckboxListTile, 'Witr'), findsOneWidget);

      await tester.tap(find.text('Sunnah'));
      await _settle(tester);

      expect(find.widgetWithText(CheckboxListTile, 'Witr'), findsNothing);
      expect(
        await SettingsRepository(
          db,
        ).getBool(SettingsKeys.sunnahChecklistCollapsed),
        isTrue,
      );
    } finally {
      await _disposeCleanly(tester);
    }
  });

  testWidgets('history, stats, and qada tabs render without crashing', (
    tester,
  ) async {
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

  testWidgets(
    'Stats reflects a prayer logged after the Stats tab was already open',
    (tester) async {
      try {
        await tester.pumpWidget(buildApp());
        await _settle(tester);

        // Visit Stats first — regression test for a bug where its data
        // provider was a one-shot fetch that never picked up later edits.
        await tester.tap(find.byIcon(Icons.bar_chart));
        await _settle(tester);
        expect(find.byTooltip("Jama'ah rate: 100%"), findsNothing);

        await tester.tap(find.byIcon(Icons.mosque_outlined));
        await _settle(tester);
        await tester.tap(_prayerRow(_fajr));
        await _settle(tester);
        await tester.tap(find.text('Jama\'ah').last);
        await _settle(tester);

        await tester.tap(find.byIcon(Icons.bar_chart));
        await _settle(tester);
        expect(find.byTooltip("Jama'ah rate: 100%"), findsWidgets);
      } finally {
        await _disposeCleanly(tester);
      }
    },
  );

  testWidgets('toggling Ramadan mode in settings persists to the database', (
    tester,
  ) async {
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

  testWidgets(
    'combining Dhuhr with Asr while travelling logs both (FR-TR-06)',
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

        expect(find.text('Jama\'ah'), findsNWidgets(2));
        expect(find.textContaining('Combined with'), findsNWidgets(2));
      } finally {
        await _disposeCleanly(tester);
      }
    },
  );

  testWidgets(
    'deleting one half of a combined pair deletes its partner too (FR-TR-06)',
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
        expect(find.text('Jama\'ah'), findsNWidgets(2));

        // Deleting just the Dhuhr half should also remove the Asr half it
        // was combined with, not leave it dangling.
        await tester.tap(_prayerRow(_dhuhr));
        await _settle(tester);
        await tester.tap(find.text('Delete'));
        await _settle(tester);

        expect(find.text('Jama\'ah'), findsNothing);
        expect(find.text('Not logged'), findsNWidgets(5));
      } finally {
        await _disposeCleanly(tester);
      }
    },
  );

  testWidgets('suggests enabling Ramadan mode during Ramadan (FR-RM-01)', (
    tester,
  ) async {
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            todayProvider.overrideWithValue(
              DateTime(2026, 3, 5),
            ), // Ramadan 1447
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

  testWidgets(
    'turning off Fajr notifications persists the setting (FR-NT-01)',
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
          matching: find.byType(Row),
        );
        await tester.tap(
          find.descendant(of: fajrTile.first, matching: find.byType(Switch)),
        );
        await _settle(tester);

        final settings = SettingsRepository(db);
        expect(
          await settings.getBool(SettingsKeys.notifyEnabled('fajr')),
          isFalse,
        );
      } finally {
        await _disposeCleanly(tester);
      }
    },
  );

  testWidgets('enabling sunnah reminders persists the setting (FR-SN)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    try {
      await tester.pumpWidget(buildApp());
      await _settle(tester);

      await tester.tap(find.byIcon(Icons.settings));
      await _settle(tester);

      await tester.tap(find.text('Remind me for rawatib'));
      await _settle(tester);

      final settings = SettingsRepository(db);
      expect(
        await settings.getBool(SettingsKeys.sunnahRemindersEnabled),
        isTrue,
      );
    } finally {
      await _disposeCleanly(tester);
    }
  });

  testWidgets(
    'switching to Arabic shows prayer names in script only, no transliteration '
    '(FR-UI-01, FR-UI-03)',
    (tester) async {
      try {
        await SettingsRepository(db).setString(SettingsKeys.languageCode, 'ar');

        await tester.pumpWidget(buildApp());
        await _settle(tester);

        expect(_prayerRow('الفجر'), findsOneWidget);
        expect(_prayerRow(_fajr), findsNothing);
      } finally {
        await _disposeCleanly(tester);
      }
    },
  );

  testWidgets('onboarding: skipping marks it complete and lands on Home', (
    tester,
  ) async {
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
    },
  );

  testWidgets('History pre-install days are collapsed by default but expand to '
      'become backfillable', (tester) async {
    try {
      // A fresh install today: everything before today is "pre-install".
      await SettingsRepository(
        db,
      ).setString(SettingsKeys.firstLaunchDate, Codecs.dateKey(DateTime.now()));
      await tester.pumpWidget(buildApp());
      await _settle(tester);

      await tester.tap(find.byIcon(Icons.history));
      await _settle(tester);

      final historyRows = find.descendant(
        of: find.byType(HistoryScreen),
        matching: find.byType(ListTile),
      );
      // Collapsed by default: just "Today" and the pre-install notice —
      // dismissing this was the only thing you could do with those days.
      expect(historyRows, findsNWidgets(2));
      expect(find.text('29 days before you installed the app'), findsOneWidget);

      // Tapping the notice (not the dismiss X) expands it into 29
      // individual, tappable rows — the days are accessible for backfill,
      // not just hidden behind a one-way dismiss.
      await tester.tap(find.text('29 days before you installed the app'));
      await _settle(tester);
      expect(historyRows, findsNWidgets(2 + 29));

      // The last expanded row is built but off the (short, test-viewport)
      // screen — scroll it into view before tapping.
      await tester.ensureVisible(historyRows.last);
      await _settle(tester);
      await tester.tap(historyRows.last);
      await _settle(tester);
      expect(find.byType(TodayPrayerList), findsOneWidget);
    } finally {
      await _disposeCleanly(tester);
    }
  });

  testWidgets('marking today as a period day excuses it instead of leaving it '
      'loggable', (tester) async {
    // Both the period-tracking toggle (Settings) and the sunnah checklist
    // (Home) sit below the default 800x600 test surface, past what a
    // lazy sliver inflates without scrolling — use a taller virtual screen
    // so the whole page is built and hit-testable directly.
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    try {
      await tester.pumpWidget(buildApp());
      await _settle(tester);

      await tester.tap(find.byIcon(Icons.settings));
      await _settle(tester);
      await tester.tap(
        find.widgetWithText(SwitchListTile, 'Enable period tracking'),
      );
      await _settle(tester);

      await tester.tap(find.byIcon(Icons.mosque_outlined));
      await _settle(tester);
      expect(_prayerRow(_fajr), findsOneWidget);
      expect(find.byType(SunnahChecklist), findsOneWidget);

      await tester.tap(find.widgetWithText(SwitchListTile, 'Period day'));
      await _settle(tester);

      expect(_prayerRow(_fajr), findsNothing);
      expect(find.text('Prayers excused today'), findsOneWidget);
      // The exemption covers sunnah too (product decision 2026-09-07) —
      // nothing left to log for a period day, obligatory or voluntary.
      expect(find.byType(SunnahChecklist), findsNothing);
    } finally {
      await _disposeCleanly(tester);
    }
  });

  testWidgets(
    'choosing Dark in Settings switches the app theme and persists it',
    (tester) async {
      // The Appearance section sits well below the default 800x600 test
      // surface, past what a lazy sliver inflates without scrolling — use a
      // taller virtual screen so the whole settings list is built and
      // hit-testable directly.
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      try {
        await tester.pumpWidget(buildApp());
        await _settle(tester);

        await tester.tap(find.byIcon(Icons.settings));
        await _settle(tester);

        final themeTile = find.ancestor(
          of: find.text('Theme'),
          matching: find.byType(Column),
        );
        await tester.tap(
          find.descendant(of: themeTile.first, matching: find.text('Dark')),
        );
        await _settle(tester);

        final settings = SettingsRepository(db);
        expect(await settings.getString(SettingsKeys.themeMode), 'dark');
        final materialApp = tester.widget<MaterialApp>(
          find.byType(MaterialApp),
        );
        expect(materialApp.themeMode, ThemeMode.dark);
      } finally {
        await _disposeCleanly(tester);
      }
    },
  );
}
