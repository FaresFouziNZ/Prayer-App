import 'package:drift/drift.dart';

import '../../../domain/schedule/iqamah_profile.dart';
import '../app_database.dart';
import '../codecs.dart';

/// Persists [IqamahProfile]s (SRS FR-IQ-02, FR-IQ-03).
class IqamahProfileRepository {
  final AppDatabase _db;

  IqamahProfileRepository(this._db);

  static const String normalProfileId = 'normal';
  static const String ramadanProfileId = 'ramadan';

  Future<List<IqamahProfile>> getAll() async {
    final rows = await _db.select(_db.iqamahProfileTable).get();
    return rows.map(_toDomain).toList();
  }

  Future<IqamahProfile?> getById(String id) async {
    final row = await (_db.select(_db.iqamahProfileTable)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  Future<void> upsert(IqamahProfile profile) {
    return _db.into(_db.iqamahProfileTable).insertOnConflictUpdate(
          IqamahProfileTableCompanion.insert(
            id: profile.id,
            name: profile.name,
            offsets: Codecs.offsetsToJson(profile.offsetMinutes),
            mosqueOverride: Value(
              profile.mosqueOverride == null
                  ? null
                  : Codecs.offsetsToJson(profile.mosqueOverride!),
            ),
            isBuiltin: Value(profile.isBuiltin),
          ),
        );
  }

  Future<void> delete(String id) {
    return (_db.delete(_db.iqamahProfileTable)..where((t) => t.id.equals(id)))
        .go();
  }

  IqamahProfile _toDomain(IqamahProfileRow row) {
    return IqamahProfile(
      id: row.id,
      name: row.name,
      offsetMinutes: Codecs.offsetsFromJson(row.offsets),
      mosqueOverride: row.mosqueOverride == null
          ? null
          : Codecs.offsetsFromJson(row.mosqueOverride!),
      isBuiltin: row.isBuiltin,
    );
  }
}
