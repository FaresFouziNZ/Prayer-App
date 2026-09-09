import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/prayer_engine/prayer.dart';
import '../../domain/tracker/prayer_excuse.dart';
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
    required bool isFriday,
    required PrayerLogEntry? existing,
    PrayerExcuse? excuse,
  }) async {
    final needsExcuse =
        status == PrayerStatus.late || status == PrayerStatus.missed;
    final entry = existing == null
        ? TrackerRules.buildEntry(
            prayer: prayer,
            date: date,
            status: status,
            isFriday: isFriday,
            source: LogSource.manual,
            prayedAt: DateTime.now(),
            excuse: needsExcuse ? excuse : null,
          )
        : TrackerRules.edit(
            existing,
            status: status,
            excuse: excuse,
            clearExcuse: !needsExcuse,
          );
    await ref.read(prayerLogRepositoryProvider).upsert(entry);
    // The closing reminder and end-of-window prompt are conditional on the
    // prayer still being unlogged (FR-NT-05, FR-NT-06); cancel them now
    // that it's logged. The live countdown notification (FR-LA-07) is
    // conditional the same way but lives in a separate scheduler, since its
    // early phases are posted by native alarms outside
    // flutter_local_notifications entirely.
    await ref.read(notificationSchedulerProvider).cancelForPrayer(date, prayer);
    await ref
        .read(liveNotificationSchedulerProvider)
        .cancelForPrayer(date, prayer);
  }

  /// Deletes [entry]. Combined prayers (FR-TR-06) are logged as a pair
  /// sharing one `prayedAt`, so deleting one also deletes its partner —
  /// otherwise the remaining row would be left pointing at a `combinedWith`
  /// prayer that no longer has a record of its own.
  static Future<void> delete(WidgetRef ref, PrayerLogEntry entry) async {
    final repo = ref.read(prayerLogRepositoryProvider);
    await repo.delete(entry.id);
    if (entry.combinedWith != null) {
      final partner = Prayer.values.firstWhere(
        (p) => p.name == entry.combinedWith,
      );
      final partnerEntry = await repo.getForDate(entry.date, partner);
      if (partnerEntry != null) await repo.delete(partnerEntry.id);
    }
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
    final liveScheduler = ref.read(liveNotificationSchedulerProvider);
    await liveScheduler.cancelForPrayer(date, first);
    await liveScheduler.cancelForPrayer(date, second);
  }
}
