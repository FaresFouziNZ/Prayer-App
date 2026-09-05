import '../prayer_engine/prayer.dart';

/// Domain model mirroring one row of the `qada_payment` table (SRS §2.4).
class QadaPayment {
  final String id;
  final Prayer prayer;
  final int count;
  final DateTime date;
  final DateTime loggedAt;
  final String? note;

  const QadaPayment({
    required this.id,
    required this.prayer,
    required this.count,
    required this.date,
    required this.loggedAt,
    this.note,
  }) : assert(count > 0, 'A qada payment must record at least one prayer.');
}
