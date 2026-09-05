import '../tracker/prayer_log_entry.dart';
import '../tracker/prayer_status.dart';

class StreakResult {
  final int current;
  final int best;

  const StreakResult({required this.current, required this.best});
}

/// Streak rule (SRS §2.4 / FR-ST-03): a day counts toward the streak only if
/// it has five logged prayers and none is `missed`. A day with fewer than
/// five rows is neutral — it neither extends nor breaks the streak
/// (AC-ST-2). Any `missed` record breaks the streak regardless of how many
/// other prayers were logged that day.
class Streak {
  const Streak._();

  static StreakResult compute({
    required List<DateTime> days,
    required List<PrayerLogEntry> logs,
  }) {
    final byDay = <DateTime, List<PrayerLogEntry>>{};
    for (final log in logs) {
      final day = DateTime(log.date.year, log.date.month, log.date.day);
      (byDay[day] ??= []).add(log);
    }

    var running = 0;
    var best = 0;
    final sortedDays = [...days]..sort();

    for (final day in sortedDays) {
      final normalizedDay = DateTime(day.year, day.month, day.day);
      final entries = byDay[normalizedDay] ?? const <PrayerLogEntry>[];
      final hasMissed = entries.any((e) => e.status == PrayerStatus.missed);

      if (hasMissed) {
        running = 0;
      } else if (entries.length >= 5) {
        running += 1;
        if (running > best) best = running;
      }
      // else: fewer than 5 logged, none missed — neutral day, streak holds.
    }

    return StreakResult(current: running, best: best);
  }
}
