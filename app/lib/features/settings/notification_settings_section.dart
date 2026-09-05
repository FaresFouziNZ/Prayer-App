import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/notification_coordinator.dart';
import '../../app/prayer_names.dart';
import '../../app/providers.dart';
import '../../config/prayer_config.dart';
import '../../config/settings_keys.dart';
import '../../domain/prayer_engine/prayer.dart';
import '../../l10n/app_localizations.dart';
import '../../platform/dnd/dnd_service.dart';

/// Per-prayer notification toggles/sound, the pre-adhan offset, and the
/// optional Android DND-during-prayer setting (SRS FR-NT-01, FR-NT-02,
/// FR-NT-03, FR-NT-08).
class NotificationSettingsSection extends ConsumerWidget {
  const NotificationSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final valuesAsync = ref.watch(_notificationSettingsProvider);

    return valuesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (error, stack) => Text(l10n.errorLabel(error.toString())),
      data: (values) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final prayer in Prayer.values)
            _PrayerNotificationTile(
              label: PrayerNames.displayName(context, prayer),
              enabled: values.enabled[prayer]!,
              silent: values.silent[prayer]!,
              onEnabledChanged: (v) => _setEnabled(context, ref, prayer, v),
              onSilentChanged: (v) => _setSilent(context, ref, prayer, v),
            ),
          ListTile(
            title: Text(l10n.preAdhanOffsetLabel),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: values.preAdhanOffsetMinutes > 0
                      ? () =>
                          _setPreAdhanOffset(context, ref, values.preAdhanOffsetMinutes - 5)
                      : null,
                ),
                Text('${values.preAdhanOffsetMinutes}'),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () =>
                      _setPreAdhanOffset(context, ref, values.preAdhanOffsetMinutes + 5),
                ),
              ],
            ),
          ),
          SwitchListTile(
            title: Text(l10n.dndDuringPrayerLabel),
            value: values.dndEnabled,
            onChanged: (v) => _setDndEnabled(context, ref, v),
          ),
          if (values.dndEnabled)
            ListTile(
              title: Text(l10n.dndDurationLabel),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: values.dndDurationMinutes > 5
                        ? () => _setDndDuration(context, ref, values.dndDurationMinutes - 5)
                        : null,
                  ),
                  Text('${values.dndDurationMinutes}'),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () =>
                        _setDndDuration(context, ref, values.dndDurationMinutes + 5),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _setEnabled(BuildContext context, WidgetRef ref, Prayer prayer, bool value) async {
    final container = ProviderScope.containerOf(context);
    await ref
        .read(settingsRepositoryProvider)
        .setBool(SettingsKeys.notifyEnabled(prayer.name), value);
    await _refresh(container, ref);
  }

  Future<void> _setSilent(BuildContext context, WidgetRef ref, Prayer prayer, bool silent) async {
    final container = ProviderScope.containerOf(context);
    await ref
        .read(settingsRepositoryProvider)
        .setString(SettingsKeys.notifySound(prayer.name), silent ? 'silent' : 'default');
    await _refresh(container, ref);
  }

  Future<void> _setPreAdhanOffset(BuildContext context, WidgetRef ref, int minutes) async {
    final container = ProviderScope.containerOf(context);
    await ref
        .read(settingsRepositoryProvider)
        .setInt(SettingsKeys.preAdhanOffsetMinutes, minutes);
    ref.invalidate(daySnapshotProvider);
    await _refresh(container, ref);
  }

  Future<void> _setDndEnabled(BuildContext context, WidgetRef ref, bool value) async {
    final container = ProviderScope.containerOf(context);
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    if (value) {
      final granted = await DndService().isPermissionGranted();
      if (!granted) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.dndPermissionRequiredError)));
        await DndService().openPermissionSettings();
        return;
      }
    }
    await ref.read(settingsRepositoryProvider).setBool(SettingsKeys.dndDuringPrayer, value);
    await _refresh(container, ref);
  }

  Future<void> _setDndDuration(BuildContext context, WidgetRef ref, int minutes) async {
    final container = ProviderScope.containerOf(context);
    await ref.read(settingsRepositoryProvider).setInt(SettingsKeys.dndDurationMinutes, minutes);
    await _refresh(container, ref);
  }

  Future<void> _refresh(ProviderContainer container, WidgetRef ref) async {
    ref.invalidate(_notificationSettingsProvider);
    await NotificationCoordinator.scheduleUpcomingWindow(container);
  }
}

class _PrayerNotificationTile extends StatelessWidget {
  final String label;
  final bool enabled;
  final bool silent;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<bool> onSilentChanged;

  const _PrayerNotificationTile({
    required this.label,
    required this.enabled,
    required this.silent,
    required this.onEnabledChanged,
    required this.onSilentChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListTile(
      title: Text(label),
      subtitle: enabled
          ? SegmentedButton<bool>(
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              segments: [
                ButtonSegment(value: false, label: Text(l10n.soundDefault)),
                ButtonSegment(value: true, label: Text(l10n.soundSilent)),
              ],
              selected: {silent},
              onSelectionChanged: (selection) => onSilentChanged(selection.first),
            )
          : null,
      trailing: Switch(value: enabled, onChanged: onEnabledChanged),
    );
  }
}

class _NotificationSettingsValues {
  final Map<Prayer, bool> enabled;
  final Map<Prayer, bool> silent;
  final int preAdhanOffsetMinutes;
  final bool dndEnabled;
  final int dndDurationMinutes;

  const _NotificationSettingsValues({
    required this.enabled,
    required this.silent,
    required this.preAdhanOffsetMinutes,
    required this.dndEnabled,
    required this.dndDurationMinutes,
  });
}

final _notificationSettingsProvider =
    FutureProvider<_NotificationSettingsValues>((ref) async {
  final settings = ref.watch(settingsRepositoryProvider);
  final enabled = <Prayer, bool>{};
  final silent = <Prayer, bool>{};
  for (final prayer in Prayer.values) {
    enabled[prayer] =
        await settings.getBool(SettingsKeys.notifyEnabled(prayer.name)) ?? true;
    silent[prayer] =
        (await settings.getString(SettingsKeys.notifySound(prayer.name)) ?? 'default') ==
            'silent';
  }

  return _NotificationSettingsValues(
    enabled: enabled,
    silent: silent,
    preAdhanOffsetMinutes: await settings.getInt(SettingsKeys.preAdhanOffsetMinutes) ??
        PrayerConfig.defaultPreAdhanOffsetMinutes,
    dndEnabled: await settings.getBool(SettingsKeys.dndDuringPrayer) ?? false,
    dndDurationMinutes: await settings.getInt(SettingsKeys.dndDurationMinutes) ?? 15,
  );
});
