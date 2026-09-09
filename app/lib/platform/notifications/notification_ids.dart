import '../../domain/prayer_engine/prayer.dart';
import '../../domain/tracker/sunnah.dart';

/// The notification moments per prayer (SRS §2.6): pre-adhan is optional,
/// closing and the end prompt are conditional on the prayer still being
/// unlogged. [live] is the Android live-countdown notification (FR-LA-07) —
/// its id is shared across all three of its phases (native live-start post,
/// native iqamah-phase post, and the Dart-scheduled closing-phase post) so
/// each one replaces the last; [liveIqamah] exists only as a second,
/// distinct alarm request code for that surface's native iqamah-phase
/// alarm, since it must not overwrite the still-pending live-start alarm by
/// sharing its id (see live_notification_scheduler.dart). [liveDismiss] is a
/// third, distinct alarm request code for a native alarm at window end that
/// force-dismisses [live] — a safety net independent of whichever phase
/// happens to currently own that notification id, since only the
/// Dart-scheduled closing phase carries its own expiry (`timeoutAfter`) and
/// that alarm can itself be missed (doze, an OEM killing the exact alarm).
enum NotificationKind {
  preAdhan,
  adhan,
  closing,
  endPrompt,
  live,
  liveIqamah,
  liveDismiss,
}

/// Deterministic, collision-free platform notification IDs, so the same
/// (date, prayer, kind) always maps to the same ID — required to cancel or
/// replace a specific scheduled notification later (e.g. when a prayer is
/// logged, FR-NT-05/06) without keeping a separate lookup table.
class NotificationIds {
  const NotificationIds._();

  static int _epochDay(DateTime date) => DateTime(
    date.year,
    date.month,
    date.day,
  ).difference(DateTime(1970)).inDays;

  static int _prayerIndex(Prayer prayer) => Prayer.values.indexOf(prayer);

  /// Fits comfortably in a 32-bit int for centuries: epochDay * 100 leaves
  /// two decimal digits for prayerIndex (0-4) * 10 + kind (0-6), max 46.
  static int forEvent(DateTime date, Prayer prayer, NotificationKind kind) {
    return _epochDay(date) * 100 + _prayerIndex(prayer) * 10 + kind.index;
  }

  /// All IDs for one prayer on one day, e.g. to cancel every notification
  /// tied to it at once.
  static List<int> allForPrayer(DateTime date, Prayer prayer) {
    return NotificationKind.values
        .map((k) => forEvent(date, prayer, k))
        .toList();
  }

  /// Just the conditional ones (closing, end prompt, live surface),
  /// cancelled once the prayer is logged (FR-NT-05, FR-NT-06, FR-LA-07)
  /// while pre-adhan/adhan — which fire before logging is even possible —
  /// are left alone.
  static List<int> conditionalForPrayer(DateTime date, Prayer prayer) {
    return [
      forEvent(date, prayer, NotificationKind.closing),
      forEvent(date, prayer, NotificationKind.endPrompt),
      forEvent(date, prayer, NotificationKind.live),
    ];
  }

  /// Rawatib reminder IDs (SRS FR-SN) — a separate scheme from [forEvent]'s,
  /// since a sunnah item isn't a (prayer, kind) pair. Offset by 90 so the
  /// two schemes can never collide within the same day ([forEvent] only
  /// ever reaches `prayerIndex(4) * 10 + kind(5) = 45`).
  static int forSunnahItem(DateTime date, SunnahItem item) {
    return _epochDay(date) * 100 + 90 + SunnahItem.values.indexOf(item);
  }

  static List<int> allSunnahForDay(DateTime date) {
    return SunnahItem.values.map((item) => forSunnahItem(date, item)).toList();
  }
}
