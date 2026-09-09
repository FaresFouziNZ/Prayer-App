# iOS Live Activity — Mac handoff

| | |
|---|---|
| Written | 2026-09-09, on Windows, before any Xcode/Mac access existed |
| Purpose | Let a fresh Claude Code session on the Mac pick this up with full context |
| Companion to | `01-SRS.md`, `02-Architecture.md` (especially §2.2, §2.7, §3) |

## Where things stand right now

**Done and verified (do not redo):**
- Firebase backend is fully deployed and live on the Blaze plan: Firestore rules/indexes, and all three Cloud Functions (`planDay`, `onDeviceWrite`, `sendLiveActivity`) implementing the push timeline in `functions/src/`.
- The Flutter client publishes to it already (`app/lib/data/firebase/firebase_sync_service.dart`): anonymous auth on launch, device doc (tokens/location/calc/iqamah/ramadan/closingOffset), and a rolling 30-day schedule. Verified running on a real Android device (OnePlus 7T Pro) without crashing.
- Android's own live-countdown notification, sunnah reminders, custom per-prayer notification sounds, home-widget status dots, period-day exemption, and the app icon are all done, tested (90 passing tests in `app/test/`), and pushed to `main`.
- **iOS has never been built.** No CocoaPods resolution, no Xcode workspace open, no real device run — none of it has happened yet. Everything below is the plan plus a first draft of the Swift code, written blind (no compiler).

**Pre-written but unverified — the actual reason for this doc:**
`app/ios/PrayerLiveActivity/` (new directory, not yet in any Xcode target) and an edit to `app/ios/Runner/AppDelegate.swift`:
- `PrayerActivityAttributes.swift` — the `ActivityAttributes`/`ContentState` model. Field-for-field matches what `functions/src/fcm.ts` sends in the push payload. **Read the comment about `Double` vs `Date` fields before touching this** — Swift's default `Date` decoding uses the 2001 reference date, not Unix epoch, which would silently corrupt every timestamp if "fixed" naively.
- `PrayerDisplayNames.swift` — Arabic script + transliteration + Jumu'ah-on-Friday, mirroring `app/lib/app/prayer_names.dart`.
- `LogPrayerIntent.swift` — the Jama'ah/Alone/Not yet buttons, as a `LiveActivityIntent`.
- `PendingLiveActivityLogs.swift` — the shared App Group queue those buttons write to (needs Target Membership in **both** `Runner` and `PrayerLiveActivity` once that target exists).
- `PrayerLiveActivityWidget.swift` — lock screen + Dynamic Island SwiftUI.
- `AppDelegate.swift` — hosts a `live_activity` method channel (`drainPendingLogs`) that the Dart side calls. **The line most likely to need fixing:** `self.registrar(forPlugin: "LiveActivityChannel")?.messenger()` — written without being able to check which Flutter iOS embedding API this project's Flutter version actually uses.

**The write-path design decision** (`docs/02-Architecture.md` §2.7 flagged this as open, "decision at M5"): resolved as neither Drift-via-channel nor direct-SQLite. The Live Activity buttons queue a `{date, prayer, status}` record into the App Group's `UserDefaults`; the Dart side drains it through the *existing* logging path on next app foreground. This half is fully implemented and tested: `app/lib/platform/live_activity/pending_live_activity_logs.dart`, wired into `NotificationCoordinator.scheduleUpcomingWindow`, with 6 passing tests in `app/test/platform/pending_live_activity_logs_test.dart`. If you change the Swift side's queue format, this Dart file needs to match.

## Setup checklist (Apple Developer Program membership postponed)

### Phase 0 — Environment
1. Xcode (App Store), open once to accept license + install components.
2. `brew install cocoapods`.
3. Install Flutter (match the version this repo was last built with — check `app/pubspec.lock` / run `flutter --version` and compare).
4. `flutter doctor` — resolve anything flagged for iOS.

