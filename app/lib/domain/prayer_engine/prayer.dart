/// The five obligatory daily prayers. `dhuhr` renders as Jumu'ah on Friday
/// (see FR-PT-05) but is not a distinct enum value.
enum Prayer { fajr, dhuhr, asr, maghrib, isha }

extension PrayerOrder on Prayer {
  /// Position in the daily sequence, used for sorting and "next prayer" logic.
  int get order => Prayer.values.indexOf(this);
}
