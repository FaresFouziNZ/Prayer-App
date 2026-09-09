import '../prayer_engine/prayer.dart';
import '../tracker/prayer_log_entry.dart';
import '../tracker/prayer_status.dart';

class StreakResult {
  final int current;
  final int best;

  const StreakResult({required this.current, required this.best});
}

/// Streak rule (SRS §2.4 / FR-ST-03, revised 2026-09-07): consecutive
/// individual *prayers*, not consecutive full days. Walks every prayer slot
/// across [days] in chronological order (day, then Fajr..Isha within the
/// day); `jamaah`/`on_time_alone` extend the run, `missed` breaks it, and
/// both an unlogged prayer and a `late` one are neutral — a late prayer was
/// still prayed (so it shouldn't reset the streak, unlike `missed`), but it
/// wasn't on time either (so it shouldn't count as a positive streak entry
/// alongside jama'ah/on-time). Absence of a record is likewise never treated
/// as missed, same as everywhere else in the app (AC-TR-2).
///
/// That neutrality is also what makes a period-exempt day work correctly
/// without this needing to know about period tracking at all: pass the
/// *unfiltered* day range (not pre-filtered by excluded/period days, unlike
/// the other Stats computations). Prayers already logged before a period
/// began that day still count as usual; everything after it has no record
/// (the UI hides further logging for the day) and is simply skipped rather
/// than breaking the streak.
class Streak {
  const Streak._();

  static StreakResult compute({
    required List<DateTime> days,
    required List<PrayerLogEntry> logs,
  }) {
    final byDay = <DateTime, Map<Prayer, PrayerStatus>>{};
    for (final log in logs) {
      final day = DateTime(log.date.year, log.date.month, log.date.day);
      (byDay[day] ??= {})[log.prayer] = log.status;
    }

    var running = 0;
    var best = 0;
    final sortedDays = [...days]..sort();

    for (final day in sortedDays) {
      final normalizedDay = DateTime(day.year, day.month, day.day);
      final statuses = byDay[normalizedDay];
      if (statuses == null) continue;
      for (final prayer in Prayer.values) {
        final status = statuses[prayer];
        // Not logged, or logged late — neutral, streak holds either way.
        if (status == null || status == PrayerStatus.late) continue;
        if (status == PrayerStatus.missed) {
          running = 0;
        } else {
          running += 1;
          if (running > best) best = running;
        }
      }
    }

    return StreakResult(current: running, best: best);
  }
}
