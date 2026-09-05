import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/prayer_engine/prayer.dart';
import '../../domain/tracker/prayer_log_entry.dart';
import '../../domain/tracker/prayer_status.dart';
import '../../domain/tracker/tracker_rules.dart';

/// Shared log/delete actions behind [TodayPrayerList], used by both the
/// home screen (today) and the history day-detail screen (backfill).
class PrayerLogActions {
  const PrayerLogActions._();

  static Future<void> save(
    WidgetRef ref, {
    required DateTime date,
    required Prayer prayer,
    required PrayerStatus status,
    required String? note,
    required bool isFriday,
    required PrayerLogEntry? existing,
  }) async {
    final entry = existing == null
        ? TrackerRules.buildEntry(
            prayer: prayer,
            date: date,
            status: status,
            isFriday: isFriday,
            source: LogSource.manual,
            prayedAt: DateTime.now(),
            note: note,
          )
        : TrackerRules.edit(existing, status: status, note: note);
    await ref.read(prayerLogRepositoryProvider).upsert(entry);
    // The closing reminder and end-of-window prompt are conditional on the
    // prayer still being unlogged (FR-NT-05, FR-NT-06); cancel them now
    // that it's logged.
    await ref.read(notificationSchedulerProvider).cancelForPrayer(date, prayer);
  }

  static Future<void> delete(WidgetRef ref, PrayerLogEntry entry) {
    return ref.read(prayerLogRepositoryProvider).delete(entry.id);
  }

  /// Combines two adjacent prayers when travelling (FR-TR-06).
  static Future<void> combine(
    WidgetRef ref, {
    required DateTime date,
    required Prayer first,
    required Prayer second,
    required PrayerStatus status,
  }) async {
    final (firstEntry, secondEntry) = TrackerRules.buildCombinedEntries(
      first: first,
      second: second,
      date: date,
      status: status,
      source: LogSource.manual,
    );
    final repo = ref.read(prayerLogRepositoryProvider);
    await repo.upsert(firstEntry);
    await repo.upsert(secondEntry);
    final scheduler = ref.read(notificationSchedulerProvider);
    await scheduler.cancelForPrayer(date, first);
    await scheduler.cancelForPrayer(date, second);
  }
}
