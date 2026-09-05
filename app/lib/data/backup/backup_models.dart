import '../../domain/prayer_engine/prayer.dart';
import '../../domain/qada/qada_payment.dart';
import '../../domain/tracker/prayer_log_entry.dart';
import '../../domain/tracker/prayer_status.dart';
import '../../domain/tracker/sunnah.dart';
import '../db/codecs.dart';

/// The full local backup (SRS FR-BK-01, §2.9): settings, logs, sunnah, qada.
/// Tracker data never leaves the device except through this export.
class BackupData {
  static const int schemaVersion = 1;

  final DateTime exportedAt;
  final Map<String, String> settings;
  final List<BackupProfile> profiles;
  final List<PrayerLogEntry> prayerLog;
  final List<SunnahLogEntry> sunnahLog;
  final List<QadaPayment> qadaPayments;
  final Map<Prayer, int> qadaOpening;

  const BackupData({
    required this.exportedAt,
    required this.settings,
    required this.profiles,
    required this.prayerLog,
    required this.sunnahLog,
    required this.qadaPayments,
    required this.qadaOpening,
  });

  Map<String, dynamic> toJson() => {
        'schema': schemaVersion,
        'exportedAt': exportedAt.toIso8601String(),
        'settings': settings,
        'profiles': profiles.map((p) => p.toJson()).toList(),
        'prayerLog': prayerLog.map(_prayerLogToJson).toList(),
        'sunnahLog': sunnahLog.map(_sunnahLogToJson).toList(),
        'qadaPayments': qadaPayments.map(_qadaPaymentToJson).toList(),
        'qadaOpening': qadaOpening.map((k, v) => MapEntry(k.name, v)),
      };

  factory BackupData.fromJson(Map<String, dynamic> json) {
    final schema = json['schema'] as int;
    if (schema != schemaVersion) {
      throw FormatException('Unsupported backup schema version: $schema');
    }
    return BackupData(
      exportedAt: DateTime.parse(json['exportedAt'] as String),
      settings: Map<String, String>.from(json['settings'] as Map),
      profiles: (json['profiles'] as List)
          .map((p) => BackupProfile.fromJson(p as Map<String, dynamic>))
          .toList(),
      prayerLog: (json['prayerLog'] as List)
          .map((p) => _prayerLogFromJson(p as Map<String, dynamic>))
          .toList(),
      sunnahLog: (json['sunnahLog'] as List)
          .map((p) => _sunnahLogFromJson(p as Map<String, dynamic>))
          .toList(),
      qadaPayments: (json['qadaPayments'] as List)
          .map((p) => _qadaPaymentFromJson(p as Map<String, dynamic>))
          .toList(),
      qadaOpening: (json['qadaOpening'] as Map).map(
        (k, v) => MapEntry(Codecs.prayerFromDb(k as String), v as int),
      ),
    );
  }

  static Map<String, dynamic> _prayerLogToJson(PrayerLogEntry e) => {
        'id': e.id,
        'date': Codecs.dateKey(e.date),
        'prayer': e.prayer.name,
        'status': Codecs.statusToDb(e.status),
        'prayedAt': e.prayedAt?.toIso8601String(),
        'loggedAt': e.loggedAt.toIso8601String(),
        'source': e.source.name,
        'travelling': e.travelling,
        'combinedWith': e.combinedWith,
        'note': e.note,
      };

  static PrayerLogEntry _prayerLogFromJson(Map<String, dynamic> j) =>
      PrayerLogEntry(
        id: j['id'] as String,
        date: Codecs.parseDateKey(j['date'] as String),
        prayer: Codecs.prayerFromDb(j['prayer'] as String),
        status: Codecs.statusFromDb(j['status'] as String),
        prayedAt:
            j['prayedAt'] == null ? null : DateTime.parse(j['prayedAt'] as String),
        loggedAt: DateTime.parse(j['loggedAt'] as String),
        source: LogSource.values.firstWhere((s) => s.name == j['source']),
        travelling: j['travelling'] as bool? ?? false,
        combinedWith: j['combinedWith'] as String?,
        note: j['note'] as String?,
      );

  static Map<String, dynamic> _sunnahLogToJson(SunnahLogEntry e) => {
        'date': Codecs.dateKey(e.date),
        'item': Codecs.sunnahItemToDb(e.item),
        'done': e.done,
        'loggedAt': e.loggedAt.toIso8601String(),
      };

  static SunnahLogEntry _sunnahLogFromJson(Map<String, dynamic> j) =>
      SunnahLogEntry(
        date: Codecs.parseDateKey(j['date'] as String),
        item: Codecs.sunnahItemFromDb(j['item'] as String),
        done: j['done'] as bool,
        loggedAt: DateTime.parse(j['loggedAt'] as String),
      );

  static Map<String, dynamic> _qadaPaymentToJson(QadaPayment p) => {
        'id': p.id,
        'prayer': p.prayer.name,
        'count': p.count,
        'date': Codecs.dateKey(p.date),
        'loggedAt': p.loggedAt.toIso8601String(),
        'note': p.note,
      };

  static QadaPayment _qadaPaymentFromJson(Map<String, dynamic> j) =>
      QadaPayment(
        id: j['id'] as String,
        prayer: Codecs.prayerFromDb(j['prayer'] as String),
        count: j['count'] as int,
        date: Codecs.parseDateKey(j['date'] as String),
        loggedAt: DateTime.parse(j['loggedAt'] as String),
        note: j['note'] as String?,
      );
}

/// Backup representation of an [IqamahProfile] (kept flat to avoid a
/// circular import between backup and schedule domain files).
class BackupProfile {
  final String id;
  final String name;
  final Map<Prayer, int> offsetMinutes;
  final Map<Prayer, int>? mosqueOverride;
  final bool isBuiltin;

  const BackupProfile({
    required this.id,
    required this.name,
    required this.offsetMinutes,
    this.mosqueOverride,
    this.isBuiltin = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'offsetMinutes': offsetMinutes.map((k, v) => MapEntry(k.name, v)),
        'mosqueOverride': mosqueOverride?.map((k, v) => MapEntry(k.name, v)),
        'isBuiltin': isBuiltin,
      };

  factory BackupProfile.fromJson(Map<String, dynamic> j) => BackupProfile(
        id: j['id'] as String,
        name: j['name'] as String,
        offsetMinutes: (j['offsetMinutes'] as Map).map(
          (k, v) => MapEntry(Codecs.prayerFromDb(k as String), v as int),
        ),
        mosqueOverride: j['mosqueOverride'] == null
            ? null
            : (j['mosqueOverride'] as Map).map(
                (k, v) => MapEntry(Codecs.prayerFromDb(k as String), v as int),
              ),
        isBuiltin: j['isBuiltin'] as bool? ?? false,
      );
}
