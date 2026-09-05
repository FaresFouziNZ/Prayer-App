import '../prayer_engine/prayer.dart';

/// Sentinel distinguishing "leave [IqamahProfile.mosqueOverride] unchanged"
/// from "clear it" in [IqamahProfile.copyWith] — see the identical need in
/// PrayerLogEntry.copyWith.
const Object unsetMosqueOverride = Object();

/// A named set of per-prayer iqamah offsets (SRS FR-IQ-02).
class IqamahProfile {
  final String id;
  final String name;
  final Map<Prayer, int> offsetMinutes;

  /// Per-prayer override for a single "my mosque" (FR-IQ-03), null if unset.
  final Map<Prayer, int>? mosqueOverride;
  final bool isBuiltin;

  const IqamahProfile({
    required this.id,
    required this.name,
    required this.offsetMinutes,
    this.mosqueOverride,
    this.isBuiltin = false,
  });

  int offsetFor(Prayer prayer) =>
      mosqueOverride?[prayer] ?? offsetMinutes[prayer] ?? 0;

  /// [mosqueOverride] defaults to "leave unchanged"; pass `null` explicitly
  /// to clear it, since `mosqueOverride ?? this.mosqueOverride` could
  /// otherwise never do so.
  IqamahProfile copyWith({
    String? name,
    Map<Prayer, int>? offsetMinutes,
    Object? mosqueOverride = unsetMosqueOverride,
  }) {
    return IqamahProfile(
      id: id,
      name: name ?? this.name,
      offsetMinutes: offsetMinutes ?? this.offsetMinutes,
      mosqueOverride: identical(mosqueOverride, unsetMosqueOverride)
          ? this.mosqueOverride
          : mosqueOverride as Map<Prayer, int>?,
      isBuiltin: isBuiltin,
    );
  }
}
