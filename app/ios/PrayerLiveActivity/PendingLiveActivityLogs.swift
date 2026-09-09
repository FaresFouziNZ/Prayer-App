import Foundation

/// Shared between the widget extension (`LogPrayerIntent`, the writer) and
/// the main app (`AppDelegate`'s `live_activity` channel, the reader) — add
/// this file to **both** targets' Target Membership in Xcode, or whichever
/// target it isn't added to will fail to find the type.
///
/// **Write path — resolves docs/02-Architecture.md §2.7's open "decision at
/// M5"** ("writes via Drift, through a small Swift→Dart channel *or*
/// directly to the SQLite file using the shared App Group path"). Neither
/// option is safe to implement here untested: writing SQLite directly from
/// Swift would duplicate the tracker's write rules (Friday-is-Jama'ah,
/// re-log-as-edit, etc. — see `domain/tracker` in the Dart app) in a second
/// language; invoking Dart synchronously from inside an intent would need a
/// headless Flutter engine bootstrapped from Swift, which nothing in this
/// app does today (unlike Android, which already has one via
/// `android_alarm_manager_plus` for its own background work). Instead this
/// queues a small `{date, prayer, status}` record here, in the App Group's
/// shared `UserDefaults`, and the main app drains it through its *existing*
/// logging path (`PendingLiveActivityLogs` on the Dart side, wired into
/// `NotificationCoordinator.scheduleUpcomingWindow`) the next time it's
/// foregrounded — which happens automatically whenever the user reopens the
/// app, and is also nudged by `LogPrayerIntent` ending the Live Activity
/// immediately, encouraging exactly that.
///
/// **Requires an App Group** (e.g. `group.com.fares.prayerapp.prayerApp`)
/// added to both the `Runner` and `PrayerLiveActivity` targets' Signing &
/// Capabilities, with the same identifier below. If Personal Team signing
/// can't add App Groups (see the Mac setup checklist), this silently
/// no-ops — `defaults` is `nil` and every call below returns early — rather
/// than crashing, so the rest of the Live Activity still works without it;
/// only the button-tap-while-app-closed case is affected.
enum PendingLiveActivityLogs {
    private static let appGroupId = "group.com.fares.prayerapp.prayerApp"
    private static let storageKey = "pending_live_activity_logs"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupId)
    }

    /// One entry per tap — deliberately not deduplicated or merged; the
    /// Dart-side drain applies each one through the ordinary logging path,
    /// which already treats a re-log as an edit rather than a conflict
    /// (AC-TR-1).
    static func append(date: String, prayer: String, status: String) {
        guard let defaults else { return }
        var pending = defaults.array(forKey: storageKey) as? [[String: String]] ?? []
        pending.append([
            "date": date,
            "prayer": prayer,
            "status": status,
            "loggedAt": ISO8601DateFormatter().string(from: Date()),
        ])
        defaults.set(pending, forKey: storageKey)
    }

    /// Reads and clears the queue in one step — called from Dart via the
    /// `live_activity` method channel's `drainPendingLogs`.
    static func drain() -> [[String: String]] {
        guard let defaults else { return [] }
        let pending = defaults.array(forKey: storageKey) as? [[String: String]] ?? []
        defaults.removeObject(forKey: storageKey)
        return pending
    }
}
