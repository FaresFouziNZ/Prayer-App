import 'package:uuid/uuid.dart';

import '../prayer_engine/prayer.dart';
import 'prayer_log_entry.dart';
import 'prayer_status.dart';

/// Pure logging rules (SRS §2.5). No I/O — callers persist the resulting
/// entries.
class TrackerRules {
  const TrackerRules._();

  static const Uuid _uuid = Uuid();

  /// Friday's Dhuhr logged as prayed is always `jamaah` (FR-TR-07).
  static PrayerStatus applyJumuahRule({
    required Prayer prayer,
    required bool isFriday,
    required PrayerStatus requestedStatus,
  }) {
    final isPrayedStatus = requestedStatus == PrayerStatus.jamaah ||
        requestedStatus == PrayerStatus.onTimeAlone;
    if (isFriday && prayer == Prayer.dhuhr && isPrayedStatus) {
      return PrayerStatus.jamaah;
    }
    return requestedStatus;
  }

  /// True once [windowEnd] has passed relative to [now]; the UI defaults the
  /// logging button to "Prayed late" in this case, but the user may still
  /// explicitly choose `missed`.
  static bool windowHasClosed(DateTime windowEnd, DateTime now) =>
      now.isAfter(windowEnd);

  /// Builds a new log entry for logging within (or after) the window.
  static PrayerLogEntry buildEntry({
    required Prayer prayer,
    required DateTime date,
    required PrayerStatus status,
    required bool isFriday,
    required LogSource source,
    DateTime? prayedAt,
    DateTime? now,
    bool travelling = false,
    String? combinedWith,
    String? note,
  }) {
    final effectiveNow = now ?? DateTime.now();
    return PrayerLogEntry(
      id: _uuid.v4(),
      date: DateTime(date.year, date.month, date.day),
      prayer: prayer,
      status: applyJumuahRule(
        prayer: prayer,
        isFriday: isFriday,
        requestedStatus: status,
      ),
      prayedAt: prayedAt,
      loggedAt: effectiveNow,
      source: source,
      travelling: travelling,
      combinedWith: combinedWith,
      note: note,
    );
  }

  /// The prayer [prayer] may be combined with when travelling (jam' taqdim
  /// pairs), or null if it has none. Only Dhuhr+Asr and Maghrib+Isha may be
  /// combined (FR-TR-06).
  static Prayer? combinablePartner(Prayer prayer) {
    switch (prayer) {
      case Prayer.dhuhr:
        return Prayer.asr;
      case Prayer.maghrib:
        return Prayer.isha;
      default:
        return null;
    }
  }

  /// Travelling and combining (FR-TR-06): logging one of a pair of prayers
  /// offers "combined with X" and writes two rows sharing `prayedAt`, both
  /// on time, each pointing at the other via `combinedWith`.
  static (PrayerLogEntry, PrayerLogEntry) buildCombinedEntries({
    required Prayer first,
    required Prayer second,
    required DateTime date,
    required PrayerStatus status,
    required LogSource source,
    DateTime? prayedAt,
    DateTime? now,
  }) {
    assert(
      status == PrayerStatus.jamaah || status == PrayerStatus.onTimeAlone,
      'Combined prayers are always logged as on time (jamaah or alone).',
    );
    final effectiveNow = now ?? DateTime.now();
    final effectivePrayedAt = prayedAt ?? effectiveNow;
    final firstEntry = PrayerLogEntry(
      id: _uuid.v4(),
      date: DateTime(date.year, date.month, date.day),
      prayer: first,
      status: status,
      prayedAt: effectivePrayedAt,
      loggedAt: effectiveNow,
      source: source,
      travelling: true,
      combinedWith: second.name,
    );
    final secondEntry = PrayerLogEntry(
      id: _uuid.v4(),
      date: DateTime(date.year, date.month, date.day),
      prayer: second,
      status: status,
      prayedAt: effectivePrayedAt,
      loggedAt: effectiveNow,
      source: source,
      travelling: true,
      combinedWith: first.name,
    );
    return (firstEntry, secondEntry);
  }

  /// Edits update status/prayedAt/note and bump `loggedAt` (FR-TR-05). A
  /// changed status still goes through the Jumu'ah rule (FR-TR-07). [note]
  /// defaults to "leave unchanged"; pass `null` explicitly to clear it.
  static PrayerLogEntry edit(
    PrayerLogEntry entry, {
    PrayerStatus? status,
    DateTime? prayedAt,
    Object? note = unsetPrayerLogNote,
    DateTime? now,
  }) {
    final resolvedStatus = status == null
        ? null
        : applyJumuahRule(
            prayer: entry.prayer,
            isFriday: entry.date.weekday == DateTime.friday,
            requestedStatus: status,
          );
    return entry.copyWith(
      status: resolvedStatus,
      prayedAt: prayedAt,
      note: note,
      loggedAt: now ?? DateTime.now(),
    );
  }
}
