import '../tracker/sunnah.dart';

/// Completion rate per rawatib over a set of days (SRS FR-ST-04). A day
/// with no row for an item counts as not done, matching the tracker's
/// "absence means not logged/not done" convention.
class SunnahStats {
  const SunnahStats._();

  static Map<SunnahItem, double> completionRate({
    required List<DateTime> days,
    required List<SunnahLogEntry> entries,
  }) {
    final doneByDayAndItem = <(DateTime, SunnahItem), bool>{
      for (final e in entries)
        (DateTime(e.date.year, e.date.month, e.date.day), e.item): e.done,
    };

    return {
      for (final item in SunnahItem.values)
        item: days.isEmpty
            ? 0
            : days
                      .where(
                        (day) =>
                            doneByDayAndItem[(
                              DateTime(day.year, day.month, day.day),
                              item,
                            )] ==
                            true,
                      )
                      .length /
                  days.length,
    };
  }
}
