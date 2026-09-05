import 'package:adhan_dart/adhan_dart.dart' as adhan;

import '../../config/prayer_config.dart';
import 'prayer.dart';
import 'prayer_day.dart';

/// Computes [PrayerDay] for a given date and location, offline, using the
/// Adhan library (SRS FR-PT-01, FR-PT-02).
class PrayerTimeCalculator {
  final adhan.Coordinates coordinates;
  final adhan.CalculationParameters calculationParameters;

  /// Applies the Ramadan +30 minute Isha adjustment (SRS FR-PT-06, C7).
  final bool ramadanMode;

  PrayerTimeCalculator({
    required this.coordinates,
    adhan.CalculationParameters? calculationParameters,
    this.ramadanMode = false,
  }) : calculationParameters =
            calculationParameters ?? PrayerConfig.defaultCalculationParameters();

  PrayerDay computeForDate(DateTime date) {
    final params = calculationParameters.copyWith(
      adjustments: Map<adhan.Prayer, int>.from(calculationParameters.adjustments),
    );
    if (ramadanMode) {
      params.adjustments[adhan.Prayer.isha] =
          (params.adjustments[adhan.Prayer.isha] ?? 0) +
              PrayerConfig.ramadanIshaAdjustmentMinutes;
    }

    final times = adhan.PrayerTimes(
      date: DateTime(date.year, date.month, date.day),
      coordinates: coordinates,
      calculationParameters: params,
    );

    final maghribLocal = times.maghrib.toLocal();
    final nextFajrLocal = times.fajrAfter.toLocal();
    final islamicMidnight = maghribLocal.add(
      nextFajrLocal.difference(maghribLocal) ~/ 2,
    );

    return PrayerDay(
      date: DateTime(date.year, date.month, date.day),
      adhan: {
        Prayer.fajr: times.fajr.toLocal(),
        Prayer.dhuhr: times.dhuhr.toLocal(),
        Prayer.asr: times.asr.toLocal(),
        Prayer.maghrib: maghribLocal,
        Prayer.isha: times.isha.toLocal(),
      },
      sunrise: times.sunrise.toLocal(),
      islamicMidnight: islamicMidnight,
    );
  }
}
