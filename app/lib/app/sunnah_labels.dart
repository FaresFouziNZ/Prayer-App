import '../domain/tracker/sunnah.dart';
import '../l10n/app_localizations.dart';

/// Localized labels for each rawatib item, shared by the home/history
/// checklist and the Stats screen's completion breakdown.
Map<SunnahItem, String> sunnahLabels(AppLocalizations l10n) => {
  SunnahItem.fajrBefore: l10n.sunnahFajrBefore,
  SunnahItem.dhuhrBefore: l10n.sunnahDhuhrBefore,
  SunnahItem.dhuhrAfter: l10n.sunnahDhuhrAfter,
  SunnahItem.maghribAfter: l10n.sunnahMaghribAfter,
  SunnahItem.ishaAfter: l10n.sunnahIshaAfter,
  SunnahItem.witr: l10n.sunnahWitr,
};
