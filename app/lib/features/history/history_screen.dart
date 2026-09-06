import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../config/settings_keys.dart';
import '../../domain/prayer_engine/prayer.dart';
import '../../domain/tracker/prayer_log_entry.dart';
import '../../l10n/app_localizations.dart';
import 'day_detail_screen.dart';

/// Last 30 days, each row summarised as five status dots (SRS FR-TR-03:
/// history view for backfilling). Days before the app was ever installed
/// can't have data, so they're collapsed into one dismissible notice
/// instead of a run of empty "not logged" rows.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final today = ref.watch(todayProvider);
    final logsAsync = ref.watch(historyLogsProvider);
    final scheme = Theme.of(context).colorScheme;
    final firstLaunchDate = ref.watch(firstLaunchDateProvider).value;
    final preInstallDismissed =
        ref.watch(historyPreInstallDismissedProvider).value ?? false;

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

          final allDays = List.generate(
            historyWindowDays,
            (i) => today.subtract(Duration(days: i)),
          );
          final days = firstLaunchDate == null
              ? allDays
              : allDays.where((d) => !d.isBefore(firstLaunchDate)).toList();
          final preInstallCount = allDays.length - days.length;
          final showPreInstallNotice = preInstallCount > 0 && !preInstallDismissed;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (final (index, day) in days.indexed) ...[
                      if (index > 0)
                        Divider(height: 1, indent: 16, color: scheme.outlineVariant),
                      _DayRow(
                        day: day,
                        isToday: day == today,
                        isYesterday: day == today.subtract(const Duration(days: 1)),
                        logsByPrayer: byDay[day] ?? const {},
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => DayDetailScreen(date: day),
                          ),
                        ),
                      ),
                    ],
                    if (showPreInstallNotice) ...[
                      if (days.isNotEmpty)
                        Divider(height: 1, indent: 16, color: scheme.outlineVariant),
                      _PreInstallNotice(
                        count: preInstallCount,
                        onDismiss: () async {
                          await ref
                              .read(settingsRepositoryProvider)
                              .setBool(SettingsKeys.historyPreInstallDismissed, true);
                          ref.invalidate(historyPreInstallDismissedProvider);
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PreInstallNotice extends StatelessWidget {
  final int count;
  final VoidCallback onDismiss;

  const _PreInstallNotice({required this.count, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      shape: const RoundedRectangleBorder(),
      leading: Icon(Icons.history_toggle_off_rounded, color: scheme.onSurfaceVariant),
      title: Text(
        l10n.historyPreInstallLabel(count),
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: scheme.onSurfaceVariant),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.close_rounded),
        tooltip: l10n.dismiss,
        onPressed: onDismiss,
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  final DateTime day;
  final bool isToday;
  final bool isYesterday;
  final Map<Prayer, PrayerLogEntry> logsByPrayer;
  final VoidCallback onTap;

  const _DayRow({
    required this.day,
    required this.isToday,
    required this.isYesterday,
    required this.logsByPrayer,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final label = isToday
        ? l10n.todayLabel
        : isYesterday
            ? l10n.yesterdayLabel
            : DateFormat.yMMMEd().format(day);

    return ListTile(
      shape: const RoundedRectangleBorder(),
      title: Text(
        label,
        style: (isToday
            ? Theme.of(context).textTheme.titleMedium
            : Theme.of(context).textTheme.bodyLarge)
            ?.copyWith(color: isToday ? scheme.primary : null),
      ),
      trailing: _DayDots(logsByPrayer: logsByPrayer),
      onTap: onTap,
    );
  }
}

class _DayDots extends StatelessWidget {
  final Map<Prayer, PrayerLogEntry> logsByPrayer;

  const _DayDots({required this.logsByPrayer});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: Prayer.values.map((prayer) {
        final status = logsByPrayer[prayer]?.status;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2.5),
          child: CircleAvatar(
            radius: 6,
            backgroundColor: PrayerColors.of(scheme, status),
          ),
        );
      }).toList(),
    );
  }
}
