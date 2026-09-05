import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../app/prayer_names.dart';
import '../../domain/prayer_engine/prayer.dart';
import '../../domain/schedule/prayer_event.dart';
import '../../l10n/app_localizations.dart';
import 'notification_action_ids.dart';
import 'notification_ids.dart';
import 'notification_payload.dart';
import 'notification_response_handler.dart';

/// Per-prayer notification settings (SRS FR-NT-01, FR-NT-02).
class PrayerNotificationPreference {
  final bool enabled;
  final bool silent;

  const PrayerNotificationPreference({required this.enabled, required this.silent});
}

/// Schedules a rolling window of local notifications for a list of
/// [PrayerEvent]s (SRS FR-NT, §2.6): adhan, pre-adhan, leave-by, closing,
/// and the end-prompt, and cancels the conditional ones once a prayer is
/// logged.
abstract class NotificationScheduler {
  Future<void> initialize();

  Future<void> scheduleForDay({
    required List<PrayerEvent> events,
    required bool isFriday,
    required Map<Prayer, PrayerNotificationPreference> preferences,
    required AppLocalizations l10n,
    required bool isArabicLocale,
  });

  Future<void> cancelForPrayer(DateTime date, Prayer prayer);

  Future<void> cancelAllForDay(DateTime date);
}

class UnimplementedNotificationScheduler implements NotificationScheduler {
  const UnimplementedNotificationScheduler();

  @override
  Future<void> initialize() async {}

  @override
  Future<void> scheduleForDay({
    required List<PrayerEvent> events,
    required bool isFriday,
    required Map<Prayer, PrayerNotificationPreference> preferences,
    required AppLocalizations l10n,
    required bool isArabicLocale,
  }) async {}

  @override
  Future<void> cancelForPrayer(DateTime date, Prayer prayer) async {}

  @override
  Future<void> cancelAllForDay(DateTime date) async {}
}

const String _adhanChannelId = 'adhan';
const String _remindersChannelId = 'reminders';
const String _endPromptCategoryId = 'end_prompt';

