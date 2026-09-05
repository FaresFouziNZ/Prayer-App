import 'package:adhan_dart/adhan_dart.dart' as adhan;

import '../domain/prayer_engine/prayer.dart';

/// Single source of truth for calculation parameters and iqamah defaults.
///
/// SRS NFR-09: prayer-time parameters, iqamah defaults, and window-end rules
/// live in one configuration module shared by every consumer (app, widget,
/// notifications, backend parity tests).
class PrayerConfig {
  const PrayerConfig._();

  /// Default calculation method (SRS A1): Umm al-Qura, Shafi madhab.
  static adhan.CalculationParameters defaultCalculationParameters() {
    final params = adhan.CalculationMethodParameters.ummAlQura();
    params.madhab = adhan.Madhab.shafi;
    return params;
  }

  /// SRS C7: Umm al-Qura requires a +30 minute Isha adjustment during
  /// Ramadan, applied by the app, not the library.
  static const int ramadanIshaAdjustmentMinutes = 30;

  /// Default iqamah offsets in minutes after adhan (SRS FR-IQ-02).
  /// Marked "to be confirmed" against the current Ministry circular (O1).
  static const Map<Prayer, int> normalIqamahOffsets = {
    Prayer.fajr: 25,
    Prayer.dhuhr: 20,
    Prayer.asr: 20,
    Prayer.maghrib: 10,
    Prayer.isha: 15,
  };

  static const Map<Prayer, int> ramadanIqamahOffsets = {
    Prayer.fajr: 20,
    Prayer.dhuhr: 15,
    Prayer.asr: 15,
    Prayer.maghrib: 10,
    Prayer.isha: 15,
  };

  /// Default leave-by settings (SRS FR-IQ-04).
  static const int defaultTravelMinutes = 10;
  static const int defaultBufferMinutes = 5;

  /// Default window-closing reminder offset (SRS FR-NT-05, open item O5).
  static const int defaultClosingOffsetMinutes = 30;

  /// Default pre-adhan reminder offset (SRS FR-NT-03).
  static const int defaultPreAdhanOffsetMinutes = 10;

  /// Imsak isn't computed by the Adhan library and the SRS doesn't define
  /// an exact formula (FR-RM-02); shown as this many minutes before Fajr,
  /// the common convention among prayer apps.
  static const int imsakBeforeFajrMinutes = 10;
}
