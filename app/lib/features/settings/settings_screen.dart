import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/providers.dart';
import '../../config/prayer_config.dart';
import '../../config/settings_keys.dart';
import '../../data/db/repositories/iqamah_profile_repository.dart';
import '../../domain/schedule/iqamah_profile.dart';
import '../../l10n/app_localizations.dart';
import '../../platform/location/location_service.dart';
import 'iqamah_profiles_screen.dart';
import 'notification_settings_section.dart';

/// SRS FR-RM, FR-IQ-04, FR-PT-03, FR-UI, FR-BK. Settings are stored in the
/// typed key/value table (§2.1) and read fresh each time this screen builds.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final valuesAsync = ref.watch(_settingsValuesProvider);
    final profilesAsync = ref.watch(iqamahProfilesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: valuesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text(l10n.errorLabel(error.toString()))),
        data: (values) => ListView(
          children: [
            _SectionHeader(l10n.locationSectionLabel),
            SegmentedButton<String>(
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
              ),
              segments: [
                ButtonSegment(value: 'automatic', label: Text(l10n.automaticGpsLabel)),
                ButtonSegment(value: 'manual', label: Text(l10n.manualLabel)),
              ],
              selected: {values.locationMode},
              onSelectionChanged: (selection) =>
                  _setString(ref, SettingsKeys.locationMode, selection.first),
            ),
            const SizedBox(height: 8),
            if (values.locationMode == 'automatic')
              ListTile(
                title: Text(l10n.useCurrentLocationLabel),
                subtitle: Text(values.locationLabel ?? l10n.noFixYetLabel),
                trailing: const Icon(Icons.my_location),
                onTap: () => _useCurrentLocation(context, ref),
              )
            else
              _ManualLocationForm(
                latitude: values.latitude,
                longitude: values.longitude,
                label: values.locationLabel,
                onSave: (lat, lng, label) => _saveManualLocation(ref, lat, lng, label),
              ),
            const Divider(),
            _SectionHeader(l10n.prayerTimesSectionLabel),
            SwitchListTile(
              title: Text(l10n.ramadanModeLabel),
              subtitle: Text(l10n.ramadanModeSubtitle),
              value: values.ramadanMode,
              onChanged: (value) => _setBool(ref, SettingsKeys.ramadanMode, value),
            ),
            profilesAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (error, stack) => Text(l10n.errorLabel(error.toString())),
              data: (profiles) => Column(
                children: [
                  _ProfilePicker(
                    label: l10n.normalProfileLabel,
                    profiles: profiles,
                    selectedId: values.normalProfileId,
                    onChanged: (id) =>
                        _setString(ref, SettingsKeys.normalIqamahProfileId, id),
                  ),
                  _ProfilePicker(
                    label: l10n.ramadanProfileLabel,
                    profiles: profiles,
                    selectedId: values.ramadanProfileId,
                    onChanged: (id) =>
                        _setString(ref, SettingsKeys.ramadanIqamahProfileId, id),
                  ),
                ],
              ),
            ),
            ListTile(
              title: Text(l10n.manageProfilesLabel),
              subtitle: Text(l10n.manageProfilesSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const IqamahProfilesScreen()),
              ),
            ),
            _StepperTile(
              title: l10n.travelMinutesLabel,
              value: values.travelMinutes,
              onChanged: (v) => _setInt(ref, SettingsKeys.travelMinutes, v),
            ),
            _StepperTile(
              title: l10n.bufferMinutesLabel,
              value: values.bufferMinutes,
              onChanged: (v) => _setInt(ref, SettingsKeys.bufferMinutes, v),
            ),
            _StepperTile(
              title: l10n.closingOffsetLabel,
              value: values.closingOffsetMinutes,
              onChanged: (v) => _setInt(ref, SettingsKeys.closingOffsetMinutes, v),
            ),
            const Divider(),
            _SectionHeader(l10n.notificationsSectionLabel),
            const NotificationSettingsSection(),
            const Divider(),
            _SectionHeader(l10n.qadaSectionLabel),
            SwitchListTile(
              title: Text(l10n.lateCountsAsQadaLabel),
              value: values.lateCountsAsQada,
              onChanged: (value) => _setBool(ref, SettingsKeys.lateCountsAsQada, value),
            ),
            const Divider(),
            _SectionHeader(l10n.appearanceSectionLabel),
            ListTile(
              title: Text(l10n.languageLabel),
              trailing: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'en', label: Text('English')),
                  ButtonSegment(value: 'ar', label: Text('العربية')),
                ],
                selected: {values.languageCode},
                onSelectionChanged: (selection) =>
                    _setString(ref, SettingsKeys.languageCode, selection.first),
              ),
            ),
            const Divider(),
            _SectionHeader(l10n.backupSectionLabel),
            ListTile(
              title: Text(l10n.exportBackupLabel),
              subtitle: Text(l10n.exportBackupSubtitle),
              trailing: const Icon(Icons.ios_share),
              onTap: () => _export(ref, l10n),
            ),
            ListTile(
              title: Text(l10n.importBackupLabel),
              subtitle: Text(l10n.importBackupSubtitle),
              trailing: const Icon(Icons.file_open),
              onTap: () => _import(context, ref, l10n),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _useCurrentLocation(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final fix = await LocationService().getCurrentFix();
      final settings = ref.read(settingsRepositoryProvider);
      await settings.setString(SettingsKeys.locationMode, 'automatic');
      await settings.setDouble(SettingsKeys.latitude, fix.latitude);
      await settings.setDouble(SettingsKeys.longitude, fix.longitude);
      await settings.setString(
        SettingsKeys.locationLabel,
        '${fix.latitude.toStringAsFixed(4)}, ${fix.longitude.toStringAsFixed(4)}',
      );
      _invalidateDerived(ref);
    } on LocationServiceDisabledException {
      if (context.mounted) _showError(context, l10n.locationServicesDisabledError);
    } on LocationPermissionDeniedException {
      if (context.mounted) _showError(context, l10n.locationPermissionDeniedError);
    }
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _saveManualLocation(
    WidgetRef ref,
    double lat,
    double lng,
    String label,
  ) async {
    final settings = ref.read(settingsRepositoryProvider);
    await settings.setString(SettingsKeys.locationMode, 'manual');
    await settings.setDouble(SettingsKeys.latitude, lat);
    await settings.setDouble(SettingsKeys.longitude, lng);
    await settings.setString(SettingsKeys.locationLabel, label);
    _invalidateDerived(ref);
  }

  Future<void> _setBool(WidgetRef ref, String key, bool value) async {
    await ref.read(settingsRepositoryProvider).setBool(key, value);
    _invalidateDerived(ref);
  }

  Future<void> _setString(WidgetRef ref, String key, String value) async {
    await ref.read(settingsRepositoryProvider).setString(key, value);
    _invalidateDerived(ref);
  }

  Future<void> _setInt(WidgetRef ref, String key, int value) async {
    await ref.read(settingsRepositoryProvider).setInt(key, value);
    _invalidateDerived(ref);
  }

  void _invalidateDerived(WidgetRef ref) {
    ref.invalidate(_settingsValuesProvider);
    ref.invalidate(coordinatesProvider);
    ref.invalidate(daySnapshotProvider);
  }

  Future<void> _export(WidgetRef ref, AppLocalizations l10n) async {
    final json = await ref.read(backupServiceProvider).exportToJsonString();
    await SharePlus.instance.share(
      ShareParams(text: json, subject: l10n.backupShareSubject),
    );
  }

  Future<void> _import(BuildContext context, WidgetRef ref, AppLocalizations l10n) async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final jsonString = utf8.decode(bytes);

    final service = ref.read(backupServiceProvider);
    final diff = await service.dryRunImport(jsonString);
    if (!context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.importBackupLabel),
        content: Text(
          l10n.importSummaryLabel(diff.rowsToAdd, diff.rowsConflicting, diff.rowsIdentical),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.import),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await service.applyImport(jsonString);
      _invalidateDerived(ref);
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}

