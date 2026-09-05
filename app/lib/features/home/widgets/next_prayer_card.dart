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
/// scope for this skeleton. The card's tint tracks the same phase (iqamah
/// → window → closing) so the "urgency" read is visible at a glance even
/// without the live surface.
class NextPrayerCard extends StatelessWidget {
  final PrayerEvent event;
  final bool isJumuah;

  const NextPrayerCard({super.key, required this.event, required this.isJumuah});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final timeFormat = DateFormat.jm();
    final now = DateTime.now();
    final phase = event.phaseAt(now);
    final phaseLabel = switch (phase) {
      LivePhase.iqamah => l10n.iqamahAtLabel(timeFormat.format(event.iqamahAt)),
      LivePhase.window => l10n.windowClosesAtLabel(timeFormat.format(event.endAt)),
      LivePhase.closing => l10n.closingSoonLabel,
    };
    final (container, onContainer) = switch (phase) {
      LivePhase.iqamah => (scheme.primaryContainer, scheme.onPrimaryContainer),
      LivePhase.window => (scheme.tertiaryContainer, scheme.onTertiaryContainer),
      LivePhase.closing => (scheme.secondaryContainer, scheme.onSecondaryContainer),
    };

    return Card(
      clipBehavior: Clip.antiAlias,
      color: container,
      child: Stack(
        children: [
          Positioned(
            right: -18,
            bottom: -18,
            child: Icon(Icons.mosque_rounded, size: 120, color: onContainer.withValues(alpha: 0.12)),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.nextPrayerLabel.toUpperCase(),
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: onContainer.withValues(alpha: 0.75)),
                ),
                const SizedBox(height: 6),
                Text(
                  PrayerNames.displayName(context, event.prayer, isJumuah: isJumuah),
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(color: onContainer),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.adhanAtLabel(timeFormat.format(event.adhanAt)),
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: onContainer.withValues(alpha: 0.85)),
                ),
                const SizedBox(height: 16),
                _InfoRow(icon: Icons.notifications_active_rounded, label: phaseLabel, color: onContainer),
                const SizedBox(height: 6),
                _InfoRow(
                  icon: Icons.directions_walk_rounded,
                  label: l10n.leaveByLabel(timeFormat.format(event.leaveByAt)),
                  color: onContainer,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoRow({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color.withValues(alpha: 0.85)),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: color),
        ),
      ],
    );
  }
}
