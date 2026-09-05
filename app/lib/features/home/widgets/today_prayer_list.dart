import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/prayer_names.dart';
import '../../../app/theme.dart';
import '../../../domain/prayer_engine/prayer.dart';
import '../../../domain/schedule/prayer_event.dart';
import '../../../domain/tracker/prayer_log_entry.dart';
import '../../../domain/tracker/prayer_status.dart';
import '../../../domain/tracker/tracker_rules.dart';
import '../../../l10n/app_localizations.dart';

/// One row per prayer with its adhan time and logged status; tapping a row
/// opens the logging sheet (SRS FR-TR-03: "one tap per prayer"). Re-opening
/// an already-logged prayer edits it in place — status, note, or deletion
/// (FR-TR-05, FR-TR-08). Dhuhr and Maghrib also offer combining with their
/// jam' partner when travelling (FR-TR-06).
class TodayPrayerList extends StatelessWidget {
  final List<PrayerEvent> events;
  final Map<Prayer, PrayerLogEntry> logsByPrayer;
  final bool isFriday;
  final void Function(Prayer prayer, PrayerStatus status, String? note) onLog;
  final void Function(Prayer prayer) onDelete;
  final void Function(Prayer first, Prayer second, PrayerStatus status) onCombine;

  const TodayPrayerList({
    super.key,
    required this.events,
    required this.logsByPrayer,
    required this.isFriday,
    required this.onLog,
    required this.onDelete,
    required this.onCombine,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final timeFormat = DateFormat.jm();
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final (index, event) in events.indexed) ...[
            if (index > 0) Divider(height: 1, indent: 72, color: scheme.outlineVariant),
            Builder(builder: (context) {
              final log = logsByPrayer[event.prayer];
              final isJumuah = isFriday && event.prayer == Prayer.dhuhr;
              final subtitleParts = [
                l10n.adhanAtLabel(timeFormat.format(event.adhanAt)),
                if (log?.note != null && log!.note!.isNotEmpty) log.note!,
                if (log?.combinedWith != null)
                  l10n.combinedWithLabel(
                    PrayerNames.displayName(context, _parsePrayer(log!.combinedWith!)),
                  ),
              ];
              return ListTile(
                shape: const RoundedRectangleBorder(),
                leading: CircleAvatar(
                  radius: 22,
                  backgroundColor: PrayerColors.containerOf(scheme, log?.status),
                  foregroundColor: PrayerColors.onContainerOf(scheme, log?.status),
                  child: Icon(PrayerColors.iconOf(log?.status), size: 22),
                ),
                title: Text(PrayerNames.displayName(context, event.prayer, isJumuah: isJumuah)),
                subtitle: Text(subtitleParts.join(' · ')),
                trailing: _StatusChip(status: log?.status),
                onTap: () => _openLogSheet(context, event.prayer, log, isJumuah),
              );
            }),
          ],
        ],
      ),
    );
  }

  Prayer _parsePrayer(String name) => Prayer.values.firstWhere((p) => p.name == name);

  void _openLogSheet(
    BuildContext context,
    Prayer prayer,
    PrayerLogEntry? existing,
    bool isJumuah,
  ) {
    final partner = TrackerRules.combinablePartner(prayer);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _LogSheet(
        prayer: prayer,
        isJumuah: isJumuah,
        existing: existing,
        combinePartner: partner,
        onSave: (status, note) => onLog(prayer, status, note),
        onDelete: existing == null ? null : () => onDelete(prayer),
        onCombine: partner == null
            ? null
            : (status) => onCombine(prayer, partner, status),
      ),
    );
  }
}

class _LogSheet extends StatefulWidget {
  final Prayer prayer;
  final bool isJumuah;
  final PrayerLogEntry? existing;
  final Prayer? combinePartner;
  final void Function(PrayerStatus status, String? note) onSave;
  final VoidCallback? onDelete;
  final void Function(PrayerStatus status)? onCombine;

  const _LogSheet({
    required this.prayer,
    required this.isJumuah,
    required this.existing,
    required this.combinePartner,
    required this.onSave,
    required this.onDelete,
    required this.onCombine,
  });

  @override
  State<_LogSheet> createState() => _LogSheetState();
}

class _LogSheetState extends State<_LogSheet> {
  late PrayerStatus? _status = widget.existing?.status;
  late final _noteController = TextEditingController(text: widget.existing?.note);
  bool _combining = false;

  static const _combinableStatuses = [PrayerStatus.jamaah, PrayerStatus.onTimeAlone];

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final statusOptions = _combining ? _combinableStatuses : PrayerStatus.values;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              PrayerNames.displayName(context, widget.prayer, isJumuah: widget.isJumuah),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final status in statusOptions)
                  ChoiceChip(
                    label: Text(_statusLabel(l10n, status)),
                    selected: _status == status,
                    onSelected: (_) => setState(() => _status = status),
                  ),
              ],
            ),
            if (widget.onCombine != null) ...[
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                  l10n.travellingCombineLabel(
                    PrayerNames.displayName(context, widget.combinePartner!),
                  ),
                ),
                value: _combining,
                onChanged: (checked) => setState(() {
                  _combining = checked ?? false;
                  if (_combining && !_combinableStatuses.contains(_status)) {
                    _status = null;
                  }
                }),
              ),
            ],
            const SizedBox(height: 8),
            TextField(
              controller: _noteController,
              decoration: InputDecoration(
                labelText: l10n.noteOptionalLabel,
                border: const OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (widget.onDelete != null)
                  TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onDelete!();
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: Text(l10n.delete),
                  ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.cancel),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _status == null
                      ? null
                      : () {
                          Navigator.of(context).pop();
                          if (_combining) {
                            widget.onCombine!(_status!);
                            return;
                          }
                          final note = _noteController.text.trim();
                          widget.onSave(_status!, note.isEmpty ? null : note);
                        },
                  child: Text(l10n.save),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(AppLocalizations l10n, PrayerStatus status) {
    switch (status) {
      case PrayerStatus.jamaah:
        return l10n.statusJamaah;
      case PrayerStatus.onTimeAlone:
        return l10n.statusOnTimeAlone;
      case PrayerStatus.late:
        return l10n.statusLate;
      case PrayerStatus.missed:
        return l10n.statusMissed;
    }
  }
}

class _StatusChip extends StatelessWidget {
  final PrayerStatus? status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final label = switch (status) {
      null => l10n.statusNotLogged,
      PrayerStatus.jamaah => l10n.statusJamaah,
      PrayerStatus.onTimeAlone => l10n.statusOnTimeAlone,
      PrayerStatus.late => l10n.statusLate,
      PrayerStatus.missed => l10n.statusMissed,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: PrayerColors.containerOf(scheme, status),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: PrayerColors.onContainerOf(scheme, status),
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
