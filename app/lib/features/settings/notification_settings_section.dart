import 'dart:io' show File, Platform;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../app/notification_coordinator.dart';
import '../../app/prayer_names.dart';
import '../../app/providers.dart';
import '../../config/prayer_config.dart';
import '../../config/settings_keys.dart';
import '../../domain/prayer_engine/prayer.dart';
import '../../l10n/app_localizations.dart';
import '../../platform/dnd/dnd_service.dart';
import '../../platform/notifications/notification_scheduler.dart';
import '../../platform/sound/sound_picker.dart';

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
              soundMode: values.soundMode[prayer]!,
              allowCustomSound: Platform.isAndroid,
              onEnabledChanged: (v) => _setEnabled(context, ref, prayer, v),
              onSoundModeChanged: (mode) =>
                  _setSoundMode(context, ref, prayer, mode),
              onCustomSoundRequested: () => _requestCustomSound(
                context,
                ref,
                prayer,
                values.customSoundUri[prayer],
              ),
            ),
          ListTile(
            title: Text(l10n.preAdhanOffsetLabel),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: values.preAdhanOffsetMinutes > 0
                      ? () => _setPreAdhanOffset(
                          context,
                          ref,
                          values.preAdhanOffsetMinutes - 5,
                        )
                      : null,
                ),
                Text('${values.preAdhanOffsetMinutes}'),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _setPreAdhanOffset(
                    context,
                    ref,
                    values.preAdhanOffsetMinutes + 5,
                  ),
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
                        ? () => _setDndDuration(
                            context,
                            ref,
                            values.dndDurationMinutes - 5,
                          )
                        : null,
                  ),
                  Text('${values.dndDurationMinutes}'),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => _setDndDuration(
                      context,
                      ref,
                      values.dndDurationMinutes + 5,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _setEnabled(
    BuildContext context,
    WidgetRef ref,
    Prayer prayer,
    bool value,
  ) async {
    final container = ProviderScope.containerOf(context);
    await ref
        .read(settingsRepositoryProvider)
        .setBool(SettingsKeys.notifyEnabled(prayer.name), value);
    await _refresh(container, ref);
  }

  Future<void> _setSoundMode(
    BuildContext context,
    WidgetRef ref,
    Prayer prayer,
    NotificationSoundMode mode,
  ) async {
    final container = ProviderScope.containerOf(context);
    await ref
        .read(settingsRepositoryProvider)
        .setString(SettingsKeys.notifySound(prayer.name), mode.settingsValue);
    await _refresh(container, ref);
  }

  /// Lets the user pick a custom adhan sound (SRS FR-NT-02) from either the
  /// system ringtone/notification picker or an arbitrary file — the user
  /// asked for both. Only commits to 'custom' once a sound actually comes
  /// back; cancelling at any step leaves the prayer's setting untouched.
  Future<void> _requestCustomSound(
    BuildContext context,
    WidgetRef ref,
    Prayer prayer,
    String? currentUri,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final source = await _showSoundSourceSheet(context);
    if (source == null || !context.mounted) return;

    String? newUri;
    try {
      if (source == _SoundSource.systemPicker) {
        newUri = await SoundPicker.pickSystemRingtone(currentUri: currentUri);
      } else {
        final picked = await FilePicker.pickFile(type: FileType.audio);
        if (picked == null) return;
        // `picked.path` is only non-null for a `file://` URI; Android's
        // Storage Access Framework typically returns `content://` instead,
        // so this reads the bytes (works regardless of scheme, same as the
        // JSON backup import elsewhere) into a temp file native code can
        // open by plain path.
        final tempDir = await getTemporaryDirectory();
        final tempFile = File(p.join(tempDir.path, picked.name));
        await tempFile.writeAsBytes(await picked.readAsBytes());
        try {
          newUri = await SoundPicker.importSoundFile(
            filePath: tempFile.path,
            displayName: '${prayer.name}_adhan',
          );
        } finally {
          await tempFile.delete();
        }
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.soundImportError(e.toString()))),
      );
      return;
    }
    if (newUri == null) return;

    if (currentUri != null && currentUri != newUri) {
      await SoundPicker.deleteImportedSound(currentUri);
    }

    if (!context.mounted) return;
    final container = ProviderScope.containerOf(context);
    final settings = ref.read(settingsRepositoryProvider);
    await settings.setString(
      SettingsKeys.notifySound(prayer.name),
      NotificationSoundMode.custom.settingsValue,
    );
    await settings.setString(SettingsKeys.notifySoundUri(prayer.name), newUri);
    await _refresh(container, ref);
  }

  Future<_SoundSource?> _showSoundSourceSheet(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return showModalBottomSheet<_SoundSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  l10n.chooseSoundSheetTitle,
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.notifications_active_outlined),
              title: Text(l10n.chooseSoundSystemOption),
              onTap: () =>
                  Navigator.of(sheetContext).pop(_SoundSource.systemPicker),
            ),
            ListTile(
              leading: const Icon(Icons.audio_file_outlined),
              title: Text(l10n.chooseSoundFileOption),
              onTap: () => Navigator.of(sheetContext).pop(_SoundSource.file),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _setPreAdhanOffset(
    BuildContext context,
    WidgetRef ref,
    int minutes,
  ) async {
    final container = ProviderScope.containerOf(context);
    await ref
        .read(settingsRepositoryProvider)
        .setInt(SettingsKeys.preAdhanOffsetMinutes, minutes);
    ref.invalidate(daySnapshotProvider);
    await _refresh(container, ref);
  }

  Future<void> _setDndEnabled(
    BuildContext context,
    WidgetRef ref,
    bool value,
  ) async {
    final container = ProviderScope.containerOf(context);
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    if (value) {
      final granted = await DndService().isPermissionGranted();
      if (!granted) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.dndPermissionRequiredError)),
        );
        await DndService().openPermissionSettings();
        return;
      }
    }
    await ref
        .read(settingsRepositoryProvider)
        .setBool(SettingsKeys.dndDuringPrayer, value);
    await _refresh(container, ref);
  }

  Future<void> _setDndDuration(
    BuildContext context,
    WidgetRef ref,
    int minutes,
  ) async {
    final container = ProviderScope.containerOf(context);
    await ref
        .read(settingsRepositoryProvider)
        .setInt(SettingsKeys.dndDurationMinutes, minutes);
    await _refresh(container, ref);
  }

  Future<void> _refresh(ProviderContainer container, WidgetRef ref) async {
    ref.invalidate(_notificationSettingsProvider);
    await NotificationCoordinator.scheduleUpcomingWindow(container);
  }
}

