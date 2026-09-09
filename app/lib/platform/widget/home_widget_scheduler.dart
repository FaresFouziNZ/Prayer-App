import 'dart:convert';
import 'dart:io' show Platform;

import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';

import '../../app/prayer_names.dart';
import '../../domain/prayer_engine/prayer.dart';
import '../../domain/schedule/prayer_event.dart';
import '../../domain/tracker/prayer_status.dart';
import '../../l10n/app_localizations.dart';

/// Android widget class name registered in `AndroidManifest.xml` (SRS FR-WD).
const String _androidWidgetProvider = 'PrayerWidgetProvider';

/// Feeds the Android home-screen widget (SRS FR-WD-01/02): writes the
/// upcoming events as JSON to shared storage and arms `home_widget`'s own
/// alarm-backed refresh at each one's adhan/iqamah/window-end boundary — the
/// three moments the widget's displayed content actually changes, mirroring
/// [PrayerEvent.phaseAt] (the closing phase doesn't change the countdown
/// target, only [NextPrayerCard]'s tint/label, which the widget's simpler
/// display doesn't have).
///
/// The countdown is a plain, static "1h 19m left" string, not a ticking
/// Chronometer — `RemoteViews.setChronometer`'s countDown mode displays a
/// "T-minus" style (negative until the target) rather than a positive
/// number counting down to zero, and a per-second-accurate positive
/// countdown isn't something a periodically-refreshed widget can show
/// anyway. The native `PrayerWidgetProvider` only *selects* which of the
/// three precomputed strings below applies (by comparing the raw
/// timestamps against `System.currentTimeMillis()`) — it never formats a
/// duration or touches l10n itself, consistent with `ScheduleBuilder` being
/// the one place event times are derived (SRS §2.1 design principle).
///
/// Two of the three are exact durations between two *known* timestamps
/// (`iqamahAt - adhanAt`, `endAt - iqamahAt`), not "now"-relative — they're
/// only ever displayed starting exactly when the alarm scheduled for the
/// earlier of the two fires, so they're never stale. Only the "before
/// adhan" string is computed against "now" (at write time), since it's
/// displayed immediately.
class HomeWidgetScheduler {
  const HomeWidgetScheduler._();

  /// [events] should already span the app's whole rolling window (today and
  /// tomorrow, matching [NotificationCoordinator]) so the widget has a
  /// "next" event to fall back on right up to the end of that window — a
  /// single call replaces the widget's entire schedule, so calling this
  /// once per day (rather than once for the combined window) would drop
  /// the other day's boundaries. `isJumuah` is carried per-event (not one
  /// flag for the whole batch) since today and tomorrow can straddle a
  /// Friday boundary.
  static Future<void> refresh({
    required List<({PrayerEvent event, bool isJumuah})> events,
    required Map<Prayer, PrayerStatus?> todayStatuses,
    required AppLocalizations l10n,
    required bool isArabicLocale,
  }) async {
    if (!Platform.isAndroid) return;

    final now = DateTime.now();
    final timeFormat = DateFormat.jm();
    final payloadEvents = events.map((e) {
      final beforeAdhanRemaining = e.event.adhanAt.difference(now);
      return {
        'name': PrayerNames.displayNameFor(
          l10n,
          isArabicLocale,
          e.event.prayer,
          isJumuah: e.isJumuah,
        ),
        // Pre-formatted (not just the raw time) so the native widget code
        // never needs its own locale-aware time formatting or l10n strings.
        'adhanLabel': l10n.adhanAtLabel(timeFormat.format(e.event.adhanAt)),
        'adhanAt': e.event.adhanAt.millisecondsSinceEpoch,
        'iqamahAt': e.event.iqamahAt.millisecondsSinceEpoch,
        'endAt': e.event.endAt.millisecondsSinceEpoch,
        'beforeAdhanText': _formatRemaining(
          l10n,
          beforeAdhanRemaining.isNegative
              ? Duration.zero
              : beforeAdhanRemaining,
        ),
        'iqamahPhaseText': _formatRemaining(
          l10n,
          e.event.iqamahAt.difference(e.event.adhanAt),
        ),
        'windowPhaseText': _formatRemaining(
          l10n,
          e.event.endAt.difference(e.event.iqamahAt),
        ),
      };
    }).toList();

    // FR-WD-03's five status dots: always exactly Fajr..Isha regardless of
    // which events are in the rolling window, so this is its own top-level
    // field rather than folded into a per-event payload.
    final todayStatus = [
      for (final prayer in Prayer.values) todayStatuses[prayer]?.name,
    ];

    await HomeWidget.saveWidgetData<String>(
      'events',
      jsonEncode(payloadEvents),
    );
    await HomeWidget.saveWidgetData<String>(
      'todayStatus',
      jsonEncode(todayStatus),
    );
    await HomeWidget.updateWidget(androidName: _androidWidgetProvider);

    final boundaries = <DateTime>[];
    for (final e in events) {
      for (final at in [e.event.adhanAt, e.event.iqamahAt, e.event.endAt]) {
        if (at.isAfter(now)) boundaries.add(at);
      }
    }
    boundaries.sort();
    await HomeWidget.scheduleWidgetUpdates(
      boundaries,
      androidName: _androidWidgetProvider,
    );
  }

  static String _formatRemaining(AppLocalizations l10n, Duration remaining) {
    final totalMinutes = remaining.inMinutes;
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (hours > 0) {
      return l10n.widgetTimeLeftHoursMinutes(hours, minutes);
    }
    return l10n.widgetTimeLeftMinutes(minutes);
  }
}
