import 'package:flutter/widgets.dart';

import '../domain/prayer_engine/prayer.dart';
import '../l10n/app_localizations.dart';

/// Prayer names shown in Arabic script in both languages, with an English
/// transliteration alongside in English mode (SRS FR-UI-03). The Arabic
/// script is locale-independent (a proper noun, not a translation), so it
/// lives here rather than in the ARB files, which hold the transliteration
/// for the active locale.
class PrayerNames {
  const PrayerNames._();

  static const Map<Prayer, String> _arabicScript = {
    Prayer.fajr: 'الفجر',
    Prayer.dhuhr: 'الظهر',
    Prayer.asr: 'العصر',
    Prayer.maghrib: 'المغرب',
    Prayer.isha: 'العشاء',
  };

  static const String _jumuahArabicScript = 'الجمعة';

  static String transliteration(AppLocalizations l10n, Prayer prayer) {
    switch (prayer) {
      case Prayer.fajr:
        return l10n.prayerFajr;
      case Prayer.dhuhr:
        return l10n.prayerDhuhr;
      case Prayer.asr:
        return l10n.prayerAsr;
      case Prayer.maghrib:
        return l10n.prayerMaghrib;
      case Prayer.isha:
        return l10n.prayerIsha;
    }
  }

  /// The context-free core of [displayName] — usable when scheduling
  /// notification text, which has no `BuildContext` (FR-UI-04).
  static String displayNameFor(
    AppLocalizations l10n,
    bool isArabicLocale,
    Prayer prayer, {
    bool isJumuah = false,
  }) {
    final useJumuah = isJumuah && prayer == Prayer.dhuhr;
    final script = useJumuah ? _jumuahArabicScript : _arabicScript[prayer]!;
    if (isArabicLocale) return script;

    final translit = useJumuah ? l10n.prayerJumuah : transliteration(l10n, prayer);
    return '$script ($translit)';
  }

  /// The name to display for [prayer] (Jumu'ah instead of Dhuhr on Fridays,
  /// per FR-PT-05). Arabic script always; the English transliteration is
  /// appended unless the active locale is already Arabic.
  static String displayName(
    BuildContext context,
    Prayer prayer, {
    bool isJumuah = false,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final isArabicLocale = Localizations.localeOf(context).languageCode == 'ar';
    return displayNameFor(l10n, isArabicLocale, prayer, isJumuah: isJumuah);
  }
}
