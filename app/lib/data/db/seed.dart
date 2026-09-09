import '../../config/prayer_config.dart';
import '../../domain/schedule/iqamah_profile.dart';
import 'repositories/iqamah_profile_repository.dart';

/// Ensures the built-in Normal and Ramadan profiles exist (SRS FR-IQ-02:
/// they "ship as editable defaults"). Called once at app startup.
Future<void> seedDefaultIqamahProfiles(IqamahProfileRepository repo) async {
  if (await repo.getById(IqamahProfileRepository.normalProfileId) == null) {
    await repo.upsert(
      IqamahProfile(
        id: IqamahProfileRepository.normalProfileId,
        name: 'Normal',
        offsetMinutes: PrayerConfig.normalIqamahOffsets,
        isBuiltin: true,
      ),
    );
  }
  if (await repo.getById(IqamahProfileRepository.ramadanProfileId) == null) {
    await repo.upsert(
      IqamahProfile(
        id: IqamahProfileRepository.ramadanProfileId,
        name: 'Ramadan',
        offsetMinutes: PrayerConfig.ramadanIqamahOffsets,
        isBuiltin: true,
      ),
    );
  }
}
