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
import 'widgets/sunnah_checklist.dart';
import 'widgets/today_prayer_list.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final today = ref.watch(todayProvider);
    final snapshotAsync = ref.watch(daySnapshotProvider(today));
    final logsAsync = ref.watch(dayLogsProvider(today));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.homeTitle)),
      body: snapshotAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text(l10n.errorLabel(error.toString()))),
        data: (snapshot) {
          final now = DateTime.now();
          final nextEvent = snapshot.events.firstWhere(
            (event) => event.endAt.isAfter(now),
            orElse: () => snapshot.events.last,
          );

          return logsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(child: Text(l10n.errorLabel(error.toString()))),
            data: (logs) {
              final logsByPrayer = {for (final log in logs) log.prayer: log};
              return RefreshIndicator(
                onRefresh: () => ref.refresh(daySnapshotProvider(today).future),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (snapshot.suggestRamadanMode)
                      _RamadanSuggestionCard(
                        onEnable: () async {
                          await ref
                              .read(settingsRepositoryProvider)
                              .setBool(SettingsKeys.ramadanMode, true);
                          ref.invalidate(daySnapshotProvider);
                        },
                      ),
                    if (snapshot.ramadanMode) _ImsakIftarCard(prayerDay: snapshot.prayerDay),
                    NextPrayerCard(event: nextEvent, isJumuah: snapshot.prayerDay.isJumuah),
                    const SizedBox(height: 16),
                    TodayPrayerList(
                      events: snapshot.events,
                      logsByPrayer: logsByPrayer,
                      isFriday: snapshot.prayerDay.isJumuah,
                      onLog: (prayer, status, note) => PrayerLogActions.save(
                        ref,
                        date: today,
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
                        date: today,
                        first: first,
                        second: second,
                        status: status,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SunnahChecklist(date: today),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _RamadanSuggestionCard extends StatelessWidget {
  final VoidCallback onEnable;

  const _RamadanSuggestionCard({required this.onEnable});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: ListTile(
        leading: const Icon(Icons.nightlight_outlined),
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
            _TimeStat(label: l10n.imsakLabel, time: timeFormat.format(imsak)),
            _TimeStat(label: l10n.iftarLabel, time: timeFormat.format(iftar)),
          ],
        ),
      ),
    );
  }
}

class _TimeStat extends StatelessWidget {
  final String label;
  final String time;

  const _TimeStat({required this.label, required this.time});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(time, style: Theme.of(context).textTheme.titleMedium),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
