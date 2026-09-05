import '../prayer_engine/prayer.dart';

/// A qada plan: a target payment rate and the projected clearance date for
/// one prayer's balance (SRS FR-QD-04).
class QadaPlan {
  final Prayer prayer;
  final int currentBalance;
  final int targetPerDay;

  const QadaPlan({
    required this.prayer,
    required this.currentBalance,
    required this.targetPerDay,
  }) : assert(targetPerDay > 0, 'targetPerDay must be positive.');

  /// Days until the balance reaches zero at [targetPerDay] per day.
  int get daysToClear => (currentBalance / targetPerDay).ceil();

  DateTime projectedClearanceDate({DateTime? from}) {
    final start = from ?? DateTime.now();
    if (currentBalance <= 0) return start;
    return DateTime(start.year, start.month, start.day)
        .add(Duration(days: daysToClear));
  }
}
