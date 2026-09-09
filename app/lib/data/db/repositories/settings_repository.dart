import '../app_database.dart';

/// Typed accessors over the `settings` key/value table (SRS §2.1, NFR-09).
class SettingsRepository {
  final AppDatabase _db;

  SettingsRepository(this._db);

  Future<String?> getString(String key) async {
    final row = await (_db.select(
      _db.settingsTable,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> setString(String key, String value) {
    return _db
        .into(_db.settingsTable)
        .insertOnConflictUpdate(
          SettingsTableCompanion.insert(key: key, value: value),
        );
  }

  Future<int?> getInt(String key) async {
    final value = await getString(key);
    return value == null ? null : int.tryParse(value);
  }

  Future<void> setInt(String key, int value) =>
      setString(key, value.toString());

  Future<double?> getDouble(String key) async {
    final value = await getString(key);
    return value == null ? null : double.tryParse(value);
  }

  Future<void> setDouble(String key, double value) =>
      setString(key, value.toString());

  Future<bool?> getBool(String key) async {
    final value = await getString(key);
    if (value == null) return null;
    return value == 'true';
  }

  Future<void> setBool(String key, bool value) =>
      setString(key, value.toString());

  Stream<String?> watchString(String key) {
    return (_db.select(_db.settingsTable)..where((t) => t.key.equals(key)))
        .watchSingleOrNull()
        .map((row) => row?.value);
  }

  Stream<bool?> watchBool(String key) =>
      watchString(key).map((value) => value == null ? null : value == 'true');
}
