/// Rawatib tracked per day (SRS FR-SN-01).
enum SunnahItem {
  fajrBefore,
  dhuhrBefore,
  dhuhrAfter,
  maghribAfter,
  ishaAfter,
  witr,
}

/// Domain model mirroring one row of the `sunnah_log` table (SRS §2.4).
class SunnahLogEntry {
  final DateTime date;
  final SunnahItem item;
  final bool done;
  final DateTime loggedAt;

  const SunnahLogEntry({
    required this.date,
    required this.item,
    required this.done,
    required this.loggedAt,
  });
}
