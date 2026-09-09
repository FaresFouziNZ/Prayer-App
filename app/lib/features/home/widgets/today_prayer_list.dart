import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/prayer_names.dart';
import '../../../app/theme.dart';
import '../../../domain/prayer_engine/prayer.dart';
import '../../../domain/schedule/prayer_event.dart';
import '../../../domain/tracker/prayer_excuse.dart';
import '../../../domain/tracker/prayer_log_entry.dart';
import '../../../domain/tracker/prayer_status.dart';
import '../../../domain/tracker/tracker_rules.dart';
import '../../../l10n/app_localizations.dart';

/// One row per prayer with its adhan time and logged status; tapping a row
/// opens the logging sheet (SRS FR-TR-03: "one tap per prayer"). Re-opening
/// an already-logged prayer edits it in place — status or deletion
/// (FR-TR-05). Dhuhr and Maghrib also offer combining with their jam'
/// partner when travelling (FR-TR-06).
class TodayPrayerList extends StatelessWidget {
  final List<PrayerEvent> events;
  final Map<Prayer, PrayerLogEntry> logsByPrayer;
  final bool isFriday;
  final void Function(Prayer prayer, PrayerStatus status, PrayerExcuse? excuse)
  onLog;
  final void Function(Prayer prayer) onDelete;
  final void Function(Prayer first, Prayer second, PrayerStatus status)
  onCombine;

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
            if (index > 0)
              Divider(height: 1, indent: 72, color: scheme.outlineVariant),
            Builder(
              builder: (context) {
                final log = logsByPrayer[event.prayer];
                final isJumuah = isFriday && event.prayer == Prayer.dhuhr;
                final subtitleParts = [
                  l10n.adhanAtLabel(timeFormat.format(event.adhanAt)),
                  if (log?.combinedWith != null)
                    l10n.combinedWithLabel(
                      PrayerNames.displayName(
                        context,
                        _parsePrayer(log!.combinedWith!),
                      ),
                    ),
                ];
                return ListTile(
                  shape: const RoundedRectangleBorder(),
                  leading: CircleAvatar(
                    radius: 22,
                    backgroundColor: PrayerColors.containerOf(
                      scheme,
                      log?.status,
                    ),
                    foregroundColor: PrayerColors.onContainerOf(
                      scheme,
                      log?.status,
                    ),
                    child: Icon(PrayerColors.iconOf(log?.status), size: 22),
                  ),
                  title: Text(
                    PrayerNames.displayName(
                      context,
                      event.prayer,
                      isJumuah: isJumuah,
                    ),
                  ),
                  subtitle: Text(subtitleParts.join(' · ')),
                  trailing: _StatusChip(status: log?.status),
                  onTap: () =>
                      _openLogSheet(context, event.prayer, log, isJumuah),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Prayer _parsePrayer(String name) =>
      Prayer.values.firstWhere((p) => p.name == name);

  void _openLogSheet(
    BuildContext context,
    Prayer prayer,
    PrayerLogEntry? existing,
    bool isJumuah,
  ) {
    final partner = TrackerRules.combinablePartner(prayer);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _LogSheet(
        prayer: prayer,
        isJumuah: isJumuah,
        existing: existing,
        combinePartner: partner,
        onSave: (status, excuse) => onLog(prayer, status, excuse),
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
  final void Function(PrayerStatus status, PrayerExcuse? excuse) onSave;
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
  late PrayerExcuse? _excuse = widget.existing?.excuse;
  bool _combining = false;

  static const _combinableStatuses = [
    PrayerStatus.jamaah,
    PrayerStatus.onTimeAlone,
  ];
  static const _excusableStatuses = [PrayerStatus.late, PrayerStatus.missed];

  bool get _needsExcuse => _excusableStatuses.contains(_status);

  /// Picking a status is the last tap needed — no separate Save button.
  /// The combine checkbox sits *above* the status chips for exactly this
  /// reason: it has to be set before the terminal tap, since there's no
  /// later step left to change your mind in.
  void _selectStatus(PrayerStatus status) {
    setState(() {
      _status = status;
      if (!_excusableStatuses.contains(status)) _excuse = null;
    });
    _maybeCommit();
  }

  void _selectExcuse(PrayerExcuse excuse) {
    setState(() => _excuse = excuse);
    _maybeCommit();
  }

  void _toggleCombine(bool checked) {
    setState(() {
      _combining = checked;
      if (_combining && !_combinableStatuses.contains(_status)) {
        _status = null;
      }
    });
    _maybeCommit();
  }

  void _maybeCommit() {
    if (_status == null) return;
    if (_combining) {
      Navigator.of(context).pop();
      widget.onCombine!(_status!);
      return;
    }
    if (_needsExcuse && _excuse == null) return;
    Navigator.of(context).pop();
    widget.onSave(_status!, _needsExcuse ? _excuse : null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final statusOptions = _combining
        ? _combinableStatuses
        : PrayerStatus.values;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              PrayerNames.displayName(
                context,
                widget.prayer,
                isJumuah: widget.isJumuah,
              ),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (widget.onCombine != null) ...[
              const SizedBox(height: 4),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                  l10n.travellingCombineLabel(
                    PrayerNames.displayName(context, widget.combinePartner!),
                  ),
                ),
                value: _combining,
                onChanged: (checked) => _toggleCombine(checked ?? false),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final status in statusOptions)
                  ChoiceChip(
                    label: Text(_statusLabel(l10n, status)),
                    selected: _status == status,
                    onSelected: (_) => _selectStatus(status),
                  ),
              ],
            ),
            if (_needsExcuse) ...[
              const SizedBox(height: 12),
              Text(
                l10n.reasonPromptLabel,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final excuse in PrayerExcuse.values)
                    ChoiceChip(
                      label: Text(_excuseLabel(l10n, excuse)),
                      selected: _excuse == excuse,
                      onSelected: (_) => _selectExcuse(excuse),
                    ),
                ],
              ),
            ],
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

  String _excuseLabel(AppLocalizations l10n, PrayerExcuse excuse) {
    switch (excuse) {
      case PrayerExcuse.overslept:
        return l10n.excuseOverslept;
      case PrayerExcuse.busy:
        return l10n.excuseBusy;
      case PrayerExcuse.forgot:
        return l10n.excuseForgot;
      case PrayerExcuse.travel:
        return l10n.excuseTravel;
      case PrayerExcuse.sick:
        return l10n.excuseSick;
      case PrayerExcuse.other:
        return l10n.excuseOther;
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
