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
/// can't have real data by default, but the user may still want to
/// backfill one of them (e.g. they remember praying Jama'ah a specific day
/// before they installed the app) — so they're tucked behind a collapsed,
/// expandable notice rather than shown as a wall of empty rows, but tapping
/// the notice still reveals each day as a normal, tappable row.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  bool _preInstallExpanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final today = ref.watch(todayProvider);
    final logsAsync = ref.watch(historyLogsProvider);
    final scheme = Theme.of(context).colorScheme;
    final firstLaunchDate = ref.watch(firstLaunchDateProvider).value;
    final preInstallDismissed =
        ref.watch(historyPreInstallDismissedProvider).value ?? false;
    final periodDays = ref.watch(periodDaysProvider).value ?? const {};

    return Scaffold(
      appBar: AppBar(title: Text(l10n.historyTitle)),
      body: logsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) =>
            Center(child: Text(l10n.errorLabel(error.toString()))),
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
          final preInstallDays = firstLaunchDate == null
              ? const <DateTime>[]
              : allDays.skip(days.length).toList();
          final showPreInstallNotice =
              preInstallDays.isNotEmpty && !preInstallDismissed;

          Widget dayRow(DateTime day) => _DayRow(
            day: day,
            isToday: day == today,
            isYesterday: day == today.subtract(const Duration(days: 1)),
            logsByPrayer: byDay[day] ?? const {},
            isPeriodDay: periodDays.contains(day),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => DayDetailScreen(date: day),
              ),
            ),
          );

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (final (index, day) in days.indexed) ...[
                      if (index > 0)
                        Divider(
                          height: 1,
                          indent: 16,
                          color: scheme.outlineVariant,
                        ),
                      dayRow(day),
                    ],
                    if (showPreInstallNotice) ...[
                      if (days.isNotEmpty)
                        Divider(
                          height: 1,
                          indent: 16,
                          color: scheme.outlineVariant,
                        ),
                      _PreInstallNotice(
                        count: preInstallDays.length,
                        expanded: _preInstallExpanded,
                        onToggleExpand: () => setState(
                          () => _preInstallExpanded = !_preInstallExpanded,
                        ),
                        onDismiss: () async {
                          await ref
                              .read(settingsRepositoryProvider)
                              .setBool(
                                SettingsKeys.historyPreInstallDismissed,
                                true,
                              );
                          ref.invalidate(historyPreInstallDismissedProvider);
                        },
                      ),
                      if (_preInstallExpanded)
                        for (final day in preInstallDays) ...[
                          Divider(
                            height: 1,
                            indent: 16,
                            color: scheme.outlineVariant,
                          ),
                          dayRow(day),
                        ],
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
  final bool expanded;
  final VoidCallback onToggleExpand;
  final VoidCallback onDismiss;

  const _PreInstallNotice({
    required this.count,
    required this.expanded,
    required this.onToggleExpand,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      shape: const RoundedRectangleBorder(),
      leading: Icon(
        Icons.history_toggle_off_rounded,
        color: scheme.onSurfaceVariant,
      ),
      title: Text(
        l10n.historyPreInstallLabel(count),
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedRotation(
            duration: const Duration(milliseconds: 200),
            turns: expanded ? 0.5 : 0,
            child: Icon(
              Icons.expand_more_rounded,
              color: scheme.onSurfaceVariant,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded),
            tooltip: l10n.dismiss,
            onPressed: onDismiss,
          ),
        ],
      ),
      onTap: onToggleExpand,
    );
  }
}

class _DayRow extends StatelessWidget {
  final DateTime day;
  final bool isToday;
  final bool isYesterday;
  final Map<Prayer, PrayerLogEntry> logsByPrayer;
  final bool isPeriodDay;
  final VoidCallback onTap;

  const _DayRow({
    required this.day,
    required this.isToday,
    required this.isYesterday,
    required this.logsByPrayer,
    required this.isPeriodDay,
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
        style:
            (isToday
                    ? Theme.of(context).textTheme.titleMedium
                    : Theme.of(context).textTheme.bodyLarge)
                ?.copyWith(color: isToday ? scheme.primary : null),
      ),
      subtitle: isPeriodDay ? Text(l10n.periodDayLabel) : null,
      trailing: isPeriodDay
          ? Icon(Icons.water_drop_rounded, color: scheme.primary, size: 20)
          : _DayDots(logsByPrayer: logsByPrayer),
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