/// Real implementation backed by `flutter_local_notifications`
/// (SRS §2.1 stack table).
class FlutterLocalNotificationsScheduler implements NotificationScheduler {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    final localTimezone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localTimezone.identifier));

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    final darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      notificationCategories: [
        DarwinNotificationCategory(
          _endPromptCategoryId,
          actions: [
            DarwinNotificationAction.plain(
              NotificationActionIds.logJamaah,
              'Jama\'ah',
              options: {DarwinNotificationActionOption.foreground},
            ),
            DarwinNotificationAction.plain(
              NotificationActionIds.logAlone,
              'Alone',
              options: {DarwinNotificationActionOption.foreground},
            ),
            DarwinNotificationAction.plain(NotificationActionIds.notYet, 'Not yet'),
          ],
        ),
      ],
    );

    await _plugin.initialize(
      settings: InitializationSettings(android: androidSettings, iOS: darwinSettings),
      onDidReceiveNotificationResponse: (response) {
        handleNotificationResponse(response);
      },
      onDidReceiveBackgroundNotificationResponse: notificationBackgroundHandler,
    );

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.requestExactAlarmsPermission();
    await androidPlugin?.createNotificationChannel(const AndroidNotificationChannel(
      _adhanChannelId,
      'Adhan',
      description: 'Adhan notifications for each prayer',
      importance: Importance.high,
    ));
    await androidPlugin?.createNotificationChannel(const AndroidNotificationChannel(
      _remindersChannelId,
      'Reminders',
      description: 'Pre-adhan, leave-by, and window-closing reminders',
      importance: Importance.defaultImportance,
    ));

    _initialized = true;
  }

  @override
  Future<void> scheduleForDay({
    required List<PrayerEvent> events,
    required bool isFriday,
    required Map<Prayer, PrayerNotificationPreference> preferences,
    required AppLocalizations l10n,
    required bool isArabicLocale,
  }) async {
    await initialize();
    final now = DateTime.now();

    for (final event in events) {
      final preference = preferences[event.prayer];
      if (preference == null || !preference.enabled) {
        await cancelForPrayer(event.date, event.prayer);
        continue;
      }

      final isJumuah = isFriday && event.prayer == Prayer.dhuhr;
      final name = PrayerNames.displayNameFor(l10n, isArabicLocale, event.prayer,
          isJumuah: isJumuah);
      final payload = NotificationPayload(date: event.date, prayer: event.prayer).encode();

      await _scheduleOne(
        id: NotificationIds.forEvent(event.date, event.prayer, NotificationKind.preAdhan),
        at: event.preAdhanAt,
        now: now,
        title: name,
        body: l10n.notifPreAdhanBody(name),
        channelId: _remindersChannelId,
        silent: preference.silent,
        payload: payload,
      );
      await _scheduleOne(
        id: NotificationIds.forEvent(event.date, event.prayer, NotificationKind.adhan),
        at: event.adhanAt,
        now: now,
        title: name,
        body: l10n.notifAdhanBody(name),
        channelId: _adhanChannelId,
        silent: preference.silent,
        payload: payload,
      );
      await _scheduleOne(
        id: NotificationIds.forEvent(event.date, event.prayer, NotificationKind.leaveBy),
        at: event.leaveByAt,
        now: now,
        title: name,
        body: l10n.notifLeaveByBody(name),
        channelId: _remindersChannelId,
        silent: preference.silent,
        payload: payload,
      );
      await _scheduleOne(
        id: NotificationIds.forEvent(event.date, event.prayer, NotificationKind.closing),
        at: event.closingAt,
        now: now,
        title: name,
        body: l10n.notifClosingBody(name),
        channelId: _remindersChannelId,
        silent: preference.silent,
        payload: payload,
      );
      await _scheduleOne(
        id: NotificationIds.forEvent(event.date, event.prayer, NotificationKind.endPrompt),
        at: event.endAt,
        now: now,
        title: l10n.notifEndPromptTitle(name),
        body: '',
        channelId: _remindersChannelId,
        silent: preference.silent,
        payload: payload,
        withActions: true,
      );
    }
  }

  Future<void> _scheduleOne({
    required int id,
    required DateTime at,
    required DateTime now,
    required String title,
    required String body,
    required String channelId,
    required bool silent,
    required String payload,
    bool withActions = false,
  }) async {
    if (at.isBefore(now)) {
      await _plugin.cancel(id: id);
      return;
    }

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelId == _adhanChannelId ? 'Adhan' : 'Reminders',
        importance: withActions ? Importance.high : Importance.defaultImportance,
        priority: withActions ? Priority.high : Priority.defaultPriority,
        silent: silent,
        actions: withActions
            ? const [
                AndroidNotificationAction(
                  NotificationActionIds.logJamaah,
                  'Jama\'ah',
                  showsUserInterface: false,
                ),
                AndroidNotificationAction(
                  NotificationActionIds.logAlone,
                  'Alone',
                  showsUserInterface: false,
                ),
                AndroidNotificationAction(
                  NotificationActionIds.notYet,
                  'Not yet',
                  showsUserInterface: false,
                ),
              ]
            : null,
      ),
      iOS: DarwinNotificationDetails(
        presentSound: !silent,
        categoryIdentifier: withActions ? _endPromptCategoryId : null,
      ),
    );

    await _plugin.zonedSchedule(
      id: id,
      scheduledDate: tz.TZDateTime.from(at, tz.local),
      title: title,
      body: body,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: payload,
    );
  }

  @override
  Future<void> cancelForPrayer(DateTime date, Prayer prayer) async {
    for (final id in NotificationIds.conditionalForPrayer(date, prayer)) {
      await _plugin.cancel(id: id);
    }
  }

  @override
  Future<void> cancelAllForDay(DateTime date) async {
    for (final prayer in Prayer.values) {
      for (final id in NotificationIds.allForPrayer(date, prayer)) {
        await _plugin.cancel(id: id);
      }
    }
  }
}
