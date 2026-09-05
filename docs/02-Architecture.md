# Software Architecture & Design — Prayer Discipline App (MVP)

| | |
|---|---|
| Version | 0.1 (draft) |
| Date | 2026-09-05 |
| Companion to | 01-SRS.md |

---

## 1. Architecture overview

```
┌─────────────────────────────────────────────────────────────────┐
│  Phone                                                          │
│                                                                 │
│  ┌──────────────── Flutter app ────────────────┐                │
│  │  UI (Riverpod)                              │                │
│  │  Domain: prayer engine · tracker · qada ·   │                │
│  │          stats · schedule builder            │                │
│  │  Data: Drift/SQLite · settings · JSON I/O   │                │
│  │  Platform bridges: notifications · widget · │                │
│  │          live activity · firebase            │                │
│  └───────┬───────────────┬───────────────┬─────┘                │
│          │ shared store  │ platform ch.  │ Firebase SDK          │
│  ┌───────▼──────┐ ┌──────▼───────┐       │                      │
│  │ Widget ext.  │ │ Live Activity│       │                      │
│  │ (WidgetKit / │ │ ext. (Swift) │       │                      │
│  │  Glance)     │ │ App Intents  │       │                      │
│  └──────────────┘ └──────▲───────┘       │                      │
│                          │ APNs          │                      │
└──────────────────────────┼───────────────┼──────────────────────┘
                           │               │
            ┌──────────────┴───────┐  ┌────▼─────────────────┐
            │ APNs (via FCM v1)    │  │ Firestore            │
            └──────────▲───────────┘  │  devices/{id}        │
                       │              │  devices/{id}/schedule│
            ┌──────────┴───────────┐  └────▲─────────────────┘
            │ Cloud Function:      │       │
            │  sendLiveActivity    │◄──────┤ read schedule
            └──────────▲───────────┘       │
                       │ HTTP task         │
            ┌──────────┴───────────┐  ┌────┴─────────────────┐
            │ Cloud Tasks queue    │◄─┤ Cloud Function:      │
            │ (exact scheduleTime) │  │  planDay (daily)     │
            └──────────────────────┘  └────▲─────────────────┘
                                           │ Cloud Scheduler
```

**Principles**
1. Local-first. The phone is the source of truth for prayer times and all tracker data.
2. The backend is a scheduler that sends pushes. It stores settings and a published schedule, nothing else.
3. One configuration module defines calculation parameters, window-end rules, and iqamah defaults; every consumer (app, widget, backend) derives from it.
4. Native surfaces (Live Activity, widgets, notification actions) read from shared storage or from push payloads; they never compute prayer times themselves.

---

## 2. Mobile application

### 2.1 Stack

| Concern | Choice | Why |
|---|---|---|
| Framework | Flutter (stable), Dart 3 | Existing expertise; single codebase for both platforms. |
| State | Riverpod | Testable, no BuildContext coupling, good for time-driven state. |
| Storage | Drift (SQLite) | Statistics are SQL aggregates; migrations are explicit. |
| Settings | Drift table `settings` (key/value, typed accessors) | Single store, included in backup. |
| Prayer times | `adhan_dart` (validate vs `adhan`, see SRS O2) | Same algorithm family as npm `adhan` used server-side. |
| Hijri (v2) | `hijri_plus` or `hijri_core` | Umm al-Qura calendar with corrections. |
| Notifications | `flutter_local_notifications` + small native shims | Exact alarms, chronometer, actions. |
| Widgets | `home_widget` + WidgetKit (Swift) / Glance (Kotlin) | Shared storage hand-off. |
| Live Activity | `live_activities` bridge + own Swift extension | ActivityKit + App Intents need Swift regardless. |
| Firebase | `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_messaging` | Anonymous auth, settings/schedule publish, tokens. |
| Localisation | `flutter_localizations` + ARB files | Arabic/English, RTL. |

### 2.2 Module layout

