import 'package:drift/drift.dart';

/// Typed key/value settings store (SRS §2.4). Keys are constants defined by
/// each consumer; values are JSON-encoded.
@DataClassName('SettingsEntry')
class SettingsTable extends Table {
  @override
  String get tableName => 'settings';

  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DataClassName('IqamahProfileRow')
class IqamahProfileTable extends Table {
  @override
  String get tableName => 'iqamah_profile';

  /// 'normal' | 'ramadan' | uuid for custom profiles.
  TextColumn get id => text()();
  TextColumn get name => text()();

  /// JSON `{fajr:25,...}`.
  TextColumn get offsets => text()();

  /// JSON or null (FR-IQ-03).
  TextColumn get mosqueOverride => text().nullable()();
  BoolColumn get isBuiltin => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('PrayerLogRow')
@TableIndex(name: 'idx_prayer_log_date', columns: {#date})
class PrayerLogTable extends Table {
  @override
  String get tableName => 'prayer_log';

  TextColumn get id => text()();

  /// 'YYYY-MM-DD' local prayer date.
  TextColumn get date => text()();

  /// fajr|dhuhr|asr|maghrib|isha
  TextColumn get prayer => text()();

  /// jamaah|on_time_alone|late|missed
  TextColumn get status => text()();

  /// ISO-8601, nullable (unknown for backfill).
  TextColumn get prayedAt => text().nullable()();

  /// ISO-8601.
  TextColumn get loggedAt => text()();

  /// manual|notification_action|live_activity|import
  TextColumn get source => text()();
  BoolColumn get travelling => boolean().withDefault(const Constant(false))();

  /// Prayer name or null.
  TextColumn get combinedWith => text().nullable()();
  TextColumn get note => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {date, prayer},
      ];
}

@DataClassName('SunnahLogRow')
class SunnahLogTable extends Table {
  @override
  String get tableName => 'sunnah_log';

  TextColumn get date => text()();

  /// fajr_before|dhuhr_before|dhuhr_after|maghrib_after|isha_after|witr
  TextColumn get item => text()();
  BoolColumn get done => boolean().withDefault(const Constant(false))();
  TextColumn get loggedAt => text()();

  @override
  Set<Column> get primaryKey => {date, item};
}

@DataClassName('QadaPaymentRow')
class QadaPaymentTable extends Table {
  @override
  String get tableName => 'qada_payment';

  TextColumn get id => text()();
  TextColumn get prayer => text()();
  IntColumn get count => integer()();

  /// Day the payment was made.
  TextColumn get date => text()();
  TextColumn get loggedAt => text()();
  TextColumn get note => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('QadaOpeningBalanceRow')
class QadaOpeningBalanceTable extends Table {
  @override
  String get tableName => 'qada_opening_balance';

  TextColumn get prayer => text()();
  IntColumn get count => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {prayer};
}
