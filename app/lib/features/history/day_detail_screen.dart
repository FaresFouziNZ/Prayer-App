import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../l10n/app_localizations.dart';
import '../home/prayer_log_actions.dart';
import '../home/widgets/sunnah_checklist.dart';
import '../home/widgets/today_prayer_list.dart';

/// Backfill / edit view for a single past day (SRS FR-TR-03, AC-TR-3).
class DayDetailScreen extends ConsumerWidget {
  final DateTime date;

  const DayDetailScreen({super.key, required this.date});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final snapshotAsync = ref.watch(daySnapshotProvider(date));
    final logsAsync = ref.watch(dayLogsProvider(date));

    return Scaffold(
      appBar: AppBar(title: Text(DateFormat.yMMMd().format(date))),
      body: snapshotAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text(l10n.errorLabel(error.toString()))),
        data: (snapshot) => logsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(child: Text(l10n.errorLabel(error.toString()))),
          data: (logs) {
            final logsByPrayer = {for (final log in logs) log.prayer: log};
            return ListView(
              children: [
                TodayPrayerList(
                  events: snapshot.events,
                  logsByPrayer: logsByPrayer,
                  isFriday: snapshot.prayerDay.isJumuah,
                  onLog: (prayer, status, note) => PrayerLogActions.save(
                    ref,
                    date: date,
                    prayer: prayer,
                    status: status,
                    note: note,
                    isFriday: snapshot.prayerDay.isJumuah,
                    existing: logsByPrayer[prayer],
                  ),
                  onDelete: (prayer) {
                    final existing = logsByPrayer[prayer];
                    if (existing != null) PrayerLogActions.delete(ref, existing);
                  },
                  onCombine: (first, second, status) => PrayerLogActions.combine(
                    ref,
                    date: date,
                    first: first,
                    second: second,
                    status: status,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Divider(),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SunnahChecklist(date: date),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
