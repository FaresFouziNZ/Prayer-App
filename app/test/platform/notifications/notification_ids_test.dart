import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_app/domain/prayer_engine/prayer.dart';
import 'package:prayer_app/platform/notifications/notification_ids.dart';

void main() {
  test('every (date, prayer, kind) combination gets a distinct id', () {
    final ids = <int>{};
    for (final date in [DateTime(2026, 3, 5), DateTime(2026, 3, 6)]) {
      for (final prayer in Prayer.values) {
        for (final kind in NotificationKind.values) {
          final id = NotificationIds.forEvent(date, prayer, kind);
          expect(ids.contains(id), isFalse, reason: 'duplicate id for $date $prayer $kind');
          ids.add(id);
        }
      }
    }
  });

  test('the same (date, prayer, kind) always maps to the same id', () {
    final a = NotificationIds.forEvent(DateTime(2026, 3, 5), Prayer.asr, NotificationKind.closing);
    final b = NotificationIds.forEvent(DateTime(2026, 3, 5), Prayer.asr, NotificationKind.closing);
    expect(a, b);
  });

  test('conditionalForPrayer returns exactly closing and endPrompt', () {
    final date = DateTime(2026, 3, 5);
    final conditional = NotificationIds.conditionalForPrayer(date, Prayer.fajr);

    expect(conditional, [
      NotificationIds.forEvent(date, Prayer.fajr, NotificationKind.closing),
      NotificationIds.forEvent(date, Prayer.fajr, NotificationKind.endPrompt),
    ]);
  });
}