```
lib/
  app/                 routing, theme, localisation bootstrap
  config/
    prayer_config.dart   calculation params, window-end rules, iqamah defaults  ← single source
  domain/
    prayer_engine/       PrayerDay, window ends, midnight, Ramadan adjustment
    schedule/            ScheduleBuilder: PrayerDay + IqamahProfile → PrayerEvent[]
    tracker/             PrayerStatus, logging rules, travel/combine rules
    qada/                balance derivation, plan projection
    stats/               period metrics, streaks
  data/
    db/                  Drift tables, DAOs, migrations
    backup/              JSON export/import, dry-run diff
    firebase/            DeviceDoc repository, schedule publisher
  platform/
    notifications/       scheduling policy (rolling window), action handling
    widget/              shared-store writer
    live_activity/       start/repair/end bridge, token relay
  features/
    home/ history/ stats/ qada/ settings/
ios/
  Runner/                 Flutter host
  PrayerLiveActivity/     Widget extension: Live Activity + home widgets (SwiftUI), App Intents
android/
  app/src/main/kotlin/    ExactAlarmReceiver, LiveNotificationBuilder, Glance widget
functions/                Firebase Cloud Functions (TypeScript)
```

### 2.3 Core domain types

```dart
enum Prayer { fajr, dhuhr, asr, maghrib, isha }          // dhuhr renders as Jumu'ah on Friday
enum PrayerStatus { jamaah, onTimeAlone, late, missed }  // absence of row == notLogged
enum LogSource { manual, notificationAction, liveActivity, import }

class PrayerDay {            // pure computation, no I/O
  final DateTime date;
  final Map<Prayer, DateTime> adhan;
  final DateTime sunrise;
  final DateTime islamicMidnight;
  DateTime windowEnd(Prayer p);          // per SRS FR-PT-04
}

class IqamahProfile {
  final String id; final String name;
  final Map<Prayer, int> offsetMinutes;
  final Map<Prayer, int>? mosqueOverride; // FR-IQ-03
}

class PrayerEvent {          // one row per prayer per day, consumed by every surface
  final Prayer prayer; final DateTime date;
  final DateTime adhanAt, iqamahAt, leaveByAt, closingAt, endAt;
}
```

`ScheduleBuilder.build(day, profile, settings) → List<PrayerEvent>` is the single function that turns times into events. Notifications, widget, Live Activity content state, Android live notification, and the published Firestore schedule all consume `PrayerEvent`. Nothing else derives times independently.

### 2.4 Local database (Drift)

```sql
-- settings: typed key/value; keys are constants in config/
CREATE TABLE settings (
  key   TEXT PRIMARY KEY,
  value TEXT NOT NULL             -- JSON-encoded
);

CREATE TABLE iqamah_profile (
  id          TEXT PRIMARY KEY,   -- 'normal' | 'ramadan' | uuid
  name        TEXT NOT NULL,
  offsets     TEXT NOT NULL,      -- JSON {fajr:25,...}
  mosque_override TEXT,           -- JSON or NULL
  is_builtin  INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE prayer_log (
  id           TEXT PRIMARY KEY,           -- uuid
  date         TEXT NOT NULL,              -- 'YYYY-MM-DD' local prayer date
  prayer       TEXT NOT NULL,              -- fajr|dhuhr|asr|maghrib|isha
  status       TEXT NOT NULL,              -- jamaah|on_time_alone|late|missed
  prayed_at    TEXT,                       -- ISO-8601, nullable (unknown for backfill)
  logged_at    TEXT NOT NULL,              -- ISO-8601
  source       TEXT NOT NULL,              -- manual|notification_action|live_activity|import
  travelling   INTEGER NOT NULL DEFAULT 0,
  combined_with TEXT,                      -- prayer name or NULL
  note         TEXT,
  UNIQUE (date, prayer)
);
CREATE INDEX idx_prayer_log_date ON prayer_log(date);

CREATE TABLE sunnah_log (
  date         TEXT NOT NULL,
  item         TEXT NOT NULL,              -- fajr_before|dhuhr_before|dhuhr_after|maghrib_after|isha_after|witr
  done         INTEGER NOT NULL DEFAULT 0,
  logged_at    TEXT NOT NULL,
  PRIMARY KEY (date, item)
);

CREATE TABLE qada_payment (
  id         TEXT PRIMARY KEY,
  prayer     TEXT NOT NULL,
  count      INTEGER NOT NULL CHECK (count > 0),
  date       TEXT NOT NULL,                -- day the payment was made
  logged_at  TEXT NOT NULL,
  note       TEXT
);

CREATE TABLE qada_opening_balance (
  prayer  TEXT PRIMARY KEY,
  count   INTEGER NOT NULL DEFAULT 0
);
```

