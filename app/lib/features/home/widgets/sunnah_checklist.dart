import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/sunnah_labels.dart';
import '../../../config/settings_keys.dart';
import '../../../domain/tracker/sunnah.dart';
import '../../../l10n/app_localizations.dart';

/// Rawatib toggles for one day, on the same screen as prayer logging
/// (SRS FR-SN-01, FR-SN-02). Editable for any past day too (AC-SN-1).
/// Collapsible — these are optional, so the header alone (with a live
/// done-count) can stand in for the full checklist once collapsed.
class SunnahChecklist extends ConsumerWidget {
  final DateTime date;

  const SunnahChecklist({super.key, required this.date});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final labels = sunnahLabels(l10n);
    final sunnahAsync = ref.watch(daySunnahProvider(date));
    final collapsed = ref.watch(sunnahChecklistCollapsedProvider).value ?? false;

    return sunnahAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (error, stack) => Text(l10n.errorLabel(error.toString())),
      data: (entries) {
        final doneByItem = {for (final e in entries) e.item: e.done};
        final doneCount = doneByItem.values.where((done) => done).length;
        final scheme = Theme.of(context).colorScheme;
        return Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () async {
                  await ref
                      .read(settingsRepositoryProvider)
                      .setBool(SettingsKeys.sunnahChecklistCollapsed, !collapsed);
                  ref.invalidate(sunnahChecklistCollapsedProvider);
                },
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
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
                      AnimatedRotation(
                        duration: const Duration(milliseconds: 200),
                        turns: collapsed ? 0 : 0.5,
                        child: Icon(
                          Icons.expand_more_rounded,
                          size: 20,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                alignment: Alignment.topCenter,
                child: collapsed
                    ? const SizedBox(width: double.infinity)
                    : Column(
                        children: [
                          for (final item in SunnahItem.values)
                            CheckboxListTile(
                              dense: true,
                              controlAffinity: ListTileControlAffinity.leading,
                              title: Text(labels[item]!),
                              value: doneByItem[item] ?? false,
                              onChanged: (checked) =>
                                  ref.read(sunnahRepositoryProvider).setDone(
                                        date: date,
                                        item: item,
                                        done: checked ?? false,
                                      ),
                            ),
                          const SizedBox(height: 4),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
