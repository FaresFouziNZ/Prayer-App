import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../l10n/app_localizations.dart';

/// A switch marking [date] as a menstrual period day (opt-in via Settings,
/// product decision 2026-09-07) — a woman isn't obligated to pray on these
/// days, so marking one excuses its prayers instead of letting them pile up
/// as `not logged`/`missed`. Shared by Home (today) and the day-detail
/// backfill screen (a day can be marked after the fact too).
class PeriodDayToggle extends ConsumerWidget {
  final DateTime date;

  const PeriodDayToggle({super.key, required this.date});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final isPeriod = ref.watch(dayIsPeriodProvider(date)).value ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: SwitchListTile(
        secondary: Icon(Icons.water_drop_outlined, color: scheme.primary),
        title: Text(l10n.periodDayLabel),
        subtitle: isPeriod ? Text(l10n.periodDayExcusedSubtitle) : null,
        value: isPeriod,
        onChanged: (value) =>
            ref.read(periodRepositoryProvider).setPeriodDay(date, value),
      ),
    );
  }
}

/// Replaces the prayer list on a marked period day, so there's nothing left
/// to accidentally log as missed.
class PeriodExcusedNotice extends StatelessWidget {
  const PeriodExcusedNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.water_drop_rounded, color: scheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.periodDayExcusedTitle,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.periodDayExcusedMessage,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
