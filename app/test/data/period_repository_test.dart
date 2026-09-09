import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_app/data/db/app_database.dart';
import 'package:prayer_app/data/db/repositories/period_repository.dart';

void main() {
  late AppDatabase db;
  late PeriodRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = PeriodRepository(db);
  });

  tearDown(() => db.close());

  test('a day starts unmarked', () async {
    final marked = await repo.watchIsPeriodDay(DateTime(2026, 3, 1)).first;
    expect(marked, isFalse);
  });

  test('marking a day persists it, unmarking removes it', () async {
    final date = DateTime(2026, 3, 1);

    await repo.setPeriodDay(date, true);
    expect(await repo.watchIsPeriodDay(date).first, isTrue);

    await repo.setPeriodDay(date, false);
    expect(await repo.watchIsPeriodDay(date).first, isFalse);
  });

  test('marking the same day twice does not throw (idempotent)', () async {
    final date = DateTime(2026, 3, 1);

    await repo.setPeriodDay(date, true);
    await repo.setPeriodDay(date, true);

    expect(await repo.watchIsPeriodDay(date).first, isTrue);
  });

  test('watchAll returns every marked day', () async {
    await repo.setPeriodDay(DateTime(2026, 3, 1), true);
    await repo.setPeriodDay(DateTime(2026, 3, 2), true);
    await repo.setPeriodDay(DateTime(2026, 3, 3), true);
    await repo.setPeriodDay(DateTime(2026, 3, 2), false);

    final all = await repo.watchAll().first;
    expect(all, {DateTime(2026, 3, 1), DateTime(2026, 3, 3)});
  });
}
