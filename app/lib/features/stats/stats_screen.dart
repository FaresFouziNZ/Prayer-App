import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/prayer_names.dart';
import '../../app/providers.dart';
import '../../app/sunnah_labels.dart';
import '../../domain/prayer_engine/hijri_date.dart';
import '../../domain/prayer_engine/prayer.dart';
import '../../domain/stats/period_stats.dart';
import '../../domain/stats/streak.dart';
import '../../domain/stats/sunnah_stats.dart';
import '../../domain/tracker/prayer_log_entry.dart';
import '../../domain/tracker/sunnah.dart';
import '../../l10n/app_localizations.dart';

/// The period a user can pick in Stats (SRS FR-ST-01). Kept as its own enum
/// rather than passing the resolved day count straight to [SegmentedButton]
/// because "this Hijri month" resolves to a different day count every day,
/// which can't be a fixed segment value.
enum _StatsPeriod { d7, d30, d90, hijriMonth, all }

/// SRS FR-ST: rates, per-prayer breakdown, sunnah completion, and streak
/// for a selectable period.
class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  _StatsPeriod _period = _StatsPeriod.d30;

  /// Number of trailing days the period covers, or `null` for "all time".
  /// "This Hijri month" resolves to the current Hijri day-of-month, since
  /// the tabular Hijri calendar advances exactly one day per Gregorian day
  /// — that many days back from today lands on the 1st of the month.
  int? _resolveDays(DateTime today) {
    switch (_period) {
      case _StatsPeriod.d7:
        return 7;
      case _StatsPeriod.d30:
        return 30;
      case _StatsPeriod.d90:
        return 90;
      case _StatsPeriod.hijriMonth:
        return HijriDate.fromGregorian(today).day;
      case _StatsPeriod.all:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final today = ref.watch(todayProvider);
    final periodDays = _resolveDays(today);
    final logsAsync = ref.watch(periodLogsProvider(periodDays));
    final sunnahAsync = ref.watch(periodSunnahProvider(periodDays));
    final excludedDays = ref.watch(periodDaysProvider).value ?? const {};

    return Scaffold(
      appBar: AppBar(title: Text(l10n.statsTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<_StatsPeriod>(
                segments: [
                  ButtonSegment(
                    value: _StatsPeriod.d7,
                    label: Text(l10n.period7d),
                  ),
                  ButtonSegment(
                    value: _StatsPeriod.d30,
                    label: Text(l10n.period30d),
                  ),
                  ButtonSegment(
                    value: _StatsPeriod.d90,
                    label: Text(l10n.period90d),
                  ),
                  ButtonSegment(
                    value: _StatsPeriod.hijriMonth,
                    label: Text(l10n.periodHijriMonth),
                  ),
                  ButtonSegment(
                    value: _StatsPeriod.all,
                    label: Text(l10n.periodAll),
                  ),
                ],
                selected: {_period},
                onSelectionChanged: (selection) =>
                    setState(() => _period = selection.first),
              ),
            ),
          ),
          Expanded(
            child: logsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) =>
                  Center(child: Text(l10n.errorLabel(error.toString()))),
              data: (logs) => sunnahAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) =>
                    Center(child: Text(l10n.errorLabel(error.toString()))),
                data: (sunnahEntries) => _StatsBody(
                  logs: logs,
                  sunnahEntries: sunnahEntries,
                  today: today,
                  periodDays: periodDays,
                  excludedDays: excludedDays,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsBody extends StatelessWidget {
  final List<PrayerLogEntry> logs;
  final List<SunnahLogEntry> sunnahEntries;
  final DateTime today;
  final int? periodDays;
  final Set<DateTime> excludedDays;

  const _StatsBody({
    required this.logs,
    required this.sunnahEntries,
    required this.today,
    required this.periodDays,
    required this.excludedDays,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final labels = sunnahLabels(l10n);
    final start = periodDays != null
        ? today.subtract(Duration(days: periodDays! - 1))
        : (logs.isEmpty
              ? today
              : logs
                    .map((l) => l.date)
                    .reduce((a, b) => a.isBefore(b) ? a : b));
    // Period days (FR-EX-04) are dropped before computing the day-level
    // stats, so they're skipped entirely for prayers and sunnah rather than
    // counted as not-logged. The streak is prayer-based, not day-based, so
    // it gets the unfiltered range instead — an unlogged prayer is already
    // neutral there (never breaks the streak), which is exactly right for
    // a period day too, while any prayer actually logged before the period
    // began that day still counts (see Streak's doc comment).
    final allDays = List.generate(
      today.difference(start).inDays + 1,
      (i) => start.add(Duration(days: i)),
    );
    final days = allDays.where((day) => !excludedDays.contains(day)).toList();

    final overall = PeriodStats.compute(days: days, logs: logs);
    final perPrayer = PeriodStats.computePerPrayer(days: days, logs: logs);
    final streak = Streak.compute(days: allDays, logs: logs);
    final sunnahRates = SunnahStats.completionRate(
      days: days,
      entries: sunnahEntries,
    );
    final percent = NumberFormat.percentPattern();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _MetricsCard(title: l10n.overallLabel, metrics: overall),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StreakStat(
                  label: l10n.currentStreakLabel,
                  value: streak.current,
                ),
                _StreakStat(label: l10n.bestStreakLabel, value: streak.best),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          l10n.perPrayerLabel,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        for (final prayer in Prayer.values)
          _MetricsCard(
            title: PrayerNames.displayName(context, prayer),
            metrics: perPrayer[prayer]!,
          ),
        const SizedBox(height: 12),
        Text(
          l10n.sunnahCompletionTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Card(
          child: Column(
            children: [
              for (final item in SunnahItem.values)
                ListTile(
                  dense: true,
                  title: Text(labels[item]!),
                  trailing: Text(percent.format(sunnahRates[item] ?? 0)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StreakStat extends StatelessWidget {
  final String label;
  final int value;

  const _StreakStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lit = value > 0;
    return Column(
      children: [
        Icon(
          Icons.local_fire_department_rounded,
          size: 28,
          color: lit ? scheme.secondary : scheme.outlineVariant,
        ),
        const SizedBox(height: 4),
        Text('$value', style: Theme.of(context).textTheme.headlineMedium),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _RateCircle extends StatelessWidget {
  final String tooltip;
  final String caption;
  final double value;
  final Color color;

  const _RateCircle({
    required this.tooltip,
    required this.caption,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final percent = NumberFormat.percentPattern().format(value.clamp(0, 1));
    return Tooltip(
      message: tooltip,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 72,
            height: 72,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: value.clamp(0, 1),
                    strokeWidth: 7,
                    strokeCap: StrokeCap.round,
                    backgroundColor: scheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
                Text(
                  percent,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            caption,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _MetricsCard extends StatelessWidget {
  final String title;
  final PeriodMetrics metrics;

  const _MetricsCard({required this.title, required this.metrics});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final percent = NumberFormat.percentPattern();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _RateCircle(
                  tooltip: l10n.jamaahRateLabel(
                    percent.format(metrics.jamaahRate),
                  ),
                  caption: l10n.statusJamaah,
                  value: metrics.jamaahRate,
                  color: scheme.primary,
                ),
                _RateCircle(
                  tooltip: l10n.onTimeRateLabel(
                    percent.format(metrics.onTimeRate),
                  ),
                  caption: l10n.onTimeCaptionLabel,
                  value: metrics.onTimeRate,
                  color: scheme.tertiary,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              l10n.lateMissedNotLoggedLabel(
                metrics.lateCount,
                metrics.missedCount,
                metrics.notLoggedCount,
              ),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
