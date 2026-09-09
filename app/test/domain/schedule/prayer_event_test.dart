import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_app/domain/prayer_engine/prayer.dart';
import 'package:prayer_app/domain/schedule/prayer_event.dart';

void main() {
  final event = PrayerEvent(
    prayer: Prayer.dhuhr,
    date: DateTime(2026, 3, 1),
    preAdhanAt: DateTime(2026, 3, 1, 12, 10),
    adhanAt: DateTime(2026, 3, 1, 12, 20),
    iqamahAt: DateTime(2026, 3, 1, 12, 40),
    closingAt: DateTime(2026, 3, 1, 13, 20),
    endAt: DateTime(2026, 3, 1, 15, 0),
  );

  test('before adhan is its own phase, not iqamah', () {
    expect(event.phaseAt(DateTime(2026, 3, 1, 8, 0)), LivePhase.beforeAdhan);
    expect(event.phaseAt(DateTime(2026, 3, 1, 12, 19)), LivePhase.beforeAdhan);
  });

  test('between adhan and iqamah is the iqamah phase', () {
    expect(event.phaseAt(DateTime(2026, 3, 1, 12, 20)), LivePhase.iqamah);
    expect(event.phaseAt(DateTime(2026, 3, 1, 12, 39)), LivePhase.iqamah);
  });

  test('between iqamah and the closing offset is the window phase', () {
    expect(event.phaseAt(DateTime(2026, 3, 1, 12, 40)), LivePhase.window);
    expect(event.phaseAt(DateTime(2026, 3, 1, 13, 19)), LivePhase.window);
  });

  test('from the closing offset to window end is the closing phase', () {
    expect(event.phaseAt(DateTime(2026, 3, 1, 13, 20)), LivePhase.closing);
    expect(event.phaseAt(DateTime(2026, 3, 1, 14, 59)), LivePhase.closing);
  });
}