### Phase 1 — First build
1. `git clone` / `git pull` this repo.
2. `cd app && flutter pub get`
3. `cd ios && pod install` — **first real test of whether the Firebase iOS pods resolve.** Nobody has confirmed this yet.
4. Open `ios/Runner.xcworkspace` (not `.xcodeproj`).
5. Signing & Capabilities → your Apple ID as Team (Personal Team is fine for now).
6. Build/run on simulator, then a real device.

### Phase 2 — Firebase iOS config
1. Generate `GoogleService-Info.plist` (re-run `flutterfire configure` from the Mac, or download from the [Firebase console](https://console.firebase.google.com/project/my-prayer-56710/settings/general) — iOS app already exists there) and add to the `Runner` target.
2. Run the app, confirm Firebase initializes and a `devices/{uid}` document appears in Firestore — this confirms `FirebaseSyncService` works on iOS too, not just Android.

### Phase 3 — Widget Extension target
1. Xcode → File → New → Target → Widget Extension → check **Include Live Activity** → name it `PrayerLiveActivity`.
2. Add the 5 files from `app/ios/PrayerLiveActivity/` to that target. Add `PendingLiveActivityLogs.swift` to **both** `Runner` and `PrayerLiveActivity`.
3. Add `NSSupportsLiveActivities = YES` to `Runner`'s `Info.plist`.
4. Try adding an App Group (e.g. `group.com.fares.prayerapp.prayerApp`, matching what `PendingLiveActivityLogs.swift` already hardcodes) to both targets — if Personal Team signing blocks it, that's expected; note it and move on. Until it's added, `PendingLiveActivityLogs` silently no-ops rather than crashing (see its doc comment).
5. Build. Fix whatever the compiler says — this code has never compiled.

### Phase 4 — Test the Live Activity locally (no push yet)
1. Add a small Dart↔Swift bridge to call `Activity.request()`/`.update()`/`.end()` locally, mirroring `app/lib/platform/live_notification/live_notification_scheduler.dart`'s phase boundaries (`liveStartAt`, `iqamahAt`, `closingAt`, `endAt`) — nothing wires this yet.
2. Run through a real prayer window on-device, watch the phases transition, tap the closing-phase buttons and confirm they end the activity immediately and the log shows up in the app (via the drain) next time it's foregrounded.

### Later, once the Apple Developer Program membership is active
Push-to-start / activity token capture and publishing to Firestore `devices/{id}.tokens`, APNs key upload to Firebase Console, and end-to-end testing of `sendLiveActivity` actually pushing to the device. See `docs/02-Architecture.md` §2.7 and §3.2/§3.3 for the exact spec.

## First prompt to paste into Claude Code on the Mac

```
Continuing the "My Prayer" app's iOS Live Activity work — read
docs/iOS-Mac-Handoff.md in full first, then docs/02-Architecture.md
§2.7 and §3 for the spec the Swift code is supposed to match. Start
at Phase 1 of the handoff doc's checklist: flutter pub get, pod
install, open the workspace, get it building on a simulator. The
Swift files under app/ios/PrayerLiveActivity/ and the AppDelegate.swift
edit were written blind on Windows with no compiler access — treat
them as a first draft, fix whatever doesn't build, and tell me what
had to change and why before moving on to the next phase.
```

## Known risk points

- CocoaPods/Firebase iOS pod resolution — completely untested.
- App Group capability may be unavailable on a free Personal Team until the paid membership is active.
- `GoogleService-Info.plist` doesn't exist in the repo yet — must be generated on the Mac.
- The exact Flutter iOS embedding API (`FlutterImplicitEngineDelegate`/`FlutterImplicitEngineBridge` in the current `AppDelegate.swift`) is newer/less common — the `registrar(forPlugin:)` fallback used for the new channel should be stable regardless, but double check.
- `docs/02-Architecture.md` §5 says Firebase config files should be per-flavour and git-ignored in prod; right now there's only one (default) config and it's committed, matching Google's own "safe to check in" guidance for `google-services.json`. Worth revisiting once flavours exist.