**Derived, never stored**
```sql
-- qada balance per prayer (late_counts_as_qada read from settings)
SELECT p.prayer,
       COALESCE(ob.count,0)
     + (SELECT COUNT(*) FROM prayer_log l
         WHERE l.prayer = p.prayer
           AND (l.status = 'missed' OR (:late_counts AND l.status = 'late')))
     - COALESCE((SELECT SUM(count) FROM qada_payment q WHERE q.prayer = p.prayer),0) AS balance
FROM (SELECT DISTINCT prayer FROM prayer_log UNION SELECT prayer FROM qada_opening_balance) p
LEFT JOIN qada_opening_balance ob ON ob.prayer = p.prayer;
```

Streak rule (in Dart, over daily aggregates): a day counts toward the streak only if it has five rows and none is `missed`; a day with fewer than five rows is *neutral* — it neither extends nor breaks the streak (SRS AC-ST-2).

### 2.5 Tracker rules (domain layer)

| Situation | Rule |
|---|---|
| Log while window open | `prayed_at = now`; status chosen by user (jama'ah / alone). |
| Log after window closed, same or later day | status `late` unless the user explicitly chooses `missed`. UI defaults the button label to "Prayed late". |
| Friday, prayer = dhuhr, status ∈ {jamaah, on_time_alone} | stored as `jamaah` (FR-TR-07). |
| Travelling and combining | logging one of the pair offers "combined with X"; writes two rows with the same `prayed_at`, both `on_time_alone` or `jamaah`, `combined_with` set both ways. |
| Edit | updates `status`/`prayed_at`/`note`, sets `logged_at = now`. Backfill indicator = `logged_at.date > date`. |
| Delete | hard delete; balances recompute. |

### 2.6 Notification design

**Event set per prayer** (from `PrayerEvent`): pre-adhan (optional), adhan, leave-by, closing (only if unlogged), end prompt (only if unlogged).

**iOS**
- `UNUserNotificationCenter`, category with actions `LOG_JAMAAH`, `LOG_ALONE`, `NOT_YET`.
- Budget: up to 5 notifications × 5 prayers = 25/day. Rolling window = **2 days ahead** (≤ 50 pending), refreshed on: app foreground, BGAppRefresh, silent FCM push at 00:15 local (sent by `planDay`), and any settings change.
- Conditional notifications (closing, end prompt) are scheduled unconditionally and **cancelled** when the prayer is logged. Cancellation runs from the log write path and from the App Intent.
- Sound: bundled `.caf` ≤ 30 s. Document C1 in settings UI ("Full adhan plays when the app is open").

**Android**
- `flutter_local_notifications` `zonedSchedule` with `AndroidScheduleMode.exactAllowWhileIdle`; request `SCHEDULE_EXACT_ALARM` on Android 12+, handle the Android 14 revocation flow.
- Reschedule on `BOOT_COMPLETED` and on time-zone change (plugin receiver + own check on app start).
- Channels: `adhan` (sound, high), `reminders` (default), `live` (silent, ongoing).
- Actions on the end prompt identical to iOS; handled in a background isolate that writes to the DB via Drift and cancels dependent notifications.
- DND: `NotificationManager.setInterruptionFilter` for `iqamah → iqamah + N min` when `ACCESS_NOTIFICATION_POLICY` granted; restore after.

### 2.7 Live countdown surface

**Content model** (identical on both platforms, JSON in push and in shared store):

```json
{
  "prayer": "asr",
  "date": "2026-09-05",
  "phase": "iqamah",              // iqamah | window | closing
  "adhanAt": 1757075400,
  "iqamahAt": 1757076600,
  "closingAt": 1757087400,
  "endAt": 1757089200,
  "leaveByAt": 1757075700,
  "logged": false
}
```

Phase changes are pushed (iOS) or alarm-driven (Android), but every phase's view is computable from the timestamps alone; if an update is missed, the surface still shows a correct countdown (SRS FR-LA-09).

**iOS — ActivityKit**

| Element | Design |
|---|---|
| Attributes (static) | `prayer`, `date` |
| ContentState (dynamic) | `phase`, timestamps, `logged` |
| Lock screen / expanded | Prayer name (Arabic + transliteration), phase label, `Text(timerInterval:)` to `iqamahAt` (phase iqamah) or `endAt` (window/closing), secondary line "leave by HH:mm" in iqamah phase. Closing phase: red tint + three buttons. |
| Compact Dynamic Island | leading: prayer glyph; trailing: timer. |
| Minimal | timer only. |
| Buttons | `LogPrayerIntent(prayer, date, status)` — `LiveActivityIntent`, runs in-process, writes via Drift (through a small Swift→Dart channel *or* directly to the SQLite file using shared App Group path — **decision at M5**; the direct-SQLite route avoids launching Dart but duplicates the write rule). Ends the activity after logging. |
| Lifecycle | start ← push-to-start (server) or app-foreground repair; update ← push at `iqamahAt`, `closingAt`; end ← push at `endAt` with `dismissalPolicy: .immediate`, or from intent. On app foreground: end any activity whose `endAt` < now; start/repair the current one. |
| Tokens | On launch and on `pushToStartTokenUpdates` / `pushTokenUpdates`: write to Firestore `devices/{id}.tokens`. |
| Stale date | `staleDate = endAt`; `relevanceScore` higher in closing phase. |

**Android — live notification**

| Element | Design |
|---|---|
| Trigger | `ExactAlarmReceiver` at `adhanAt`, `iqamahAt`, `closingAt`, `endAt` (alarm extras carry the content JSON). |
| Notification | `NotificationCompat.Builder` ongoing, `setUsesChronometer(true)`, `setChronometerCountDown(true)`, `setWhen(target)`; `setOnlyAlertOnce(true)`; fixed ID `LIVE_NOTIFICATION_ID`. Closing phase adds the three actions. |
| Android 16+ (v2) | `requestPromotedOngoing(true)` + `ProgressStyle` for the status-bar chip. |
| Cancel | at `endAt` alarm, or from the log write path. |

### 2.8 Home widget

- App writes `next_event.json` (next `PrayerEvent` + today's log statuses) to the shared store (App Group `group.<bundle>` / `SharedPreferences`) on: app foreground, every log write, every notification/alarm fire.
- iOS `TimelineProvider`: entries at each event boundary; countdown via `Text(timerInterval:)`.
- Android Glance: `RemoteViews` chronometer; `AlarmManager` refresh at each boundary.

### 2.9 Backup

- Export: `{ "schema": 1, "exportedAt": ..., "settings": {...}, "profiles": [...], "prayerLog": [...], "sunnahLog": [...], "qadaPayments": [...], "qadaOpening": {...} }`.
- Import: parse → validate schema → dry-run diff (add / conflict-by-`(date,prayer)` / identical) → user confirms → transaction; conflicts resolved by newest `logged_at`.

---

## 3. Backend (Firebase)

### 3.1 Firestore schema

```
devices/{deviceId}                       // deviceId == Firebase Auth uid (anonymous)
  platform:        "ios" | "android"
  appVersion:      string
  tz:              "Asia/Riyadh"
  location:        { lat, lng, label }
  calc:            { method: "umm_al_qura", madhab: "shafi", adjustments: {isha: 0} }
  iqamah:          { profileId, offsets: {...}, mosqueOverride: {...}|null }
  ramadanMode:     bool
  travelMinutes:   int
  bufferMinutes:   int
  closingOffsetMin:int
  tokens:          { fcm, pushToStart, activity: { token, prayer, date } | null }
  updatedAt:       timestamp

devices/{deviceId}/schedule/{YYYY-MM-DD}  // published by the app, 30 days ahead
  fajr:    { adhanAt, iqamahAt, leaveByAt, closingAt, endAt }
  dhuhr:   { ... } asr: {...} maghrib: {...} isha: {...}
  source:  "app" | "server"
  publishedAt: timestamp
```

**Security rules**
```
match /devices/{deviceId} {
  allow read, write: if request.auth != null && request.auth.uid == deviceId;
  match /schedule/{day} {
    allow read, write: if request.auth != null && request.auth.uid == deviceId;
  }
}
```
Cloud Functions use the Admin SDK and bypass rules.

### 3.2 Functions (TypeScript, 2nd gen)

| Function | Trigger | Behaviour |
|---|---|---|
| `planDay` | Cloud Scheduler, hourly | For each device whose local time is 00:15–01:14: load `schedule/{tomorrow}`; if absent, compute with npm `adhan` from `calc`/`location`/`iqamah` and write it with `source: "server"`. Enqueue Cloud Tasks (see 3.3). Send one silent FCM data message `{type:"reschedule"}` so the app refreshes its iOS notification window. |
| `onDeviceWrite` | Firestore `devices/{id}` update | If `location`, `calc`, `iqamah`, `ramadanMode`, or offsets changed: delete pending tasks for today/tomorrow (by name prefix) and re-enqueue from the new schedule. |
| `sendLiveActivity` | HTTP, Cloud Tasks only (OIDC) | Body `{deviceId, date, prayer, event}`. Loads device + schedule, builds content state, sends FCM v1 with `apns.live_activity_token` = push-to-start token (event `start`) or activity token (`update`/`end`). Idempotent: skips if the device's `tokens.activity` already reflects a later state. |

### 3.3 Push timeline per prayer (iOS)

| When | Task name | FCM payload |
|---|---|---|
| `adhanAt` | `{id}-{date}-{prayer}-start` | `event: start`, `attributes-type: PrayerActivityAttributes`, full content state, `apns-priority: 10`, alert text "Asr — iqamah in 20 min" |
| `iqamahAt` | `…-window` | `event: update`, `phase: window` |
| `closingAt` | `…-closing` | `event: update`, `phase: closing`, alert "Asr ends in 30 min" (only if `logged == false` — the function checks the device doc's last `logged` marker written by the app's log path; if unknown, sends anyway) |
| `endAt` | `…-end` | `event: end`, `dismissal-date: now` |

Task names encode device, date, prayer, and event; Cloud Tasks rejects duplicate names for ~1 hour after completion, which gives free idempotency for retries.

Android devices get **no** pushes; their timeline runs entirely on local exact alarms.

### 3.4 Cost and limits
- Per iOS device: 20 tasks/day + 1 silent push + hourly `planDay` scan. Firestore reads/writes < 200/day/device. Well inside free quotas; Blaze required only because 2nd-gen Functions and Cloud Tasks need it. Set a budget alert at $5.
- APNs push-to-start has a per-device budget; 5 starts/day is far below it.

### 3.5 Failure modes

| Failure | Effect | Mitigation |
|---|---|---|
| Push-to-start delayed/lost | No Live Activity for that prayer | Adhan notification still fires locally; app foreground repairs. |
| Update (phase change) lost | Layout stays in previous phase but countdown is correct | Timestamps in initial state (FR-LA-09); end push independent. |
| End push lost | Activity lingers | `staleDate`; ended on next app foreground; 8-hour system cap. |
| Function/quota outage | No pushes | Zero impact on notifications, widget, tracker. |
| Schedule missing for a day | Server computes | Must use identical params — parity test in CI (see §4). |
| Token rotation | Pushes rejected | App re-publishes tokens on every launch; function marks device `tokens.invalidAt` on `Unregistered`. |

---

## 4. Testing strategy

| Layer | Approach |
|---|---|
| Prayer engine | Golden tests: 30 Jeddah dates vs Umm al-Qura published times (±1 min). Cross-check `adhan_dart` vs `adhan` on 365 dates × 3 locations. |
| Parity | CI job runs the npm `adhan` computation and the Dart computation on the same fixtures; fails on any minute difference. |
| Tracker/qada/stats | Unit tests on fixture datasets (90-day synthetic log with backfills, travel days, Fridays). |
| Notifications | Manual device matrix: iOS + Android, force-quit, reboot, Doze, time-zone change. Checklist in 03-Delivery-Plan. |
| Live Activity | Manual: push-to-start via Firebase console / cURL with a real token; phase updates; intents; 8-hour Isha case in winter (use a spoofed location such as a high-latitude city to force a long Isha window). |
| Backup | Round-trip test: export → wipe → import → stats identical. |

---

## 5. Repository and environments

- Mono-repo: `app/` (Flutter), `functions/`, `docs/`.
- Branches: `main` (release), `dev`; feature branches with PRs even solo — the PR description is the changelog.
- Environments: `dev` and `prod` Firebase projects; flavour-based `GoogleService-Info.plist` / `google-services.json`.
- Secrets: none in the repo; Firebase config files are per-flavour and git-ignored in `prod`.
- CI (GitHub Actions): `flutter analyze`, `flutter test`, parity job, `functions` lint/test.
