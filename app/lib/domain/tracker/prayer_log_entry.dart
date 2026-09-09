import '../prayer_engine/prayer.dart';
import 'prayer_excuse.dart';
import 'prayer_status.dart';

/// Domain model mirroring one row of the `prayer_log` table (SRS §2.4).
class PrayerLogEntry {
  final String id;

  /// Local prayer date, 'YYYY-MM-DD' semantics (stored as [DateTime] here
  /// with time-of-day discarded).
  final DateTime date;
  final Prayer prayer;
  final PrayerStatus status;

  /// When the prayer was actually prayed; null if unknown (backfill).
  final DateTime? prayedAt;

  /// When this entry was written or last edited (FR-TR-04, FR-TR-05).
  final DateTime loggedAt;
  final LogSource source;
  final bool travelling;

  /// Name of the other prayer this one was combined with (FR-TR-06).
  final String? combinedWith;

  /// Why the prayer was `late`/`missed`, picked from a fixed set of
  /// reasons; meaningless (and left null) for `jamaah`/`onTimeAlone`.
  final PrayerExcuse? excuse;

  const PrayerLogEntry({
    required this.id,
    required this.date,
    required this.prayer,
    required this.status,
    this.prayedAt,
    required this.loggedAt,
    required this.source,
    this.travelling = false,
    this.combinedWith,
    this.excuse,
  });

  /// True when this entry was written on a later day than the prayer date
  /// (AC-TR-3).
  bool get isBackfilled => DateTime(
    loggedAt.year,
    loggedAt.month,
    loggedAt.day,
  ).isAfter(DateTime(date.year, date.month, date.day));

  /// [excuse] follows [status]/[prayedAt]'s "leave unchanged unless passed"
  /// convention; pass [clearExcuse] to explicitly drop it (e.g. the status
  /// changed away from `late`/`missed`), since a plain `excuse ?? this.excuse`
  /// could otherwise never clear it.
  PrayerLogEntry copyWith({
    PrayerStatus? status,
    DateTime? prayedAt,
    DateTime? loggedAt,
    LogSource? source,
    bool? travelling,
    String? combinedWith,
    PrayerExcuse? excuse,
    bool clearExcuse = false,
  }) {
    return PrayerLogEntry(
      id: id,
      date: date,
      prayer: prayer,
      status: status ?? this.status,
      prayedAt: prayedAt ?? this.prayedAt,
      loggedAt: loggedAt ?? this.loggedAt,
      source: source ?? this.source,
      travelling: travelling ?? this.travelling,
      combinedWith: combinedWith ?? this.combinedWith,
      excuse: clearExcuse ? null : (excuse ?? this.excuse),
    );
  }
}
