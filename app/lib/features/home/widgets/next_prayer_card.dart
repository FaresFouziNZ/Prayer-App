import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

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
/// without the live surface. Ticks every second while visible so the
/// countdown and phase stay live without needing a pull-to-refresh; the
/// choice of *which* prayer is "next" still only updates when the Home
/// screen itself rebuilds (app resume, pull-to-refresh, or a fresh log).
class NextPrayerCard extends StatefulWidget {
  final PrayerEvent event;
  final bool isJumuah;

  const NextPrayerCard({super.key, required this.event, required this.isJumuah});

  @override
  State<NextPrayerCard> createState() => _NextPrayerCardState();
}

class _NextPrayerCardState extends State<NextPrayerCard> {
  late Timer _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final timeFormat = DateFormat.jm();
    final event = widget.event;
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
    final countdownTarget = phase == LivePhase.iqamah ? event.iqamahAt : event.endAt;
    final remaining = countdownTarget.difference(now);

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
                  PrayerNames.displayName(context, event.prayer, isJumuah: widget.isJumuah),
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
                const SizedBox(height: 18),
                Text(
                  l10n.timeRemainingLabel.toUpperCase(),
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: onContainer.withValues(alpha: 0.75)),
                ),
                const SizedBox(height: 2),
                _CountdownDigits(remaining: remaining, color: onContainer),
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

/// A digital "H:MM:SS" (or "MM:SS" under an hour) readout. Tabular figures
/// keep the digits from jittering horizontally as they tick.
class _CountdownDigits extends StatelessWidget {
  final Duration remaining;
  final Color color;

  const _CountdownDigits({required this.remaining, required this.color});

  @override
  Widget build(BuildContext context) {
    final clamped = remaining.isNegative ? Duration.zero : remaining;
    final hours = clamped.inHours;
    final minutes = clamped.inMinutes.remainder(60);
    final seconds = clamped.inSeconds.remainder(60);
    final text = hours > 0
        ? '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}'
        : '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    return Text(
      text,
      textDirection: TextDirection.ltr,
      style: Theme.of(context).textTheme.displaySmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
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
