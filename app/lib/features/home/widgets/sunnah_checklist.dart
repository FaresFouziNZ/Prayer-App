import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/sunnah_labels.dart';
import '../../../domain/tracker/sunnah.dart';
import '../../../l10n/app_localizations.dart';

/// Rawatib toggles for one day, on the same screen as prayer logging
/// (SRS FR-SN-01, FR-SN-02). Editable for any past day too (AC-SN-1).
class SunnahChecklist extends ConsumerWidget {
  final DateTime date;

  const SunnahChecklist({super.key, required this.date});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final labels = sunnahLabels(l10n);
    final sunnahAsync = ref.watch(daySunnahProvider(date));

    return sunnahAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (error, stack) => Text(l10n.errorLabel(error.toString())),
      data: (entries) {
        final doneByItem = {for (final e in entries) e.item: e.done};
        final doneCount = doneByItem.values.where((done) => done).length;
        final scheme = Theme.of(context).colorScheme;
        return Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      Icon(Icons.nights_stay_rounded, size: 18, color: scheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.sunnahTitle,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      Text(
                        l10n.sunnahProgressLabel(doneCount, SunnahItem.values.length),
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                for (final item in SunnahItem.values)
                  CheckboxListTile(
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(labels[item]!),
                    value: doneByItem[item] ?? false,
                    onChanged: (checked) => ref.read(sunnahRepositoryProvider).setDone(
                          date: date,
                          item: item,
                          done: checked ?? false,
                        ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
