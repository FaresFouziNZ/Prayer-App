/// Constant keys for the `settings` key/value table (SRS §2.4, NFR-09).
class SettingsKeys {
  const SettingsKeys._();

  static const String locationMode = 'location_mode'; // 'automatic' | 'manual'
  static const String latitude = 'latitude';
  static const String longitude = 'longitude';
  static const String locationLabel = 'location_label';
  static const String calculationMethod = 'calculation_method';

  /// Profile used outside Ramadan and the one used during it. Kept separate
  /// (rather than one "active profile" key) so toggling Ramadan mode can
  /// switch between them and switch back automatically (FR-IQ-05), while
  /// still letting the user pick a custom profile for either state.
  static const String normalIqamahProfileId = 'normal_iqamah_profile_id';
  static const String ramadanIqamahProfileId = 'ramadan_iqamah_profile_id';

  static const String ramadanMode = 'ramadan_mode';
  static const String closingOffsetMinutes = 'closing_offset_minutes';
  static const String preAdhanOffsetMinutes = 'pre_adhan_offset_minutes';
  static const String lateCountsAsQada = 'late_counts_as_qada';
  static const String languageCode = 'language_code'; // 'en' | 'ar'
  static const String themeMode = 'theme_mode'; // 'system' | 'light' | 'dark'

  /// Per-prayer adhan notification toggle (FR-NT-01): 'notify_fajr', etc.
  static String notifyEnabled(String prayerName) => 'notify_$prayerName';

  /// Per-prayer adhan sound (FR-NT-02): 'default' | 'silent'. A bundled
  /// adhan clip option needs a licensed audio asset (SRS O4) not present in
  /// this build, so it isn't offered yet.
  static String notifySound(String prayerName) => 'notify_sound_$prayerName';

  static const String dndDuringPrayer = 'dnd_during_prayer';
  static const String dndDurationMinutes = 'dnd_duration_minutes';

  /// Whether the first-launch onboarding carousel has been shown once
  /// (skip or "Get Started" both set this — it never reappears).
  static const String onboardingComplete = 'onboarding_complete';

  /// The date (Codecs.dateKey format) this install first ran. Written once,
  /// in main(), and never rewritten — lets History tell "no data because
  /// you hadn't installed the app yet" apart from "not logged".
  static const String firstLaunchDate = 'first_launch_date';

  /// Whether the user dismissed History's "days before you installed"
  /// notice for the empty tail before [firstLaunchDate].
  static const String historyPreInstallDismissed = 'history_pre_install_dismissed';

  /// Whether the Home screen's Sunnah checklist is collapsed (SRS FR-SN —
  /// optional, so it can be tucked away without losing the toggles).
  static const String sunnahChecklistCollapsed = 'sunnah_checklist_collapsed';
}
