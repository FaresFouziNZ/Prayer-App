import '../../domain/prayer_engine/prayer.dart';

/// Round-trips (date, prayer) through a scheduled notification's payload
/// string, so the action handler (which may run in a background isolate
/// with no other app state) knows which log row to write.
class NotificationPayload {
  final DateTime date;
  final Prayer prayer;

  const NotificationPayload({required this.date, required this.prayer});

  String encode() => '${date.toIso8601String()}|${prayer.name}';

  static NotificationPayload decode(String payload) {
    final parts = payload.split('|');
    return NotificationPayload(
      date: DateTime.parse(parts[0]),
      prayer: Prayer.values.firstWhere((p) => p.name == parts[1]),
    );
  }
}
