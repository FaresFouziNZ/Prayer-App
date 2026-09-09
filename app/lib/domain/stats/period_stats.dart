import '../prayer_engine/prayer.dart';
import '../tracker/prayer_log_entry.dart';
import '../tracker/prayer_status.dart';

/// Aggregate metrics for a period (SRS FR-ST-01). Not-logged prayers are
/// excluded from rate denominators and shown separately (FR-ST-05).
class PeriodMetrics {
  final int jamaahCount;
  final int onTimeAloneCount;
  final int lateCount;
  final int missedCount;
  final int notLoggedCount;

  const PeriodMetrics({
    required this.jamaahCount,
    required this.onTimeAloneCount,
    required this.lateCount,
    required this.missedCount,
    required this.notLoggedCount,
  });

  int get loggedCount =>
      jamaahCount + onTimeAloneCount + lateCount + missedCount;

  double get jamaahRate => loggedCount == 0 ? 0 : jamaahCount / loggedCount;

  double get onTimeRate =>
      loggedCount == 0 ? 0 : (jamaahCount + onTimeAloneCount) / loggedCount;
}

/// Computes [PeriodMetrics] over a set of calendar days and the log entries
/// that fall within them.
class PeriodStats {
  const PeriodStats._();

  static PeriodMetrics compute({
    required List<DateTime> days,
    required List<PrayerLogEntry> logs,
    Prayer? onlyPrayer,
  }) {
    final byDayAndPrayer = <(DateTime, Prayer), PrayerLogEntry>{
      for (final log in logs)
        (DateTime(log.date.year, log.date.month, log.date.day), log.prayer):
            log,
    };

    var jamaah = 0, onTimeAlone = 0, late = 0, missed = 0, notLogged = 0;
    final prayers = onlyPrayer != null ? [onlyPrayer] : Prayer.values;

    for (final day in days) {
      final normalizedDay = DateTime(day.year, day.month, day.day);
      for (final prayer in prayers) {
        final entry = byDayAndPrayer[(normalizedDay, prayer)];
        if (entry == null) {
          notLogged++;
          continue;
        }
        switch (entry.status) {
          case PrayerStatus.jamaah:
            jamaah++;
          case PrayerStatus.onTimeAlone:
            onTimeAlone++;
          case PrayerStatus.late:
            late++;
          case PrayerStatus.missed:
            missed++;
        }
      }
    }

    return PeriodMetrics(
      jamaahCount: jamaah,
      onTimeAloneCount: onTimeAlone,
      lateCount: late,
      missedCount: missed,
      notLoggedCount: notLogged,
    );
  }

  /// Per-prayer breakdown of the same metrics (FR-ST-02).
  static Map<Prayer, PeriodMetrics> computePerPrayer({
    required List<DateTime> days,
    required List<PrayerLogEntry> logs,
  }) {
    return {
      for (final prayer in Prayer.values)
        prayer: compute(days: days, logs: logs, onlyPrayer: prayer),
    };
  }
}
