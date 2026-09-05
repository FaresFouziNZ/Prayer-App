import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../domain/prayer_engine/prayer.dart';
import '../../domain/tracker/prayer_log_entry.dart';
import '../../domain/tracker/prayer_status.dart';
import '../../l10n/app_localizations.dart';
import 'day_detail_screen.dart';

/// Last 30 days, each row summarised as five status dots (SRS FR-TR-03:
/// history view for backfilling).
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final today = ref.watch(todayProvider);
    final logsAsync = ref.watch(historyLogsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.historyTitle)),
      body: logsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text(l10n.errorLabel(error.toString()))),
        data: (logs) {
          final byDay = <DateTime, Map<Prayer, PrayerLogEntry>>{};
          for (final log in logs) {
            final day = DateTime(log.date.year, log.date.month, log.date.day);
            (byDay[day] ??= {})[log.prayer] = log;
          }

          final days = List.generate(
            historyWindowDays,
            (i) => today.subtract(Duration(days: i)),
          );

          return ListView.builder(
            itemCount: days.length,
            itemBuilder: (context, index) {
              final day = days[index];
              final dayLogs = byDay[day] ?? const {};
              return ListTile(
                title: Text(DateFormat.yMMMd().format(day)),
                trailing: _DayDots(logsByPrayer: dayLogs),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => DayDetailScreen(date: day),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _DayDots extends StatelessWidget {
  final Map<Prayer, PrayerLogEntry> logsByPrayer;

  const _DayDots({required this.logsByPrayer});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: Prayer.values.map((prayer) {
        final status = logsByPrayer[prayer]?.status;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: CircleAvatar(radius: 5, backgroundColor: _colorFor(status)),
        );
      }).toList(),
    );
  }

  Color _colorFor(PrayerStatus? status) {
    switch (status) {
      case PrayerStatus.jamaah:
        return Colors.green;
      case PrayerStatus.onTimeAlone:
        return Colors.blue;
      case PrayerStatus.late:
        return Colors.orange;
      case PrayerStatus.missed:
        return Colors.red;
      case null:
        return Colors.grey.shade300;
    }
  }
}
