import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../config/prayer_config.dart';
import '../../config/settings_keys.dart';
import '../../domain/prayer_engine/prayer.dart';
import '../../domain/prayer_engine/prayer_day.dart';
import '../../l10n/app_localizations.dart';
import 'prayer_log_actions.dart';
import 'widgets/next_prayer_card.dart';
import 'widgets/period_day_section.dart';
import 'widgets/sunnah_checklist.dart';
import 'widgets/today_prayer_list.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Timer? _nextEventTimer;

  @override
  void dispose() {
    _nextEventTimer?.cancel();
    super.dispose();
  }

  /// [NextPrayerCard] ticks its own countdown every second, but *which*
  /// event is "next" is only recomputed when this screen itself rebuilds —
  /// without this, the countdown sat at 00:00 forever once an event's
  /// window ended, instead of moving on to the next prayer. Scheduled fresh
  /// on every build (rather than a repeating poll) so it fires once, right
  /// after the current event's window actually ends.
  void _scheduleSwitchAt(DateTime endAt) {
    final delay = endAt.difference(DateTime.now()) + const Duration(seconds: 1);
    _nextEventTimer?.cancel();
    _nextEventTimer = Timer(delay.isNegative ? Duration.zero : delay, () {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final today = ref.watch(todayProvider);
    final snapshotAsync = ref.watch(daySnapshotProvider(today));
    final logsAsync = ref.watch(dayLogsProvider(today));
    final locationLabelAsync = ref.watch(locationLabelProvider);
    final periodTrackingEnabled =
        ref.watch(periodTrackingEnabledProvider).value ?? false;
    final isPeriodDay = ref.watch(dayIsPeriodProvider(today)).value ?? false;
    final isArabicLocale = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      body: SafeArea(
        child: snapshotAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) =>
              Center(child: Text(l10n.errorLabel(error.toString()))),
          data: (snapshot) {
            final now = DateTime.now();
            final nextEvent = snapshot.events.firstWhere(
              (event) => event.endAt.isAfter(now),
              orElse: () => snapshot.events.last,
            );
            _scheduleSwitchAt(nextEvent.endAt);
            final hijri = snapshot.hijriDate;
            final dateLine =
                '${DateFormat.MMMEd().format(today)} · '
                '${hijri.day} ${hijri.longMonthName(arabic: isArabicLocale)} ${hijri.year}';

            return logsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) =>
                  Center(child: Text(l10n.errorLabel(error.toString()))),
              data: (logs) {
                final logsByPrayer = {for (final log in logs) log.prayer: log};
                return RefreshIndicator(
                  onRefresh: () =>
                      ref.refresh(daySnapshotProvider(today).future),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          dateLine,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _LocationLine(labelAsync: locationLabelAsync),
                      ),
                      if (snapshot.suggestRamadanMode)
                        _RamadanSuggestionCard(
                          onEnable: () async {
                            await ref
                                .read(settingsRepositoryProvider)
                                .setBool(SettingsKeys.ramadanMode, true);
                            ref.invalidate(daySnapshotProvider);
                          },
                        ),
                      if (snapshot.ramadanMode)
                        _ImsakIftarCard(prayerDay: snapshot.prayerDay),
                      NextPrayerCard(
                        event: nextEvent,
                        isJumuah: snapshot.prayerDay.isJumuah,
                      ),
                      const SizedBox(height: 16),
                      if (periodTrackingEnabled) PeriodDayToggle(date: today),
                      if (isPeriodDay)
                        const PeriodExcusedNotice()
                      else
                        TodayPrayerList(
                          events: snapshot.events,
                          logsByPrayer: logsByPrayer,
                          isFriday: snapshot.prayerDay.isJumuah,
                          onLog: (prayer, status, excuse) =>
                              PrayerLogActions.save(
                                ref,
                                date: today,
                                prayer: prayer,
                                status: status,
                                excuse: excuse,
                                isFriday: snapshot.prayerDay.isJumuah,
                                existing: logsByPrayer[prayer],
                              ),
                          onDelete: (prayer) {
                            final existing = logsByPrayer[prayer];
                            if (existing != null)
                              PrayerLogActions.delete(ref, existing);
                          },
                          onCombine: (first, second, status) =>
                              PrayerLogActions.combine(
                                ref,
                                date: today,
                                first: first,
                                second: second,
                                status: status,
                              ),
                        ),
                      if (!isPeriodDay) ...[
                        const SizedBox(height: 16),
                        SunnahChecklist(date: today),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// Shows which location today's prayer times are computed for (FR-PT-03),
/// so the user isn't left guessing whether the schedule matches where they
/// actually are.
class _LocationLine extends StatelessWidget {
  final AsyncValue<String?> labelAsync;

  const _LocationLine({required this.labelAsync});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final label = labelAsync.value ?? l10n.defaultLocationLabel;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.location_on, size: 14, color: scheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          l10n.prayerTimesForLabel(label),
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _RamadanSuggestionCard extends StatelessWidget {
  final VoidCallback onEnable;

  const _RamadanSuggestionCard({required this.onEnable});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: scheme.secondaryContainer,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: scheme.secondary,
          foregroundColor: scheme.onSecondary,
          child: const Icon(Icons.nightlight_rounded, size: 20),
        ),
        title: Text(l10n.ramadanBannerTitle),
        subtitle: Text(l10n.ramadanBannerSubtitle),
        trailing: FilledButton(onPressed: onEnable, child: Text(l10n.enable)),
      ),
    );
  }
}

class _ImsakIftarCard extends StatelessWidget {
  final PrayerDay prayerDay;

  const _ImsakIftarCard({required this.prayerDay});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final timeFormat = DateFormat.jm();
    final imsak = prayerDay
        .adhanAt(Prayer.fajr)
        .subtract(Duration(minutes: PrayerConfig.imsakBeforeFajrMinutes));
    final iftar = prayerDay.adhanAt(Prayer.maghrib);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _TimeStat(
              icon: Icons.dark_mode_rounded,
              label: l10n.imsakLabel,
              time: timeFormat.format(imsak),
            ),
            _TimeStat(
              icon: Icons.wb_twilight_rounded,
              label: l10n.iftarLabel,
              time: timeFormat.format(iftar),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String time;

  const _TimeStat({
    required this.icon,
    required this.label,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Icon(icon, size: 20, color: scheme.primary),
        const SizedBox(height: 4),
        Text(time, style: Theme.of(context).textTheme.titleMedium),
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
