import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/prayer_names.dart';
import '../../app/providers.dart';
import '../../domain/prayer_engine/prayer.dart';
import '../../domain/qada/qada_balance.dart';
import '../../domain/qada/qada_payment.dart';
import '../../domain/qada/qada_plan.dart';
import '../../domain/tracker/prayer_log_entry.dart';
import '../../l10n/app_localizations.dart';

/// SRS FR-QD: balances derived from missed records, payments, and an
/// opening balance; never stored directly. Also exposes the opening
/// balance (FR-QD-03) and a simple clearance plan (FR-QD-04).
class QadaScreen extends ConsumerStatefulWidget {
  const QadaScreen({super.key});

  @override
  ConsumerState<QadaScreen> createState() => _QadaScreenState();
}

class _QadaScreenState extends ConsumerState<QadaScreen> {
  int _targetPerDay = 1;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final balances = ref.watch(_qadaBalancesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.qadaTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.secondaryContainer,
                foregroundColor: Theme.of(
                  context,
                ).colorScheme.onSecondaryContainer,
                child: const Icon(Icons.flag_rounded),
              ),
              title: Text(l10n.qadaPlanLabel),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: _targetPerDay > 1
                        ? () => setState(() => _targetPerDay--)
                        : null,
                  ),
                  Text(
                    '$_targetPerDay',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => setState(() => _targetPerDay++),
                  ),
                ],
              ),
            ),
          ),
          for (final prayer in Prayer.values)
            _QadaTile(
              prayer: prayer,
              balance: balances[prayer] ?? 0,
              targetPerDay: _targetPerDay,
              onRecordPayment: () => _recordPayment(context, ref, prayer),
              onSetOpeningBalance: () => _setOpeningBalance(
                context,
                ref,
                prayer,
                balances[prayer] ?? 0,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _recordPayment(
    BuildContext context,
    WidgetRef ref,
    Prayer prayer,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final count = await showDialog<int>(
      context: context,
      builder: (context) => _CountDialog(
        title: l10n.recordPaymentTitle(
          PrayerNames.displayName(context, prayer),
        ),
        label: l10n.countLabel,
        initial: 1,
      ),
    );
    if (count == null || count <= 0) return;
    await ref
        .read(qadaRepositoryProvider)
        .recordPayment(
          prayer: prayer,
          count: count,
          date: ref.read(todayProvider),
        );
  }

  Future<void> _setOpeningBalance(
    BuildContext context,
    WidgetRef ref,
    Prayer prayer,
    int currentBalance,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final count = await showDialog<int>(
      context: context,
      builder: (context) => _CountDialog(
        title: l10n.setOpeningBalanceTitle(
          PrayerNames.displayName(context, prayer),
        ),
        label: l10n.openingBalanceHint,
        initial: currentBalance,
        allowZero: true,
      ),
    );
    if (count == null || count < 0) return;
    await ref.read(qadaRepositoryProvider).setOpeningBalance(prayer, count);
  }
}

class _QadaTile extends StatelessWidget {
  final Prayer prayer;
  final int balance;
  final int targetPerDay;
  final VoidCallback onRecordPayment;
  final VoidCallback onSetOpeningBalance;

  const _QadaTile({
    required this.prayer,
    required this.balance,
    required this.targetPerDay,
    required this.onRecordPayment,
    required this.onSetOpeningBalance,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final cleared = balance == 0;
    final (container, onContainer) = cleared
        ? (scheme.primaryContainer, scheme.onPrimaryContainer)
        : (scheme.secondaryContainer, scheme.onSecondaryContainer);

    String? subtitle;
    if (balance > 0) {
      final plan = QadaPlan(
        prayer: prayer,
        currentBalance: balance,
        targetPerDay: targetPerDay,
      );
      subtitle = l10n.clearByLabel(
        DateFormat.yMMMd().format(plan.projectedClearanceDate()),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: container,
          foregroundColor: onContainer,
          child: Icon(cleared ? Icons.check_rounded : Icons.balance_rounded),
        ),
        title: Text(PrayerNames.displayName(context, prayer)),
        subtitle: subtitle == null ? null : Text(subtitle),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$balance',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: cleared ? scheme.onSurfaceVariant : scheme.secondary,
                fontWeight: FontWeight.w700,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.tune),
              tooltip: l10n.setOpeningBalanceTooltip,
              onPressed: onSetOpeningBalance,
            ),
          ],
        ),
        onTap: onRecordPayment,
      ),
    );
  }
}

/// Reactive sources feeding [_qadaBalancesProvider] — [StreamProvider]s
/// (not one-shot futures) so the balance recomputes as soon as a prayer is
/// (re)logged, a payment is recorded, or an opening balance changes,
/// instead of only reflecting whatever was true when Qada was first opened.
final _qadaLogsProvider = StreamProvider<List<PrayerLogEntry>>((ref) {
  return ref
      .watch(prayerLogRepositoryProvider)
      .watchBetween(DateTime(1970), DateTime.now());
});

final _qadaPaymentsProvider = StreamProvider<List<QadaPayment>>((ref) {
  return ref.watch(qadaRepositoryProvider).watchAllPayments();
});

final _qadaOpeningBalancesProvider = StreamProvider<Map<Prayer, int>>((ref) {
  return ref.watch(qadaRepositoryProvider).watchOpeningBalances();
});

final _qadaBalancesProvider = Provider<Map<Prayer, int>>((ref) {
  return QadaBalance.compute(
    logs: ref.watch(_qadaLogsProvider).value ?? const [],
    payments: ref.watch(_qadaPaymentsProvider).value ?? const [],
    openingBalances: ref.watch(_qadaOpeningBalancesProvider).value ?? const {},
    excludedDays: ref.watch(periodDaysProvider).value ?? const {},
  );
});

class _CountDialog extends StatefulWidget {
  final String title;
  final String label;
  final int initial;
  final bool allowZero;

  const _CountDialog({
    required this.title,
    required this.label,
    required this.initial,
    this.allowZero = false,
  });

  @override
  State<_CountDialog> createState() => _CountDialogState();
}

class _CountDialogState extends State<_CountDialog> {
  late final _controller = TextEditingController(text: '${widget.initial}');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        keyboardType: TextInputType.number,
        autofocus: true,
        decoration: InputDecoration(labelText: widget.label),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () {
            final value = int.tryParse(_controller.text);
            if (value == null) return;
            if (value < 0 || (value == 0 && !widget.allowZero)) return;
            Navigator.of(context).pop(value);
          },
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
