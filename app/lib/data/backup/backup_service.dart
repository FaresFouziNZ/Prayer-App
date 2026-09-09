import 'dart:convert';

import '../../domain/schedule/iqamah_profile.dart';
import '../db/app_database.dart';
import '../db/repositories/iqamah_profile_repository.dart';
import '../db/repositories/prayer_log_repository.dart';
import '../db/repositories/qada_repository.dart';
import '../db/repositories/settings_repository.dart';
import '../db/repositories/sunnah_repository.dart';
import 'backup_models.dart';

/// Import dry-run summary shown to the user before applying (SRS FR-BK-02).
class ImportDiff {
  final int rowsToAdd;
  final int rowsConflicting;
  final int rowsIdentical;

  const ImportDiff({
    required this.rowsToAdd,
    required this.rowsConflicting,
    required this.rowsIdentical,
  });
}

/// Export to / import from a single JSON backup file (SRS FR-BK-01/02, §2.9).
class BackupService {
  final AppDatabase _db;
  final SettingsRepository _settings;
  final IqamahProfileRepository _profiles;
  final PrayerLogRepository _prayerLog;
  final SunnahRepository _sunnah;
  final QadaRepository _qada;

  BackupService(this._db)
    : _settings = SettingsRepository(_db),
      _profiles = IqamahProfileRepository(_db),
      _prayerLog = PrayerLogRepository(_db),
      _sunnah = SunnahRepository(_db),
      _qada = QadaRepository(_db);

  Future<String> exportToJsonString() async {
    final data = await _buildBackupData();
    return jsonEncode(data.toJson());
  }

  Future<BackupData> _buildBackupData() async {
    final settingsRows = await _db.select(_db.settingsTable).get();
    final profiles = await _profiles.getAll();
    final start = DateTime(1970);
    final end = DateTime.now().add(const Duration(days: 3650));

    return BackupData(
      exportedAt: DateTime.now(),
      settings: {for (final row in settingsRows) row.key: row.value},
      profiles: profiles
          .map(
            (p) => BackupProfile(
              id: p.id,
              name: p.name,
              offsetMinutes: p.offsetMinutes,
              mosqueOverride: p.mosqueOverride,
              isBuiltin: p.isBuiltin,
            ),
          )
          .toList(),
      prayerLog: await _prayerLog.getBetween(start, end),
      sunnahLog: await _sunnah.getAll(),
      qadaPayments: await _qada.getAllPayments(),
      qadaOpening: await _qada.getOpeningBalances(),
    );
  }

  /// Parses [jsonString] and reports what an import would do, without
  /// writing anything (FR-BK-02).
  Future<ImportDiff> dryRunImport(String jsonString) async {
    final incoming = BackupData.fromJson(
      jsonDecode(jsonString) as Map<String, dynamic>,
    );
    final existing = {
      for (final entry in await _prayerLog.getBetween(
        DateTime(1970),
        DateTime.now().add(const Duration(days: 3650)),
      ))
        (entry.date, entry.prayer): entry,
    };

    var toAdd = 0, conflicting = 0, identical = 0;
    for (final entry in incoming.prayerLog) {
      final match = existing[(entry.date, entry.prayer)];
      if (match == null) {
        toAdd++;
      } else if (match.id == entry.id &&
          match.loggedAt.isAtSameMomentAs(entry.loggedAt)) {
        identical++;
      } else {
        conflicting++;
      }
    }

    return ImportDiff(
      rowsToAdd: toAdd,
      rowsConflicting: conflicting,
      rowsIdentical: identical,
    );
  }

  /// Applies the import. Conflicts are resolved by newest `loggedAt`
  /// (§2.9).
  Future<void> applyImport(String jsonString) async {
    final incoming = BackupData.fromJson(
      jsonDecode(jsonString) as Map<String, dynamic>,
    );

    await _db.transaction(() async {
      for (final entry in incoming.settings.entries) {
        await _settings.setString(entry.key, entry.value);
      }

      for (final profile in incoming.profiles) {
        await _profiles.upsert(
          IqamahProfile(
            id: profile.id,
            name: profile.name,
            offsetMinutes: profile.offsetMinutes,
            mosqueOverride: profile.mosqueOverride,
            isBuiltin: profile.isBuiltin,
          ),
        );
      }

      final existing = {
        for (final entry in await _prayerLog.getBetween(
          DateTime(1970),
          DateTime.now().add(const Duration(days: 3650)),
        ))
          (entry.date, entry.prayer): entry,
      };
      for (final entry in incoming.prayerLog) {
        final match = existing[(entry.date, entry.prayer)];
        if (match == null || entry.loggedAt.isAfter(match.loggedAt)) {
          await _prayerLog.upsert(entry);
        }
      }

      for (final sunnah in incoming.sunnahLog) {
        await _sunnah.setDone(
          date: sunnah.date,
          item: sunnah.item,
          done: sunnah.done,
          now: sunnah.loggedAt,
        );
      }

      for (final payment in incoming.qadaPayments) {
        await _qada.recordPayment(
          prayer: payment.prayer,
          count: payment.count,
          date: payment.date,
          note: payment.note,
          now: payment.loggedAt,
        );
      }

      for (final entry in incoming.qadaOpening.entries) {
        await _qada.setOpeningBalance(entry.key, entry.value);
      }
    });
  }
}
