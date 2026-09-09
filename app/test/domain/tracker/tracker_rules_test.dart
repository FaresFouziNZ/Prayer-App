import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_app/domain/prayer_engine/prayer.dart';
import 'package:prayer_app/domain/tracker/prayer_excuse.dart';
import 'package:prayer_app/domain/tracker/prayer_status.dart';
import 'package:prayer_app/domain/tracker/tracker_rules.dart';

void main() {
  group('applyJumuahRule (FR-TR-07)', () {
    test('Friday Dhuhr logged as alone becomes jamaah', () {
      final result = TrackerRules.applyJumuahRule(
        prayer: Prayer.dhuhr,
        isFriday: true,
        requestedStatus: PrayerStatus.onTimeAlone,
      );
      expect(result, PrayerStatus.jamaah);
    });

    test('Friday Dhuhr logged as late is left as late', () {
      final result = TrackerRules.applyJumuahRule(
        prayer: Prayer.dhuhr,
        isFriday: true,
        requestedStatus: PrayerStatus.late,
      );
      expect(result, PrayerStatus.late);
    });

    test('non-Friday Dhuhr is unaffected', () {
      final result = TrackerRules.applyJumuahRule(
        prayer: Prayer.dhuhr,
        isFriday: false,
        requestedStatus: PrayerStatus.onTimeAlone,
      );
      expect(result, PrayerStatus.onTimeAlone);
    });

    test('Friday Asr is unaffected (only Dhuhr is Jumu\'ah)', () {
      final result = TrackerRules.applyJumuahRule(
        prayer: Prayer.asr,
        isFriday: true,
        requestedStatus: PrayerStatus.onTimeAlone,
      );
      expect(result, PrayerStatus.onTimeAlone);
    });
  });

  test('buildEntry stamps loggedAt and applies the Jumu\'ah rule', () {
    final now = DateTime(2026, 3, 6, 13, 0); // Friday
    final entry = TrackerRules.buildEntry(
      prayer: Prayer.dhuhr,
      date: DateTime(2026, 3, 6),
      status: PrayerStatus.onTimeAlone,
      isFriday: true,
      source: LogSource.manual,
      now: now,
    );

    expect(entry.status, PrayerStatus.jamaah);
    expect(entry.loggedAt, now);
    expect(entry.isBackfilled, isFalse);
  });

  test('a backfilled entry has loggedAt after the prayer date (AC-TR-3)', () {
    final entry = TrackerRules.buildEntry(
      prayer: Prayer.fajr,
      date: DateTime(2026, 3, 1),
      status: PrayerStatus.missed,
      isFriday: false,
      source: LogSource.manual,
      now: DateTime(2026, 3, 5),
    );

    expect(entry.isBackfilled, isTrue);
  });

  test('only Dhuhr-Asr and Maghrib-Isha may be combined (FR-TR-06)', () {
    expect(TrackerRules.combinablePartner(Prayer.dhuhr), Prayer.asr);
    expect(TrackerRules.combinablePartner(Prayer.maghrib), Prayer.isha);
    expect(TrackerRules.combinablePartner(Prayer.fajr), isNull);
    expect(TrackerRules.combinablePartner(Prayer.asr), isNull);
    expect(TrackerRules.combinablePartner(Prayer.isha), isNull);
  });

  test('combined entries share prayedAt and point at each other (FR-TR-06)', () {
    final (first, second) = TrackerRules.buildCombinedEntries(
      first: Prayer.dhuhr,
      second: Prayer.asr,
      date: DateTime(2026, 3, 6),
      status: PrayerStatus.jamaah,
      source: LogSource.manual,
      now: DateTime(2026, 3, 6, 15, 0),
    );

    expect(first.combinedWith, 'asr');
    expect(second.combinedWith, 'dhuhr');
    expect(first.prayedAt, second.prayedAt);
    expect(first.travelling, isTrue);
    expect(second.travelling, isTrue);
  });

  test('edit bumps loggedAt without touching the original date (FR-TR-05)', () {
    final original = TrackerRules.buildEntry(
      prayer: Prayer.isha,
      date: DateTime(2026, 3, 1),
      status: PrayerStatus.late,
      isFriday: false,
      source: LogSource.manual,
      now: DateTime(2026, 3, 1, 21, 0),
    );

    final edited = TrackerRules.edit(
      original,
      status: PrayerStatus.jamaah,
      now: DateTime(2026, 3, 2, 9, 0),
    );

    expect(edited.status, PrayerStatus.jamaah);
    expect(edited.date, original.date);
    expect(edited.loggedAt, DateTime(2026, 3, 2, 9, 0));
  });

  test('editing a Friday Dhuhr entry still applies the Jumu\'ah rule', () {
    final original = TrackerRules.buildEntry(
      prayer: Prayer.dhuhr,
      date: DateTime(2026, 3, 6), // Friday
      status: PrayerStatus.missed,
      isFriday: true,
      source: LogSource.manual,
      now: DateTime(2026, 3, 6, 20, 0),
    );

    final edited = TrackerRules.edit(
      original,
      status: PrayerStatus.onTimeAlone,
      now: DateTime(2026, 3, 6, 21, 0),
    );

    expect(edited.status, PrayerStatus.jamaah);
  });

  test('buildEntry carries an excuse through for late/missed', () {
    final entry = TrackerRules.buildEntry(
      prayer: Prayer.fajr,
      date: DateTime(2026, 3, 1),
      status: PrayerStatus.missed,
      isFriday: false,
      source: LogSource.manual,
      excuse: PrayerExcuse.overslept,
    );

    expect(entry.excuse, PrayerExcuse.overslept);
  });

  test('editing without clearExcuse leaves an existing excuse untouched', () {
    final original = TrackerRules.buildEntry(
      prayer: Prayer.isha,
      date: DateTime(2026, 3, 1),
      status: PrayerStatus.late,
      isFriday: false,
      source: LogSource.manual,
      excuse: PrayerExcuse.busy,
    );

    final edited = TrackerRules.edit(original, prayedAt: DateTime(2026, 3, 1, 20, 0));

    expect(edited.excuse, PrayerExcuse.busy);
  });

  test('editing with clearExcuse drops the excuse (status no longer late/missed)', () {
    final original = TrackerRules.buildEntry(
      prayer: Prayer.isha,
      date: DateTime(2026, 3, 1),
      status: PrayerStatus.late,
      isFriday: false,
      source: LogSource.manual,
      excuse: PrayerExcuse.busy,
    );

    final edited = TrackerRules.edit(
      original,
      status: PrayerStatus.jamaah,
      clearExcuse: true,
    );

    expect(edited.status, PrayerStatus.jamaah);
    expect(edited.excuse, isNull);
  });
}