enum _SoundSource { systemPicker, file }

extension on NotificationSoundMode {
  String get settingsValue => switch (this) {
    NotificationSoundMode.defaultSound => 'default',
    NotificationSoundMode.silent => 'silent',
    NotificationSoundMode.custom => 'custom',
  };
}

class _PrayerNotificationTile extends StatelessWidget {
  final String label;
  final bool enabled;
  final NotificationSoundMode soundMode;
  final bool allowCustomSound;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<NotificationSoundMode> onSoundModeChanged;
  final VoidCallback onCustomSoundRequested;

  const _PrayerNotificationTile({
    required this.label,
    required this.enabled,
    required this.soundMode,
    required this.allowCustomSound,
    required this.onEnabledChanged,
    required this.onSoundModeChanged,
    required this.onCustomSoundRequested,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              Switch(value: enabled, onChanged: onEnabledChanged),
            ],
          ),
          // A full-width row of its own, rather than squeezed in alongside
          // the name and switch above: three segments plus Arabic's longer
          // labels ("افتراضي"/"صامت"/"مخصص") overflowed when this shared
          // that row (SRS decision log, this feature's entry).
          if (enabled)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: SegmentedButton<NotificationSoundMode>(
                      style: const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                      ),
                      segments: [
                        ButtonSegment(
                          value: NotificationSoundMode.defaultSound,
                          label: Text(l10n.soundDefault),
                        ),
                        ButtonSegment(
                          value: NotificationSoundMode.silent,
                          label: Text(l10n.soundSilent),
                        ),
                        if (allowCustomSound)
                          ButtonSegment(
                            value: NotificationSoundMode.custom,
                            label: Text(l10n.soundCustom),
                          ),
                      ],
                      selected: {soundMode},
                      onSelectionChanged: (selection) {
                        final mode = selection.first;
                        if (mode == NotificationSoundMode.custom) {
                          onCustomSoundRequested();
                        } else {
                          onSoundModeChanged(mode);
                        }
                      },
                    ),
                  ),
                  if (allowCustomSound &&
                      soundMode == NotificationSoundMode.custom)
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      visualDensity: VisualDensity.compact,
                      tooltip: l10n.chooseSoundSheetTitle,
                      onPressed: onCustomSoundRequested,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _NotificationSettingsValues {
  final Map<Prayer, bool> enabled;
  final Map<Prayer, NotificationSoundMode> soundMode;
  final Map<Prayer, String?> customSoundUri;
  final int preAdhanOffsetMinutes;
  final bool dndEnabled;
  final int dndDurationMinutes;

  const _NotificationSettingsValues({
    required this.enabled,
    required this.soundMode,
    required this.customSoundUri,
    required this.preAdhanOffsetMinutes,
    required this.dndEnabled,
    required this.dndDurationMinutes,
  });
}

final _notificationSettingsProvider =
    FutureProvider<_NotificationSettingsValues>((ref) async {
      final settings = ref.watch(settingsRepositoryProvider);
      final enabled = <Prayer, bool>{};
      final soundMode = <Prayer, NotificationSoundMode>{};
      final customSoundUri = <Prayer, String?>{};
      for (final prayer in Prayer.values) {
        enabled[prayer] =
            await settings.getBool(SettingsKeys.notifyEnabled(prayer.name)) ??
            true;
        final soundValue =
            await settings.getString(SettingsKeys.notifySound(prayer.name)) ??
            'default';
        final mode = NotificationSoundMode.fromSettingsValue(soundValue);
        soundMode[prayer] = mode;
        customSoundUri[prayer] = mode == NotificationSoundMode.custom
            ? await settings.getString(SettingsKeys.notifySoundUri(prayer.name))
            : null;
      }

      return _NotificationSettingsValues(
        enabled: enabled,
        soundMode: soundMode,
        customSoundUri: customSoundUri,
        preAdhanOffsetMinutes:
            await settings.getInt(SettingsKeys.preAdhanOffsetMinutes) ??
            PrayerConfig.defaultPreAdhanOffsetMinutes,
        dndEnabled:
            await settings.getBool(SettingsKeys.dndDuringPrayer) ?? false,
        dndDurationMinutes:
            await settings.getInt(SettingsKeys.dndDurationMinutes) ?? 15,
      );
    });
