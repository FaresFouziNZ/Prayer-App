import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../app/prayer_names.dart';
import '../../config/prayer_config.dart';
import '../../domain/prayer_engine/prayer.dart';
import '../../domain/schedule/prayer_event.dart';
import '../../l10n/app_localizations.dart';
import '../notifications/notification_action_ids.dart';
import '../notifications/notification_ids.dart';
import '../notifications/notification_payload.dart';
import '../notifications/notification_scheduler.dart';

const String _liveChannelId = 'live';
const String _liveChannelName = 'Live countdown';
const MethodChannel _liveMethodChannel = MethodChannel('live_notification');

/// Android's live countdown surface (SRS FR-LA-01, FR-LA-07) — the
/// Android-side equivalent of iOS's Live Activity. Three phases, one
/// notification id per prayer, each phase replacing the last on screen:
///
/// 1. Live start (adhan + [PrayerConfig.liveStartGraceMinutes]): counts down
///    to Iqamah. Posted by a native exact alarm targeting
///    `LiveNotificationReceiver` directly, bypassing
///    `flutter_local_notifications`' own scheduling — its `zonedSchedule`
///    ties one notification id to exactly one future alarm, so scheduling
///    the iqamah-phase update ahead of time under the *same* id would
///    silently overwrite this alarm before it ever fires.
/// 2. Iqamah: counts down to window end. Same native path, a second,
///    independently-keyed alarm (so it doesn't overwrite #1's still-pending
///    alarm), but posts to the *same displayed* notification id.
/// 3. Closing (the closing-offset before window end, SRS FR-NT-05's
///    setting): counts down to window end with the same Jama'ah/Alone/Not
///    yet actions as the end-of-window prompt (FR-NT-06). Scheduled the
///    ordinary way through `flutter_local_notifications`, reusing its
///    already-correct background-isolate action handling — interactive
///    notifications need no native code at all. `timeoutAfter` is meant to
///    auto-cancel it exactly at window end, but that alarm can itself be
///    missed (doze, an OEM killing an exact alarm) — a fourth, native alarm
///    at `endAt` (`NotificationKind.liveDismiss`) force-dismisses the
///    notification outright as a safety net independent of phase 3 ever
///    firing correctly.
///
/// Reuses [NotificationScheduler]'s shape so [NotificationCoordinator] can
/// drive both the same way, and depends on it having already called
/// `initialize()` first — this class posts through the same plugin but
/// doesn't redo the (process-global) timezone-data setup itself.
abstract class LiveNotificationScheduler {
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

/// No-op everywhere but Android — iOS's live surface (FR-LA-02..06) is a
/// server-pushed ActivityKit Live Activity, a fundamentally different
/// mechanism not implemented in this pass.
class UnimplementedLiveNotificationScheduler
    implements LiveNotificationScheduler {
  const UnimplementedLiveNotificationScheduler();

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

class AndroidLiveNotificationScheduler implements LiveNotificationScheduler {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _channelCreated = false;

  @override
  Future<void> initialize() async {
    if (_channelCreated) return;
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _liveChannelId,
        _liveChannelName,
        description: 'Ongoing countdown to Iqamah and window close',
        importance: Importance.low,
        playSound: false,
      ),
    );
    _channelCreated = true;
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
      final name = PrayerNames.displayNameFor(
        l10n,
        isArabicLocale,
        event.prayer,
        isJumuah: isJumuah,
      );
      final liveId = NotificationIds.forEvent(
        event.date,
        event.prayer,
        NotificationKind.live,
      );
      final iqamahRequestCode = NotificationIds.forEvent(
        event.date,
        event.prayer,
        NotificationKind.liveIqamah,
      );
      final dismissRequestCode = NotificationIds.forEvent(
        event.date,
        event.prayer,
        NotificationKind.liveDismiss,
      );
      final liveStartAt = event.adhanAt.add(
        const Duration(minutes: PrayerConfig.liveStartGraceMinutes),
      );

      await _scheduleNativePhase(
        requestCode: liveId,
        notifyId: liveId,
        at: liveStartAt,
        // Phase 1 is superseded by phase 2 once iqamah arrives.
        mootAt: event.iqamahAt,
        now: now,
        title: name,
        text: l10n.liveIqamahCountdownBody(name),
        countdownTarget: event.iqamahAt,
      );
      await _scheduleNativePhase(
        requestCode: iqamahRequestCode,
        notifyId: liveId,
        at: event.iqamahAt,
        // Phase 2 is superseded by phase 3 (closing) once that starts.
        mootAt: event.closingAt,
        now: now,
        title: name,
        text: l10n.liveWindowCountdownBody(name),
        countdownTarget: event.endAt,
      );

      final payload = NotificationPayload(
        date: event.date,
        prayer: event.prayer,
      ).encode();
      if (!event.endAt.isAfter(now)) {
        await _plugin.cancel(id: liveId);
        await _liveMethodChannel.invokeMethod<void>('cancel', {
          'requestCodes': [dismissRequestCode],
          'notifyId': liveId,
        });
      } else {
        // If this device wasn't running (app closed, or just reinstalled)
        // when `closingAt` itself arrived, `zonedSchedule` would silently
        // never fire since it only arms a *future* trigger — catch up by
        // posting immediately instead whenever `closingAt` has already
        // passed but the window itself (`endAt`) hasn't. `timeoutAfter` is
        // measured from *now*, not from `closingAt`, so a late catch-up
        // post still clears itself out exactly at the real window end.
        final alreadyClosing = event.closingAt.isBefore(now);
        final details = NotificationDetails(
          android: AndroidNotificationDetails(
            _liveChannelId,
            _liveChannelName,
            importance: Importance.low,
            priority: Priority.low,
            silent: true,
            ongoing: true,
            onlyAlertOnce: true,
            autoCancel: false,
            showWhen: true,
            when: event.endAt.millisecondsSinceEpoch,
            usesChronometer: true,
            chronometerCountDown: true,
            timeoutAfter: event.endAt
                .difference(alreadyClosing ? now : event.closingAt)
                .inMilliseconds,
            actions: const [
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
            ],
          ),
        );
        if (alreadyClosing) {
          await _plugin.show(
            id: liveId,
            title: name,
            body: l10n.liveClosingBody(name),
            notificationDetails: details,
            payload: payload,
          );
        } else {
          await _plugin.zonedSchedule(
            id: liveId,
            scheduledDate: tz.TZDateTime.from(event.closingAt, tz.local),
            title: name,
            body: l10n.liveClosingBody(name),
            notificationDetails: details,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            payload: payload,
          );
        }
        // Safety net independent of the closing-phase notification's own
        // `timeoutAfter` above: a native alarm at `endAt` that force-dismisses
        // the notification outright. Without this, a missed closing-phase
        // alarm (doze, an OEM killing the exact alarm) leaves the still-live
        // iqamah-phase notification on screen forever, its chronometer
        // counting past zero into negative time.
        await _liveMethodChannel.invokeMethod<void>('scheduleDismiss', {
          'requestCode': dismissRequestCode,
          'triggerAtMillis': event.endAt.millisecondsSinceEpoch,
          'notifyId': liveId,
        });
      }
    }
  }

  /// Arms one of the two native-alarm phases, or cancels it once [mootAt]
  /// has passed (a later phase now applies instead). [at] itself is allowed
  /// to already be in the past: `AlarmManager` fires an overdue exact alarm
  /// immediately rather than dropping it, which is exactly what's wanted
  /// when the app opens (or a settings change re-schedules) in the middle
  /// of a phase that should already be showing — without this, a phase
  /// whose *start* had already passed by schedule time never got armed at
  /// all, silently going missing for anyone who wasn't already looking at
  /// the notification when it should have first appeared.
  Future<void> _scheduleNativePhase({
    required int requestCode,
    required int notifyId,
    required DateTime at,
    required DateTime mootAt,
    required DateTime now,
    required String title,
    required String text,
    required DateTime countdownTarget,
  }) async {
    if (!mootAt.isAfter(now)) {
      await _liveMethodChannel.invokeMethod<void>('cancel', {
        'requestCodes': [requestCode],
        'notifyId': notifyId,
      });
      return;
    }
    await _liveMethodChannel.invokeMethod<void>('schedule', {
      'requestCode': requestCode,
      'triggerAtMillis': at.millisecondsSinceEpoch,
      'notifyId': notifyId,
      'title': title,
      'text': text,
      'whenMillis': countdownTarget.millisecondsSinceEpoch,
      'countDown': true,
    });
  }

  @override
  Future<void> cancelForPrayer(DateTime date, Prayer prayer) async {
    final liveId = NotificationIds.forEvent(
      date,
      prayer,
      NotificationKind.live,
    );
    final iqamahRequestCode = NotificationIds.forEvent(
      date,
      prayer,
      NotificationKind.liveIqamah,
    );
    final dismissRequestCode = NotificationIds.forEvent(
      date,
      prayer,
      NotificationKind.liveDismiss,
    );
    await _liveMethodChannel.invokeMethod<void>('cancel', {
      'requestCodes': [liveId, iqamahRequestCode, dismissRequestCode],
      'notifyId': liveId,
    });
    await _plugin.cancel(id: liveId);
  }

  @override
  Future<void> cancelAllForDay(DateTime date) async {
    for (final prayer in Prayer.values) {
      await cancelForPrayer(date, prayer);
    }
  }
}