class _ProfilePicker extends StatelessWidget {
  final String label;
  final List<IqamahProfile> profiles;
  final String selectedId;
  final ValueChanged<String> onChanged;

  const _ProfilePicker({
    required this.label,
    required this.profiles,
    required this.selectedId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label),
      trailing: DropdownButton<String>(
        value: profiles.any((p) => p.id == selectedId) ? selectedId : null,
        items: [
          for (final profile in profiles)
            DropdownMenuItem(value: profile.id, child: Text(profile.name)),
        ],
        onChanged: (value) {
          if (value != null) onChanged(value);
        },
      ),
    );
  }
}

class _ManualLocationForm extends StatefulWidget {
  final double? latitude;
  final double? longitude;
  final String? label;
  final void Function(double lat, double lng, String label) onSave;

  const _ManualLocationForm({
    required this.latitude,
    required this.longitude,
    required this.label,
    required this.onSave,
  });

  @override
  State<_ManualLocationForm> createState() => _ManualLocationFormState();
}

class _ManualLocationFormState extends State<_ManualLocationForm> {
  late final _lat = TextEditingController(text: widget.latitude?.toString());
  late final _lng = TextEditingController(text: widget.longitude?.toString());
  late final _label = TextEditingController(text: widget.label);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          TextField(
            controller: _label,
            decoration: InputDecoration(labelText: l10n.locationLabelFieldHint),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _lat,
                  keyboardType: const TextInputType.numberWithOptions(
                    signed: true,
                    decimal: true,
                  ),
                  decoration: InputDecoration(labelText: l10n.latitudeLabel),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _lng,
                  keyboardType: const TextInputType.numberWithOptions(
                    signed: true,
                    decimal: true,
                  ),
                  decoration: InputDecoration(labelText: l10n.longitudeLabel),
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                final lat = double.tryParse(_lat.text);
                final lng = double.tryParse(_lng.text);
                if (lat == null || lng == null) return;
                widget.onSave(lat, lng, _label.text.trim());
              },
              child: Text(l10n.saveLocationLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsValues {
  final String locationMode;
  final double? latitude;
  final double? longitude;
  final String? locationLabel;
  final bool ramadanMode;
  final String normalProfileId;
  final String ramadanProfileId;
  final int travelMinutes;
  final int bufferMinutes;
  final int closingOffsetMinutes;
  final bool lateCountsAsQada;
  final String languageCode;

  const _SettingsValues({
    required this.locationMode,
    required this.latitude,
    required this.longitude,
    required this.locationLabel,
    required this.ramadanMode,
    required this.normalProfileId,
    required this.ramadanProfileId,
    required this.travelMinutes,
    required this.bufferMinutes,
    required this.closingOffsetMinutes,
    required this.lateCountsAsQada,
    required this.languageCode,
  });
}

final _settingsValuesProvider = FutureProvider<_SettingsValues>((ref) async {
  final settings = ref.watch(settingsRepositoryProvider);
  return _SettingsValues(
    locationMode: await settings.getString(SettingsKeys.locationMode) ?? 'automatic',
    latitude: await settings.getDouble(SettingsKeys.latitude),
    longitude: await settings.getDouble(SettingsKeys.longitude),
    locationLabel: await settings.getString(SettingsKeys.locationLabel),
    ramadanMode: await settings.getBool(SettingsKeys.ramadanMode) ?? false,
    normalProfileId: await settings.getString(SettingsKeys.normalIqamahProfileId) ??
        IqamahProfileRepository.normalProfileId,
    ramadanProfileId: await settings.getString(SettingsKeys.ramadanIqamahProfileId) ??
        IqamahProfileRepository.ramadanProfileId,
    travelMinutes: await settings.getInt(SettingsKeys.travelMinutes) ??
        PrayerConfig.defaultTravelMinutes,
    bufferMinutes: await settings.getInt(SettingsKeys.bufferMinutes) ??
        PrayerConfig.defaultBufferMinutes,
    closingOffsetMinutes:
        await settings.getInt(SettingsKeys.closingOffsetMinutes) ??
            PrayerConfig.defaultClosingOffsetMinutes,
    lateCountsAsQada:
        await settings.getBool(SettingsKeys.lateCountsAsQada) ?? false,
    languageCode: await settings.getString(SettingsKeys.languageCode) ?? 'en',
  );
});

class _StepperTile extends StatelessWidget {
  final String title;
  final int value;
  final ValueChanged<int> onChanged;

  const _StepperTile({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove),
            onPressed: value > 0 ? () => onChanged(value - 5) : null,
          ),
          Text('$value'),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => onChanged(value + 5),
          ),
        ],
      ),
    );
  }
}
