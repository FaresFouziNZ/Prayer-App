import '../../domain/prayer_engine/prayer.dart';

/// The four notification moments per prayer (SRS §2.6): pre-adhan is
/// optional, closing and the end prompt are conditional on the prayer still
/// being unlogged.
enum NotificationKind { preAdhan, adhan, closing, endPrompt }

/// Deterministic, collision-free platform notification IDs, so the same
/// (date, prayer, kind) always maps to the same ID — required to cancel or
/// replace a specific scheduled notification later (e.g. when a prayer is
/// logged, FR-NT-05/06) without keeping a separate lookup table.
class NotificationIds {
  const NotificationIds._();

  static int _epochDay(DateTime date) =>
      DateTime(date.year, date.month, date.day).difference(DateTime(1970)).inDays;

  static int _prayerIndex(Prayer prayer) => Prayer.values.indexOf(prayer);

  /// Fits comfortably in a 32-bit int for centuries: epochDay * 100 leaves
  /// two decimal digits for prayerIndex (0-4) * 10 + kind (0-3), max 43.
  static int forEvent(DateTime date, Prayer prayer, NotificationKind kind) {
    return _epochDay(date) * 100 + _prayerIndex(prayer) * 10 + kind.index;
  }

  /// All IDs for one prayer on one day, e.g. to cancel every notification
  /// tied to it at once.
  static List<int> allForPrayer(DateTime date, Prayer prayer) {
    return NotificationKind.values.map((k) => forEvent(date, prayer, k)).toList();
  }

  /// Just the conditional ones (closing, end prompt), cancelled once the
  /// prayer is logged (FR-NT-05, FR-NT-06) while pre-adhan/adhan — which
  /// fire before logging is even possible — are left alone.
  static List<int> conditionalForPrayer(DateTime date, Prayer prayer) {
    return [
      forEvent(date, prayer, NotificationKind.closing),
      forEvent(date, prayer, NotificationKind.endPrompt),
    ];
  }
}
