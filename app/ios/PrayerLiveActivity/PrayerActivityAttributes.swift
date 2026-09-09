import ActivityKit
import Foundation

/// Matches `functions/src/fcm.ts`'s push payload and
/// `docs/02-Architecture.md` §2.7's content model exactly — the backend
/// (and, before push infra is wired up, the app itself via a local
/// `Activity.request`/`.update`/`.end`) is the only writer of this shape.
///
/// Timestamps are raw epoch seconds (`Double`), not `Date`. Swift's default
/// `Codable` strategy for `Date` (`.deferredToDate`) encodes/decodes as
/// seconds since the *2001 reference date*, not the Unix epoch — and the
/// system decodes a Live Activity push's `content-state` with its own
/// `JSONDecoder`, with no hook for the app to override that strategy. Since
/// `fcm.ts`'s `epochSeconds()` sends Unix-epoch seconds, a `Date` field here
/// would silently decode ~31 years off. Plain `Double` sidesteps the
/// ambiguity entirely; convert to `Date` only where displayed (below).
struct PrayerActivityAttributes: ActivityAttributes {
    /// One of "fajr" | "dhuhr" | "asr" | "maghrib" | "isha" — matches the
    /// Dart `Prayer` enum's `.name` and the TS `Prayer` type exactly.
    let prayer: String
    /// `YYYY-MM-DD`, the prayer's local calendar date.
    let date: String

    struct ContentState: Codable, Hashable {
        /// Matches §2.7's content model `phase` values exactly (`iqamah` is
        /// spelled that way there, not `beforeIqamah`/etc. — distinct from
        /// Dart's `LivePhase` enum, which also has a `beforeAdhan` case not
        /// represented here since the Live Activity itself doesn't start
        /// until `liveStartAt`, after adhan).
        enum Phase: String, Codable, Hashable {
            case iqamah
            case window
            case closing
        }

        var phase: Phase
        var adhanAt: Double
        var liveStartAt: Double
        var iqamahAt: Double
        var closingAt: Double
        var endAt: Double
        /// Whether this prayer has already been logged — §3.3's closing-phase
        /// push includes an alert "only if logged == false"; locally, this
        /// also decides whether the closing view still shows its buttons.
        var logged: Bool

        var adhanAtDate: Date { Date(timeIntervalSince1970: adhanAt) }
        var liveStartAtDate: Date { Date(timeIntervalSince1970: liveStartAt) }
        var iqamahAtDate: Date { Date(timeIntervalSince1970: iqamahAt) }
        var closingAtDate: Date { Date(timeIntervalSince1970: closingAt) }
        var endAtDate: Date { Date(timeIntervalSince1970: endAt) }

        /// The countdown target for `Text(timerInterval:)` (§2.7: "counts
        /// down to iqamahAt (phase iqamah) or endAt (window/closing)").
        var countdownTarget: Date {
            phase == .iqamah ? iqamahAtDate : endAtDate
        }
    }
}
