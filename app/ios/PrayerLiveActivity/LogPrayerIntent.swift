import ActivityKit
import AppIntents
import Foundation

/// The three end-of-window actions (SRS FR-NT-06, §2.7's "Buttons" row).
/// Raw values match `NotificationActionIds` (Dart) exactly, so both the
/// Android notification and this Live Activity produce identical action
/// ids for `NotificationActionIds.statusFor` to parse on the Dart side.
enum PrayerLogStatus: String, AppEnum {
    case jamaah = "log_jamaah"
    case alone = "log_alone"
    case notYet = "not_yet"

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Prayer log status"
    static var caseDisplayRepresentations: [PrayerLogStatus: DisplayRepresentation] = [
        .jamaah: "Jama'ah",
        .alone: "Alone",
        .notYet: "Not yet",
    ]
}

/// Logs a prayer directly from the Live Activity's closing-phase buttons —
/// see `PendingLiveActivityLogs.swift` for the full write-path design (the
/// durable DB write happens on the Dart side, on next app foreground; this
/// intent's own job is just queuing that and giving instant visual
/// feedback by ending the activity right away).
struct LogPrayerIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Log Prayer"

    @Parameter(title: "Prayer") var prayer: String
    @Parameter(title: "Date") var date: String
    @Parameter(title: "Status") var status: PrayerLogStatus

    init() {}

    init(prayer: String, date: String, status: PrayerLogStatus) {
        self.prayer = prayer
        self.date = date
        self.status = status
    }

    func perform() async throws -> some IntentResult {
        guard status != .notYet else {
            // A deliberate no-op, matching the Android live notification's
            // identical "Not yet" action — leave the activity exactly as-is.
            return .result()
        }

        PendingLiveActivityLogs.append(date: date, prayer: prayer, status: status.rawValue)

        if let activity = Activity<PrayerActivityAttributes>.activities.first(where: {
            $0.attributes.prayer == prayer && $0.attributes.date == date
        }) {
            var finalState = activity.content.state
            finalState.logged = true
            await activity.end(
                ActivityContent(state: finalState, staleDate: nil),
                dismissalPolicy: .immediate
            )
        }

        return .result()
    }
}
