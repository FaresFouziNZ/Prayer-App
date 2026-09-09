import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/prayer_names.dart';
import '../../app/providers.dart';
import '../../domain/prayer_engine/prayer.dart';
import '../../domain/schedule/iqamah_profile.dart';
import '../../l10n/app_localizations.dart';

/// Edits one profile's per-prayer offsets and mosque override
/// (SRS FR-IQ-02, FR-IQ-03).
class IqamahProfileEditScreen extends ConsumerStatefulWidget {
  final String profileId;

  const IqamahProfileEditScreen({super.key, required this.profileId});

  @override
  ConsumerState<IqamahProfileEditScreen> createState() =>
      _IqamahProfileEditScreenState();
}

class _IqamahProfileEditScreenState
    extends ConsumerState<IqamahProfileEditScreen> {
  Map<Prayer, int>? _offsets;
  Map<Prayer, int>? _mosqueOverride;
  bool _hasMosqueOverride = false;
  late TextEditingController _nameController;
  IqamahProfile? _loaded;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final profilesAsync = ref.watch(iqamahProfilesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.editProfileTitle),
        actions: [IconButton(icon: const Icon(Icons.check), onPressed: _save)],
      ),
      body: profilesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) =>
            Center(child: Text(l10n.errorLabel(error.toString()))),
        data: (profiles) {
          final profile = profiles.firstWhere((p) => p.id == widget.profileId);
          if (_loaded?.id != profile.id) {
            _loaded = profile;
            _offsets = Map.of(profile.offsetMinutes);
            _mosqueOverride = profile.mosqueOverride == null
                ? Map.of(profile.offsetMinutes)
                : Map.of(profile.mosqueOverride!);
            _hasMosqueOverride = profile.mosqueOverride != null;
            _nameController = TextEditingController(text: profile.name);
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                controller: _nameController,
                enabled: !profile.isBuiltin,
                decoration: InputDecoration(labelText: l10n.nameLabel),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.iqamahOffsetsLabel,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              for (final prayer in Prayer.values)
                _OffsetRow(
                  label: PrayerNames.displayName(context, prayer),
                  value: _offsets![prayer]!,
                  onChanged: (v) => setState(() => _offsets![prayer] = v),
                ),
              const Divider(height: 32),
              SwitchListTile(
                title: Text(l10n.mosqueOverrideLabel),
                subtitle: Text(l10n.mosqueOverrideSubtitle),
                value: _hasMosqueOverride,
                onChanged: (value) =>
                    setState(() => _hasMosqueOverride = value),
              ),
              if (_hasMosqueOverride)
                for (final prayer in Prayer.values)
                  _OffsetRow(
                    label: l10n.mosqueOffsetSuffix(
                      PrayerNames.displayName(context, prayer),
                    ),
                    value: _mosqueOverride![prayer]!,
                    onChanged: (v) =>
                        setState(() => _mosqueOverride![prayer] = v),
                  ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _save() async {
    final updated = _loaded!.copyWith(
      name: _nameController.text.trim().isEmpty
          ? _loaded!.name
          : _nameController.text.trim(),
      offsetMinutes: _offsets,
      mosqueOverride: _hasMosqueOverride ? _mosqueOverride : null,
    );
    await ref.read(iqamahProfileRepositoryProvider).upsert(updated);
    ref.invalidate(iqamahProfilesProvider);
    ref.invalidate(daySnapshotProvider);
    if (mounted) Navigator.of(context).pop();
  }
}

class _OffsetRow extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  const _OffsetRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove),
            onPressed: value > 0 ? () => onChanged(value - 1) : null,
          ),
          SizedBox(
            width: 28,
            child: Text('$value', textAlign: TextAlign.center),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => onChanged(value + 1),
          ),
        ],
      ),
    );
  }
}
