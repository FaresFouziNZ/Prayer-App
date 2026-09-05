import '../prayer_engine/prayer.dart';

/// One row per prayer per day, consumed by every surface: notifications,
/// widget, Live Activity content state, Android live notification, and the
/// published Firestore schedule (SRS §2.3). Nothing else derives times
/// independently.
class PrayerEvent {
  final Prayer prayer;
  final DateTime date;
  final DateTime preAdhanAt;
  final DateTime adhanAt;
  final DateTime iqamahAt;
  final DateTime leaveByAt;
  final DateTime closingAt;
  final DateTime endAt;

  const PrayerEvent({
    required this.prayer,
    required this.date,
    required this.preAdhanAt,
    required this.adhanAt,
    required this.iqamahAt,
    required this.leaveByAt,
    required this.closingAt,
    required this.endAt,
  });

  /// The live-surface phase for [at] (defaults to now). See SRS FR-LA-01.
  LivePhase phaseAt(DateTime at) {
    if (at.isBefore(iqamahAt)) return LivePhase.iqamah;
    if (at.isBefore(closingAt)) return LivePhase.window;
    return LivePhase.closing;
  }
}

enum LivePhase { iqamah, window, closing }
