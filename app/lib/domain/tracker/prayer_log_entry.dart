import '../prayer_engine/prayer.dart';
import 'prayer_status.dart';

/// Sentinel distinguishing "leave [PrayerLogEntry.note] unchanged" from
/// "set it to null" in [PrayerLogEntry.copyWith] and [TrackerRules.edit] —
/// a plain `note ?? this.note` could never clear an existing note.
const Object unsetPrayerLogNote = Object();

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
  final String? note;

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
    this.note,
  });

  /// True when this entry was written on a later day than the prayer date
  /// (AC-TR-3).
  bool get isBackfilled =>
      DateTime(loggedAt.year, loggedAt.month, loggedAt.day)
          .isAfter(DateTime(date.year, date.month, date.day));

  /// [note] defaults to "leave unchanged"; pass `null` explicitly to clear
  /// it, since a plain `note ?? this.note` could otherwise never do so.
  PrayerLogEntry copyWith({
    PrayerStatus? status,
    DateTime? prayedAt,
    DateTime? loggedAt,
    LogSource? source,
    bool? travelling,
    String? combinedWith,
    Object? note = unsetPrayerLogNote,
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
      note: identical(note, unsetPrayerLogNote) ? this.note : note as String?,
    );
  }
}
