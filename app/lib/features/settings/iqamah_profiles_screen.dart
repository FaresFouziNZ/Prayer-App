import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../app/providers.dart';
import '../../config/prayer_config.dart';
import '../../domain/schedule/iqamah_profile.dart';
import '../../l10n/app_localizations.dart';
import 'iqamah_profile_edit_screen.dart';

/// Lists Normal, Ramadan, and any custom iqamah profiles (SRS FR-IQ-02).
class IqamahProfilesScreen extends ConsumerWidget {
  const IqamahProfilesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final profilesAsync = ref.watch(iqamahProfilesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.iqamahProfilesTitle)),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addProfile(context, ref),
        child: const Icon(Icons.add),
      ),
      body: profilesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) =>
            Center(child: Text(l10n.errorLabel(error.toString()))),
        data: (profiles) => ListView(
          children: [
            for (final profile in profiles)
              ListTile(
                title: Text(profile.name),
                subtitle: Text(
                  profile.isBuiltin ? l10n.builtinLabel : l10n.customLabel,
                ),
                trailing: profile.isBuiltin
                    ? const Icon(Icons.chevron_right)
                    : IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => ref
                            .read(iqamahProfileRepositoryProvider)
                            .delete(profile.id),
                      ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) =>
                        IqamahProfileEditScreen(profileId: profile.id),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _addProfile(BuildContext context, WidgetRef ref) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => const _NameDialog(),
    );
    if (name == null || name.trim().isEmpty) return;

    final id = const Uuid().v4();
    final profile = IqamahProfile(
      id: id,
      name: name.trim(),
      offsetMinutes: PrayerConfig.normalIqamahOffsets,
    );
    await ref.read(iqamahProfileRepositoryProvider).upsert(profile);
    ref.invalidate(iqamahProfilesProvider);

    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => IqamahProfileEditScreen(profileId: id),
      ),
    );
  }
}

class _NameDialog extends StatefulWidget {
  const _NameDialog();

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.newProfileNameTitle),
      content: TextField(controller: _controller, autofocus: true),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(l10n.create),
        ),
      ],
    );
  }
}
