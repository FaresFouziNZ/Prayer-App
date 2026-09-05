import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_app/domain/prayer_engine/prayer.dart';
import 'package:prayer_app/domain/qada/qada_plan.dart';

void main() {
  test('daysToClear rounds up a non-exact remainder (FR-QD-04)', () {
    const plan = QadaPlan(prayer: Prayer.fajr, currentBalance: 10, targetPerDay: 3);

    expect(plan.daysToClear, 4);
  });

  test('daysToClear is exact when the balance divides evenly', () {
    const plan = QadaPlan(prayer: Prayer.dhuhr, currentBalance: 9, targetPerDay: 3);

    expect(plan.daysToClear, 3);
  });

  test('projectedClearanceDate adds daysToClear to the given start date', () {
    const plan = QadaPlan(prayer: Prayer.asr, currentBalance: 10, targetPerDay: 3);

    expect(
      plan.projectedClearanceDate(from: DateTime(2026, 3, 1)),
      DateTime(2026, 3, 5),
    );
  });

  test('projectedClearanceDate is today when the balance is already clear', () {
    const plan = QadaPlan(prayer: Prayer.maghrib, currentBalance: 0, targetPerDay: 3);

    final today = DateTime(2026, 3, 1);
    expect(plan.projectedClearanceDate(from: today), today);
  });

  test('targetPerDay must be positive', () {
    expect(
      () => QadaPlan(prayer: Prayer.isha, currentBalance: 5, targetPerDay: 0),
      throwsA(isA<AssertionError>()),
    );
  });
}
