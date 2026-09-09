import Foundation

/// Mirrors `app/lib/app/prayer_names.dart` — same Arabic script, same
/// Jumu'ah-on-Friday override for Dhuhr (SRS FR-PT-05). Keep the two in
/// sync by hand; there's no shared source between Dart and Swift for this.
enum PrayerDisplayNames {
    private static let arabicScript: [String: String] = [
        "fajr": "الفجر",
        "dhuhr": "الظهر",
        "asr": "العصر",
        "maghrib": "المغرب",
        "isha": "العشاء",
    ]
    private static let jumuahArabicScript = "الجمعة"

    private static let transliterations: [String: String] = [
        "fajr": "Fajr",
        "dhuhr": "Dhuhr",
        "asr": "Asr",
        "maghrib": "Maghrib",
        "isha": "Isha",
    ]
    private static let jumuahTransliteration = "Jumu'ah"

    /// `attributes.date` is `YYYY-MM-DD` local calendar date (not a UTC
    /// instant), so this parses it as calendar components directly rather
    /// than going through a `Date` + time zone at all — there's no time-of-
    /// day here to get wrong.
    private static func isFriday(_ dateKey: String) -> Bool {
        let parts = dateKey.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return false }
        var components = DateComponents()
        components.year = parts[0]
        components.month = parts[1]
        components.day = parts[2]
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        guard let date = calendar.date(from: components) else { return false }
        // `.weekday` is always 1=Sunday...7=Saturday for the Gregorian
        // calendar regardless of `firstWeekday`, so Friday is always 6.
        return calendar.component(.weekday, from: date) == 6
    }

    private static func isJumuah(_ attributes: PrayerActivityAttributes) -> Bool {
        attributes.prayer == "dhuhr" && isFriday(attributes.date)
    }

    static func arabic(for attributes: PrayerActivityAttributes) -> String {
        isJumuah(attributes)
            ? jumuahArabicScript
            : (arabicScript[attributes.prayer] ?? attributes.prayer)
    }

    static func transliteration(for attributes: PrayerActivityAttributes) -> String {
        isJumuah(attributes)
            ? jumuahTransliteration
            : (transliterations[attributes.prayer] ?? attributes.prayer.capitalized)
    }

    /// SF Symbol for the compact Dynamic Island's "prayer glyph" (§2.7).
    /// Monochrome/template-friendly rather than an emoji, matching how
    /// system Dynamic Island content is normally rendered.
    static func systemImageName(for prayer: String) -> String {
        switch prayer {
        case "fajr": return "moonrise.fill"
        case "dhuhr", "asr": return "sun.max.fill"
        case "maghrib": return "sunset.fill"
        case "isha": return "moon.stars.fill"
        default: return "building.columns.fill"
        }
    }
}
