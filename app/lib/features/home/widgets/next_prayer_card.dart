import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/prayer_names.dart';
import '../../../domain/schedule/prayer_event.dart';
import '../../../l10n/app_localizations.dart';

/// Highlights the next upcoming prayer with a countdown-style summary.
///
/// SRS FR-LA describes a true live countdown surface (lock screen / Dynamic
/// Island / ongoing notification); this in-app card is the same content
/// model rendered as a normal widget while that native surface is out of
/// scope for this skeleton.
class NextPrayerCard extends StatelessWidget {
  final PrayerEvent event;
  final bool isJumuah;

  const NextPrayerCard({super.key, required this.event, required this.isJumuah});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final timeFormat = DateFormat.jm();
    final now = DateTime.now();
    final phase = event.phaseAt(now);
    final phaseLabel = switch (phase) {
      LivePhase.iqamah => l10n.iqamahAtLabel(timeFormat.format(event.iqamahAt)),
      LivePhase.window => l10n.windowClosesAtLabel(timeFormat.format(event.endAt)),
      LivePhase.closing => l10n.closingSoonLabel,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              PrayerNames.displayName(context, event.prayer, isJumuah: isJumuah),
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            Text(
              l10n.adhanAtLabel(timeFormat.format(event.adhanAt)),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(phaseLabel, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 4),
            Text(
              l10n.leaveByLabel(timeFormat.format(event.leaveByAt)),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
