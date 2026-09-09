# Software Requirements Specification — Prayer Discipline App (MVP)

| | |
|---|---|
| Working title | TBD |
| Version | 0.1 (draft) |
| Date | 2026-09-05 |
| Owner | Fares |
| Status | For review |

---

## 1. Introduction

### 1.1 Purpose
This document specifies the functional and non-functional requirements for the MVP of a personal prayer application for iOS and Android. It is written so that every requirement has an ID, a priority, and acceptance criteria that can be checked before a milestone is called done.

### 1.2 Product summary
Existing prayer apps solve prayer times, adhan, and qibla well. This product treats those as plumbing and focuses on **prayer discipline**: knowing exactly when to leave for jama'ah, logging honestly what happened, and seeing the truth in statistics and a qada plan. The distinguishing feature is a live countdown on the lock screen (iOS Live Activity / Android live notification) showing time remaining to iqamah and time remaining before the prayer window closes, with logging directly from that surface.

### 1.3 Scope of the MVP
In scope: prayer times, notifications, iqamah profiles, live countdown surface, home screen widget, prayer/sunnah tracker, qada, statistics, Ramadan mode, Arabic/English UI, local backup. A thin Firebase backend exists **only** to start, update, and end the iOS Live Activity remotely.

Out of scope for the MVP: see §6.

### 1.4 Definitions
| Term | Meaning in this document |
|---|---|
| Adhan time | The start of a prayer's time as computed by the calculation method. |
| Iqamah | The start of congregational prayer at the mosque, a fixed offset after adhan. |
| Prayer window | The interval from a prayer's adhan time to its end time (see FR-PT-04). |
| Jama'ah | Prayed in congregation at the mosque. |
| On time (alone) | Prayed within the window, not in congregation. |
| Late | Prayed after the window closed. |
| Missed | Not prayed; creates a qada obligation. |
| Qada | A missed obligatory prayer that must be made up. |
| Rawatib | The regular sunnah prayers attached to the five obligatory prayers. |
| Islamic midnight | Midpoint between Maghrib and the following Fajr. |
| Iqamah profile | A named set of per-prayer iqamah offsets (e.g. Normal, Ramadan). |
| Live surface | The iOS Live Activity (lock screen + Dynamic Island) or the Android ongoing notification with a live chronometer. |
| Live start | Adhan time plus a fixed grace period (5 minutes) — when the live surface first appears, so it doesn't compete with the adhan notification itself. |

### 1.5 References
- Adhan prayer-time library (Dart port `adhan_dart`, npm `adhan`).
- Firebase Cloud Messaging — Live Activity start/update/end via HTTP v1 API.
- Apple ActivityKit — Live Activities, push-to-start (iOS 17.2+), App Intents for interactive buttons (iOS 17+).
- Ministry of Islamic Affairs (KSA) circulars on iqamah intervals — current values to be confirmed at build time.

---

## 2. Overall description

### 2.1 Product perspective
A local-first Flutter application. All core behaviour works with no network. A Firebase project (Auth, Firestore, Cloud Functions, Cloud Tasks, FCM) provides one capability: scheduling and sending the pushes that drive the iOS Live Activity. Android needs no backend.

### 2.2 Users
- **Primary:** the developer (single user) during the MVP.
- **Design constraint:** nothing in the MVP should make later publication to the App Store / Play Store structurally impossible (no hard-coded personal identifiers, no per-user manual server setup).

### 2.3 Assumptions
- A1. Calculation method is Umm al-Qura by default; the user is in Saudi Arabia most of the time.
- A2. Saudi mosques follow a standard iqamah interval set by Ministry circular; per-mosque data is not needed.
- A3. iOS device runs iOS 17.2 or later (required for push-to-start). Android device runs Android 12 or later.
- A4. The user will accept notification, exact-alarm, and location permissions.
- A5. The developer has an Apple Developer account and a Firebase project on the Blaze plan.

### 2.4 Constraints
- C1. iOS notification sounds are capped at 30 seconds. A full-length adhan cannot play from a notification on iOS.
- C2. iOS cannot programmatically enable Do Not Disturb. DND-during-prayer is Android-only.
- C3. iOS caps pending local notifications at 64 per app. Notification scheduling must use a rolling window.
- C4. An iOS Live Activity lives at most 8 hours, then remains on the lock screen up to 4 more hours.
- C5. A Live Activity can be started only from the foreground or by an APNs push-to-start.
- C6. The Live Activity UI is native SwiftUI; the Android live notification is a platform notification. Neither is rendered by Flutter.
- C7. The Umm al-Qura method requires a +30 minute Isha adjustment during Ramadan, applied by the app, not the library.

---

## 3. Functional requirements

Priority: **M** = must (MVP), **S** = should (v2), **C** = could (v3). Only M items are in the MVP.

### FR-PT — Prayer times

| ID | Pri | Requirement |
|---|---|---|
| FR-PT-01 | M | The app computes the five daily prayer times plus sunrise locally, offline, using the Adhan library with the Umm al-Qura method by default. Other supported methods are selectable. |
| FR-PT-02 | M | The app computes Islamic midnight (midpoint of Maghrib to next Fajr) for the current day. |
| FR-PT-03 | M | Location: device GPS (coarse is sufficient), reverse-geocoded to a city name for display. Last known location and coordinates are persisted. |
| FR-PT-04 | M | Prayer window end times are defined as: Fajr → sunrise; Dhuhr → Asr; Asr → Maghrib; Maghrib → Isha; Isha → Islamic midnight. |
| FR-PT-05 | M | On Fridays, Dhuhr is presented as Jumu'ah. |
| FR-PT-06 | M | Ramadan mode applies the +30 minute Isha adjustment for the Umm al-Qura method and switches the iqamah profile (see FR-RM). |
| FR-PT-07 | S | Hijri date display and Gregorian↔Hijri conversion using the Umm al-Qura calendar with moon-sighting corrections. |

**Acceptance criteria**
- AC-PT-1: For 30 consecutive dates in Jeddah, computed times match the official Umm al-Qura published times within ±1 minute.
- AC-PT-2: With airplane mode on, today's and tomorrow's times display correctly.
- AC-PT-3: Changing location updates all displayed times, scheduled notifications, and the published schedule (FR-SY) within one app session.

### FR-NT — Notifications

| ID | Pri | Requirement |
|---|---|---|
| FR-NT-01 | M | Adhan notification at each prayer's adhan time, individually enable/disable per prayer. |
| FR-NT-02 | M | Selectable adhan sound per prayer: system default, bundled adhan clip (≤30 s on iOS), silent, or (Android) a custom sound — either picked from the system ringtone/notification list or imported from an arbitrary audio file. |
| FR-NT-03 | M | Pre-adhan reminder with a configurable offset (e.g. 10 minutes before). |
| FR-NT-05 | M | Window-closing reminder at a configurable offset before the window ends (default 30 minutes), only if the prayer has not been logged. |
| FR-NT-06 | M | End-of-window prompt: when the window closes and the prayer is unlogged, a notification asks "Did you pray X?" with actions Jama'ah / Alone / Not yet. Actions log without opening the app. |
| FR-NT-07 | M | Notifications must fire on schedule with the app killed, after device reboot, and (Android) under Doze. |
| FR-NT-08 | M | Android: optional DND during prayer for a configurable duration after iqamah, using the notification-policy permission. |
| FR-NT-09 | M | iOS: notifications are scheduled in a rolling window (≥ 2 days ahead) and refreshed on app open, on background refresh, and on a silent push from the backend. |

**Acceptance criteria**
- AC-NT-1: On both platforms, with the app force-quit, all five adhan notifications fire within 60 seconds of the computed time across 3 consecutive days.
- AC-NT-2: After a device reboot without opening the app, the next adhan notification still fires.
- AC-NT-3: Tapping "Jama'ah" on the end-of-window prompt creates a `prayer_log` row with status `jamaah` and `source = notification_action`.
- AC-NT-4: On iOS, pending notifications never exceed 64 and the schedule never runs empty while the backend is reachable.

### FR-IQ — Iqamah profiles

| ID | Pri | Requirement |
|---|---|---|
| FR-IQ-01 | M | Iqamah time per prayer = adhan time + offset from the active iqamah profile. |
| FR-IQ-02 | M | Profiles: **Normal** and **Ramadan** ship as editable defaults; the user may create **Custom** profiles. Default offsets are confirmed against the current Ministry circular (O1). |
| FR-IQ-03 | M | Per-prayer override for a single "my mosque" that differs from the standard. |
| FR-IQ-05 | M | The active profile switches automatically when Ramadan mode is on, and back when it is off. |

Default offsets (minutes after adhan) — confirmed against the current Ministry circular (O1):

| Prayer | Normal | Ramadan |
|---|---|---|
| Fajr | 25 | 20 |
| Dhuhr | 20 | 15 |
| Asr | 20 | 15 |
| Maghrib | 10 | 10 |
| Isha | 20 | 15 |

**Acceptance criteria**
- AC-IQ-1: Changing a profile value updates the next iqamah time, the widget, and the published schedule.
- AC-IQ-2: The Ramadan toggle changes the active profile and all downstream times in one action.

### FR-LA — Live countdown surface

| ID | Pri | Requirement |
|---|---|---|
| FR-LA-01 | M | For each prayer, a live surface appears at live start (adhan + 5 minutes) and shows the remaining time to iqamah (phase *iqamah*), then the remaining time until the window closes (phase *window*), then a closing state with logging actions (phase *closing*) — remaining visible throughout unless the prayer is logged first. |
| FR-LA-02 | M | iOS: implemented as an ActivityKit Live Activity with lock-screen, Dynamic Island compact/expanded, and StandBy presentations. Countdowns use timer-interval text so they tick without network updates. |
| FR-LA-03 | M | iOS: the activity is started by an APNs push-to-start sent by the backend at live start (adhan + 5 minutes); phase changes and end are also pushed. If a push is missed, opening the app starts or repairs the activity for the current prayer. |
| FR-LA-04 | M | iOS: the *closing* phase shows buttons Jama'ah / Alone / Not yet implemented as App Intents; tapping logs the prayer without opening the app and the activity ends. |
| FR-LA-05 | M | iOS: the activity ends at window end (pushed) or when the prayer is logged — whichever comes first — so it is never dismissable by the user without one of those two events. Stale activities are ended on next app open. |
| FR-LA-06 | M | Isha activity ends at Islamic midnight, keeping every activity under the 8-hour limit. |
| FR-LA-07 | M | Android: implemented as an ongoing notification with a chronometer countdown, posted by an exact alarm at live start (adhan + 5 minutes), replaced at iqamah and at closing (same notification ID), cancelled at window end or when logged. Closing phase has the same three action buttons. |
| FR-LA-08 | S | Android 16 Live Updates (status-bar chip) and Samsung Now Bar presentation. |
| FR-LA-09 | M | The initial content state carries all timestamps (live start, iqamah, closing, end) so the surface remains correct even if later updates are not delivered. |

**Acceptance criteria**
- AC-LA-1: On iOS with the app force-quit, the Live Activity appears within 60 seconds of live start (adhan + 5 minutes) for 5 consecutive prayers.
- AC-LA-2: The countdown shown matches the app's own iqamah time to the second.
- AC-LA-3: Tapping "Jama'ah" from the lock screen creates the log row and dismisses the activity without launching the app UI.
- AC-LA-4: No activity is visible on the lock screen more than 5 minutes after its window ended, provided the backend is reachable.
- AC-LA-5: On Android with the app force-quit, the live notification appears at live start (adhan + 5 minutes) and updates its content at iqamah and closing.
- AC-LA-6: If the prayer is not logged, the live surface for it never disappears between live start and window end.

### FR-WD — Home screen widget

| ID | Pri | Requirement |
|---|---|---|
| FR-WD-01 | M | Widget shows the next prayer name, its adhan time, and a live countdown; small and medium sizes. |
| FR-WD-02 | M | Widget data is written by the app to shared storage (App Group / SharedPreferences) and refreshed at each prayer transition. |
| FR-WD-03 | S | Widget shows today's log status per prayer (five dots). |

**Acceptance criteria**
- AC-WD-1: Widget shows the correct next prayer within 5 minutes of each transition without opening the app.

### FR-TR — Prayer tracker

| ID | Pri | Requirement |
|---|---|---|
| FR-TR-01 | M | For each day and each of the five prayers (Jumu'ah replacing Dhuhr on Friday), exactly one status may be recorded: `jamaah`, `on_time_alone`, `late`, `missed`. Absence of a record means *not logged*. |
| FR-TR-02 | M | The app never auto-marks a prayer as missed. Unlogged prayers remain unlogged until the user acts. |
| FR-TR-03 | M | Logging is possible from: the home screen (one tap per prayer), the end-of-window notification action, the iOS Live Activity buttons, and the day/history view for backfilling. |
| FR-TR-04 | M | Each record stores `logged_at` (when the entry was made) separately from the prayer date, so same-day logs are distinguishable from backfills. |
| FR-TR-05 | M | Records can be edited or deleted; `logged_at` is updated on edit. Deleting one half of a combined pair (FR-TR-06) also deletes its partner. |
| FR-TR-06 | M | Travel flag: a day or prayer can be marked *travelling*. When two prayers are combined, both are logged as on time under one timestamp with `combined_with` set. |
| FR-TR-07 | M | Jumu'ah logged as prayed is always `jamaah`. |
| FR-TR-09 | M | Logging a prayer as `late` or `missed` prompts for a reason, chosen from a fixed set of options (no free text): overslept, busy, forgot, travel, sick, other. Required to save; cleared if the record is later edited to a non-late/missed status. |

**Acceptance criteria**
- AC-TR-1: A prayer cannot have two records for the same date (unique constraint enforced).
- AC-TR-2: A prayer left unlogged for 7 days shows as *not logged*, not *missed*, in every view and statistic.
- AC-TR-3: A backfilled record has `logged_at` later than the prayer's date and is visibly marked as backfilled in history.
- AC-TR-4: Deleting either half of a combined pair removes both records; neither is left pointing at a `combined_with` prayer with no record of its own.

### FR-EX — Period-day exemption

| ID | Pri | Requirement |
|---|---|---|
| FR-EX-01 | M | Opt-in setting to enable period-day tracking; off by default so it stays invisible to users who don't need it. |
| FR-EX-02 | M | Any day may be marked or unmarked as a period day, including past days (backfill), from Home or the day-detail screen. |
| FR-EX-03 | M | A marked period day excuses all five prayers and the sunnah checklist (FR-SN): the logging UI for both is replaced with an excused notice, and nothing may be logged for it while marked. |
| FR-EX-04 | M | Period days are excluded from Stats (FR-ST) rate, streak, and sunnah-completion calculations entirely — neither logged, not-logged, nor missed. |
| FR-EX-05 | M | Period days are excluded from Qada balance calculations (FR-QD-01), even if a `missed` record already existed for that date before it was marked. |

**Acceptance criteria**
- AC-EX-1: With a day marked, Stats for any period spanning it shows the same totals as if the day didn't exist in the tracker at all.
- AC-EX-2: Marking a day that already has a `missed` record removes its qada contribution without deleting the underlying record.

### FR-QD — Qada

| ID | Pri | Requirement |
|---|---|---|
| FR-QD-01 | M | Qada balance per prayer = count of `missed` records minus qada payments, excluding period days (FR-EX-05). |
| FR-QD-02 | M | The user can record a qada payment (prayer, count, date). History of missed and payments is preserved; balances are derived, never stored. |
| FR-QD-03 | M | The user can set an opening balance per prayer for qada from before the app was used. |
| FR-QD-04 | M | A qada plan: target payments per day/week and projected clearance date. |

**Acceptance criteria**
- AC-QD-1: Balances recompute correctly after editing or deleting a missed record or a payment.

### FR-SN — Sunnah tracker

| ID | Pri | Requirement |
|---|---|---|
| FR-SN-01 | M | Per day, toggles for rawatib: Fajr 2 before; Dhuhr 4 before, 2 after; Maghrib 2 after; Isha 2 after; Witr. |
| FR-SN-02 | M | Toggles are accessible from the same screen as prayer logging with one tap. |
| FR-SN-03 | S | Duha and other optional prayers. |
| FR-SN-04 | S | Optional reminder notifications for rawatib, one global on/off toggle, timed around each rawatib's associated fard prayer's adhan/iqamah rather than independently scheduled. |

**Acceptance criteria**
- AC-SN-1: Sunnah state for any past day can be viewed and edited.

### FR-ST — Statistics

| ID | Pri | Requirement |
|---|---|---|
| FR-ST-01 | M | For a selectable period (7 / 30 / 90 days, Hijri month, all): jama'ah rate, on-time rate (jama'ah + on time alone), late count, missed count, not-logged count. |
| FR-ST-02 | M | Per-prayer breakdown of the same metrics. |
| FR-ST-03 | M | Streak: consecutive individual prayers logged as `jamaah`/`on_time_alone`, not consecutive full days. `missed` breaks the run; `late` and not-logged are both neutral (neither extend nor break it). Current and best. |
| FR-ST-04 | M | Sunnah completion rate per rawatib. |
| FR-ST-05 | M | Not-logged prayers are excluded from rate denominators and shown separately. |

**Acceptance criteria**
- AC-ST-1: Statistics for a fixture dataset of 90 days match hand-computed values.
- AC-ST-2: A not-logged prayer or a `late` one does not break a streak, and neither extends it; a `missed` record breaks it.
- AC-ST-3: A prayer logged before a period-exempt day (FR-EX) began still counts toward the streak; the rest of that day, left unlogged by the exemption, does not break it.

### FR-RM — Ramadan mode

| ID | Pri | Requirement |
|---|---|---|
| FR-RM-01 | M | Manual toggle, with automatic suggestion when the Hijri month is Ramadan. |
| FR-RM-02 | M | Effects: +30 min Isha (Umm al-Qura), Ramadan iqamah profile, imsak/iftar display on the home screen. |
| FR-RM-03 | M | The same settings are published to the backend (FR-SY). |

### FR-UI — Localisation and appearance

| ID | Pri | Requirement |
|---|---|---|
| FR-UI-01 | M | Arabic and English UI, switchable in-app, with full RTL layout in Arabic. |
| FR-UI-02 | M | Light and dark themes, following the system by default, with a manual override (System/Light/Dark) in Settings. |
| FR-UI-03 | M | Prayer names shown in Arabic script in both languages, with transliteration in English mode. |
| FR-UI-04 | M | Notification and Live Activity text localised. |

### FR-BK — Backup and export

| ID | Pri | Requirement |
|---|---|---|
| FR-BK-01 | M | Export all local data (settings, logs, sunnah, qada) to a single JSON file via the system share sheet. |
| FR-BK-02 | M | Import from a JSON file with a dry-run summary (rows to add / conflicts) before applying. |
| FR-BK-03 | S | Cloud sync (v2). |

**Acceptance criteria**
- AC-BK-1: Export → uninstall → reinstall → import reproduces identical statistics.

### FR-SY — Settings and schedule sync (backend)

| ID | Pri | Requirement |
|---|---|---|
| FR-SY-01 | M | On first launch the app signs in anonymously to Firebase and creates its device document. |
| FR-SY-02 | M | The app publishes to Firestore: FCM token, push-to-start token, current activity push token, timezone, location, calculation parameters, active iqamah profile, Ramadan mode. Updates are pushed whenever any of these change. |
| FR-SY-03 | M | The app publishes its own computed schedule (adhan, iqamah, closing, end per prayer) for the next 30 days on every launch and settings change. The backend uses this schedule as the source of truth. |
| FR-SY-04 | M | The backend computes times itself only when the published schedule does not cover the target day. |
| FR-SY-05 | M | Tracker data, sunnah, qada, and notes are **never** sent to the backend in the MVP. |

**Acceptance criteria**
- AC-SY-1: Firestore security rules allow a device to read and write only its own document and subcollections.
- AC-SY-2: A timestamp in a Live Activity push always equals the corresponding timestamp in the app's published schedule.

---

## 4. Non-functional requirements

| ID | Requirement |
|---|---|
| NFR-01 **Offline** | Every feature except FR-SY and the remote start of the iOS Live Activity works with no network. |
| NFR-02 **Reliability** | Adhan notifications are the highest-priority behaviour. No release ships if AC-NT-1 fails. |
| NFR-03 **Consistency** | A given prayer's adhan, iqamah, closing, and end times are identical across the home screen, widget, notifications, live surface, and backend pushes. |
| NFR-04 **Performance** | Cold start to home screen under 1.5 s on a mid-range device; prayer-time computation under 50 ms. |
| NFR-05 **Battery** | No persistent foreground service on Android outside the live-notification window. No background location tracking. |
| NFR-06 **Privacy** | No accounts. The backend holds only what FR-SY-02/03 list. No analytics SDKs in the MVP. |
| NFR-07 **Security** | Firestore rules scoped to the authenticated device. Cloud Function endpoints callable only by Cloud Tasks / Scheduler. No secrets in the app binary beyond Firebase config. |
| NFR-08 **Accessibility** | Dynamic type, RTL, VoiceOver/TalkBack labels on all logging controls. |
| NFR-09 **Maintainability** | Prayer-time parameters, iqamah defaults, and window-end rules live in one configuration module shared by app and widget code. |
| NFR-10 **Testability** | Prayer engine, tracker rules, qada arithmetic, and statistics are pure Dart with unit tests and fixture data. |

---

## 5. External interfaces

| Interface | Direction | Notes |
|---|---|---|
| Firebase Auth (anonymous) | App → Firebase | Device identity. |
| Firestore `devices/{id}` | App ↔ Firebase | Settings, tokens, published schedule. |
| FCM HTTP v1 | Cloud Function → APNs | Live Activity start/update/end, silent reschedule push. |
| ActivityKit | Native iOS | Live Activity lifecycle, push tokens, App Intents. |
| UNUserNotificationCenter | Native iOS | Local notifications with actions. |
| AlarmManager / NotificationManager | Native Android | Exact alarms, chronometer notification, actions. |
| WidgetKit / Glance | Native | Home screen widgets. |
| Location services | Device | Coarse location on demand only. |

---

## 6. Out of scope

**v2 (should):** qibla compass, Hijri calendar UI, azkar with counters, tasbih, hadith/ayah of the day, fasting tracker, cloud sync, Apple Watch / Wear OS, Android 16 Live Updates, monthly timetable.

**v3 (could):** Quran text/audio/bookmarks, Hisn al-Muslim, 99 Names, nearby mosques map.

**Not planned:** mosque announcements, Jumu'ah info, donations, zakat calculator, Hajj/Umrah guides. Family/friends sharing deferred indefinitely.

---

## 7. Open items

| # | Item | Owner | Needed by |
|---|---|---|---|
| O1 | ~~Confirm current Ministry iqamah offsets (Normal, Ramadan)~~ — resolved, see Decision log | Fares | M3 |
| O2 | ~~Choose between `adhan_dart` and `adhan` after the 30-day validation (AC-PT-1)~~ — resolved, see Decision log | Fares | M1 |
| O3 | ~~Working title / app name~~ — resolved, see Decision log | Fares | M0 |
| O4 | ~~Bundled adhan audio clip source and licence (≤30 s)~~ — deferred, ship with system default sound for now, see Decision log | Fares | M1 |
| O5 | ~~Decide closing-phase offset default (30 min proposed)~~ — resolved, see Decision log | Fares | M2 |

---

## Appendix A — Decision log

| Date | Decision | Rationale |
|---|---|---|
| 2026-09-05 | Personal project; no client, no pricing | Optimise for the developer's own use, keep publishable. |
| 2026-09-05 | Mosque features reduced to iqamah offsets | Saudi standard iqamah intervals; no per-mosque data source. Announcements, Jumu'ah info, donations excluded. |
| 2026-09-05 | Tracker granularity: jama'ah / on time alone / late / missed; never auto-mark missed | Honest data over completeness. |
| 2026-09-05 | Isha window ends at Islamic midnight | Preferred-time position; keeps the Live Activity under 8 hours. |
| 2026-09-05 | Live countdown surface is an MVP feature | The differentiator. |
| 2026-09-05 | Backend: Firebase, limited to Live Activity pushes | FCM supports Live Activity start/update/end; Cloud Tasks gives exact-time scheduling; anonymous auth avoids accounts. |
| 2026-09-05 | Prayer times computed locally (Adhan library), not via API | Offline reliability; the app publishes its schedule so the server never disagrees. |
| 2026-09-05 | Local storage: SQLite via Drift | Statistics are aggregate SQL queries. |
| 2026-09-06 | O2 resolved: stick with `adhan_dart` | Already the client-side implementation; the AC-PT-1 30-day accuracy validation against published Umm al-Qura times is still outstanding and separate from this library choice. |
| 2026-09-06 | Live surface starts at "live start" = adhan + 5 minutes, not at adhan itself, and stays visible through iqamah/window/closing until logged or window end | 5-minute grace period so it doesn't compete with the adhan notification; the live surface's whole point is to be an unmissable reminder, so it must not disappear on its own before the user acts. Spec-only for now — the live surface itself (FR-LA) still needs native Swift/Kotlin work not yet started. |
| 2026-09-06 | O1 resolved: Normal profile's Isha offset corrected to 20 minutes (was 15); all other Normal/Ramadan offsets confirmed as-is | Verified by Fares against the current Ministry circular. |
| 2026-09-06 | O3 resolved: app name is "My Prayer" (English) / "صلاتي" (Arabic) | Working title chosen. |
| 2026-09-06 | O4 deferred: ship with the system default notification sound; revisit a bundled adhan clip once a licensed source is found | No licensed ≤30s clip available yet; system default is a safe interim choice already supported by the notification-sound setting. |
| 2026-09-06 | O5 resolved: closing-phase offset default confirmed at 30 minutes | Matches `PrayerConfig.defaultClosingOffsetMinutes`, already shipped and user-configurable per prayer. |
| 2026-09-06 | Removed the leave-by reminder entirely: FR-NT-04 and FR-IQ-04 retired (IDs not reused), travel/buffer-minutes settings and the leave-by notification, Settings tiles, and next-prayer-card row all deleted | Product decision — dropped rather than kept as a disabled/unused feature. |
| 2026-09-06 | Removed the per-record note field entirely: FR-TR-08 retired (ID not reused), `note` column, sentinel, and note field/UI deleted from tracker, logging sheet, and backup | Product decision — notes added friction to logging with little use; qada payments keep their own separate `note` field, untouched. |
| 2026-09-06 | Removed the "late counts as qada" setting: FR-QD-01 simplified to `missed`-only balances, AC-QD-2 retired | Product decision — late prayers are still prayed on time-ish and shouldn't inflate the qada backlog; simplifies the balance rule to one case. |
| 2026-09-06 | Removed manual location entry: FR-PT-03 now GPS-only, reverse-geocoded to a city name via the `geocoding` package (falls back to raw coordinates if geocoding fails) | Product decision — manual lat/lng entry was fiddly and rarely needed; a city name reads better than raw coordinates. |
| 2026-09-07 | Fixed: deleting one half of a combined pair left the other half dangling (`combined_with` pointing at a deleted record); AC-TR-4 added | Bug found by inspection — `PrayerLogActions.delete` only ever deleted the tapped record. |
| 2026-09-07 | Added FR-TR-09: logging `late`/`missed` now requires picking a reason from a fixed set (overslept/busy/forgot/travel/sick/other), stored as `PrayerLogEntry.excuse`. FR-TR-08 stays retired (ID not reused) — this is a new, unrelated field, not a reintroduction of free-text notes | Product decision — a bounded reason list gives accountability/insight without the friction (or backend-privacy question) of free text. |
| 2026-09-07 | Home screen now shows which location today's prayer times are computed for (city name from FR-PT-03, or "Jeddah (default)" before any GPS fix is set) | Product decision — users were left guessing whether the schedule matched their actual location. |
| 2026-09-07 | Fixed: History's pre-install days were collapsed behind a dismiss-only notice with no way to view or backfill them | The app supports backfilling any past day (FR-TR-03); collapsing pre-install days into a one-way-dismissible summary accidentally blocked that for dates before install, even though a user might legitimately want to log one retroactively. The notice is now tap-to-expand, revealing normal tappable day rows; the dismiss (X) button still hides it entirely as before. |
| 2026-09-07 | Added FR-EX: opt-in period-day tracking — a marked day excuses all five prayers, excluded entirely from Stats and Qada rather than counted as missed/not-logged | Product decision — menstruation exempts a woman from prayer obligation; without this, those days would incorrectly drag down rates and inflate the qada backlog. |
| 2026-09-07 | FR-EX-03/04 extended to the sunnah checklist (FR-SN): a marked period day now also hides sunnah logging and excludes it from the FR-ST-04 completion rate | Product decision — the same exemption applies to sunnah as to the five obligatory prayers; the original pass only covered the fard prayers. |
| 2026-09-07 | Fixed: the Home countdown card didn't make clear whether it counted down to adhan or iqamah, and before adhan it silently counted down to iqamah instead — `LivePhase` gained a `beforeAdhan` phase, and the eyebrow above the countdown now names its target directly ("Time until Adhan"/"Iqamah"/"Time left to log") instead of a generic "Time remaining" | Bug found by inspection — `phaseAt()` had no phase for "before adhan", so `at.isBefore(iqamahAt)` matched trivially and the card showed an iqamah countdown (with only a small label beneath it) even hours before adhan. |
| 2026-09-07 | Removed the explicit Save button from the prayer-logging sheet (FR-TR-03): picking a status now commits and closes the sheet immediately — for `late`/`missed` this happens after a reason is picked (FR-TR-09 still applies), and for a combined pair after the combine checkbox and a combinable status are both set. The combine checkbox now sits above the status chips instead of below, since it must be set before the terminal status tap | Product decision — logging a prayer was one tap to open the sheet plus a second explicit Save tap; removing it makes FR-TR-03's "one tap per prayer" literal instead of "one tap plus a confirm." |
| 2026-09-07 | FR-ST-03 redefined: the streak now counts consecutive individual prayers, not consecutive full days (AC-ST-2 updated to match; AC-ST-3 added). Callers pass the streak an unfiltered day range instead of one with period-exempt days (FR-EX) removed, since an unlogged prayer is already neutral — this lets a prayer logged before a period began that day still count, while the rest of that day (left unlogged by the exemption) simply doesn't break the run, with no extra period-awareness needed inside `Streak` itself | Product decision — the old "all 5 logged, none missed" day-level rule buried individual consistency inside whole-day pass/fail, and silently dropped any prayer logged on a period day since day-level filtering removed it from consideration entirely; menstruation can begin partway through a day, so prayers already prayed that day are real and should still count. |
| 2026-09-07 | FR-ST-03 refined further: a `late` prayer is now neutral for the streak (like not-logged), instead of counting the same as `jamaah`/`on_time_alone`; AC-ST-2 updated to name `late` explicitly | Product decision — a late prayer was still prayed so it shouldn't reset the streak like `missed` does, but praying late isn't the on-time discipline the streak is meant to measure, so it shouldn't extend it either. |
| 2026-09-07 | Fixed: the Home next-prayer card never showed the window's close time (FR-PT-04) outside the brief *window* phase — before adhan it wasn't shown at all, and during *closing* it was replaced by a generic "Closing soon" with no time. The close time is now a persistent line under the adhan time, shown in every phase | Bug found by inspection — the close time was tied to the phase-dependent info row instead of being surfaced on its own, so a user checking a prayer well before its adhan, or in the final closing stretch, had no way to see the actual cutoff. |
| 2026-09-07 | FR-UI-02 extended: added a manual System/Light/Dark override in Settings → Appearance, next to the language picker. `theme_mode` was already a reserved settings key with no reader; `MaterialApp.themeMode` now follows it (falling back to `ThemeMode.system` for any other/missing value) instead of being hard-coded to `ThemeMode.system` | Product decision — the app already shipped a complete dark theme that only ever followed the OS setting, with no way to force either mode independent of it. |
| 2026-09-07 | FR-NT-07 (Android) implemented: `flutter_local_notifications` already ships a `ScheduledNotificationBootReceiver` that reloads and re-arms every pending `zonedSchedule` alarm on boot, but it isn't merge-registered by the plugin's own manifest — added `RECEIVE_BOOT_COMPLETED` and a `<receiver>` entry for it in the app's `AndroidManifest.xml`. AC-NT-2 verified on the emulator: real `adb reboot`, no app launch, `dumpsys alarm` showed the same ~20 alarms restored (confirmed by a `ActivityManager: Start proc ... for broadcast {.../ScheduledNotificationBootReceiver}` logcat line) | No native Kotlin code needed — the receiver class already existed in the plugin's Android source, just unwired. iOS reboot survival (FR-NT-09's rolling-window refresh) is unaffected and was already spec'd separately. |
| 2026-09-07 | NFR-04 measured (Android emulator, release build — not the "mid-range device" the target names, so treat as directional): cold start (`am start -W`, 5 runs after `pm clear` + `force-stop`) averaged ~1301 ms TotalTime (1183–1593 ms range) against the 1.5 s budget; `PrayerTimeCalculator.computeForDate` averaged 0.098 ms/call over 2000 iterations against the 50 ms budget (~500× headroom) | One of five cold-start runs (1593 ms) slightly exceeded the 1.5 s budget — plausibly emulator scheduling noise rather than a real regression, but worth re-checking on physical hardware before treating NFR-04 as fully closed. The calc-time budget is not in question given the margin. |
| 2026-09-07 | NFR-04 re-measured on physical hardware (OnePlus 7T Pro, Android 12, release build): cold start averaged ~375 ms (330–399 ms range) — a ~3.5× margin under the 1.5 s budget, and roughly 3.5× faster than the same measurement on the emulator | Confirms the emulator numbers were pessimistic noise, not representative — NFR-04 is comfortably met on real hardware with no close calls across 5 runs. Closes out the "treat as directional" caveat from the emulator-only measurement. |
| 2026-09-07 | FR-NT-08 (Android auto-DND) implemented using the `android_alarm_manager_plus` plugin instead of native Kotlin: two `AndroidAlarmManager.oneShotAt` alarms per prayer (enable "priority only" at iqamah, restore "all" at iqamah + the configured duration), each running `DndService` directly in a background isolate. Applies uniformly to every prayer under the one existing global toggle — there's no per-prayer DND setting. Verified live: enabling the setting (after granting Modes access) armed exactly 2 alarms × 7 remaining prayers in `dumpsys alarm`, with times matching iqamah and iqamah+duration to the millisecond; disabling it cancelled all of them | Product decision — this needed some background-execution primitive since `do_not_disturb` has no scheduling of its own and a plain Dart `Timer` doesn't survive the app being killed; a well-maintained plugin built exactly for "run Dart code at a scheduled time" was chosen over hand-writing an equivalent native `AlarmManager` + `BroadcastReceiver`, keeping the DND on/off calls themselves in Dart where `DndService` already lived. |
| 2026-09-07 | FR-LA-07 (Android live countdown notification) implemented as a hybrid: the two early, non-interactive phases (counting down to Iqamah, then to window end) are posted by a new native `LiveNotificationReceiver`, armed by exact alarms from `MainActivity` via a `live_notification` method channel — bypassing `flutter_local_notifications`' own scheduling, which ties one notification id to exactly one future alarm and can't express a *third* future update to the same id without the second alarm silently overwriting the first before it fires. The later, interactive closing phase (with the Jama'ah/Alone/Not-yet actions) is scheduled the ordinary way through `flutter_local_notifications`, reusing its existing action handling — no new code needed for that part, and `timeoutAfter` auto-cancels it at window end without a fourth alarm. All three phases share one notification id (`NotificationKind.live`), so each replaces the last on screen; logging the prayer early cancels all of it (native alarms + Dart-scheduled entry) via `PrayerLogActions`. Verified live end-to-end: `dumpsys alarm` showed the native alarms armed at the exact computed adhan+5min/iqamah times; a temporary `exported=true` build confirmed the notification renders correctly (ongoing chronometer, correct title/text) before reverting to the correct `exported=false` | Product decision — full native fidelity for all three phases, matching the architecture doc's original plan, since this is the app's signature feature (SRS §1.2) and a partial version (interactive closing phase only) would have skipped FR-LA-01's earlier "time remaining to Iqamah" / "time remaining to log" phases entirely. |
| 2026-09-07 | FR-LA-07's reboot-survival gap (noted above) closed: added `LiveAlarmStore` (a small `SharedPreferences` cache, mirroring `flutter_local_notifications`' own approach) that `LiveNotificationReceiver.arm`/`.cancel` keep in sync on every schedule/cancel call, plus a new `LiveNotificationBootReceiver` that reloads the cache and re-arms every still-future entry on boot. First confirmed as a real, not just theoretical, gap on physical hardware (OnePlus 7T Pro, Android 12): after a real `adb reboot` + unlock, the regular notifications came back (via `flutter_local_notifications`' own boot receiver) but the two live-notification alarms did not. After the fix, a second real reboot on the same device restored all 14 live-notification alarms with byte-for-byte identical trigger times to what was persisted pre-reboot | Real-device testing surfaced this immediately where emulator testing hadn't — worth remembering as a concrete case for why FR-NT-07/FR-LA-07-style OS-integration features need a physical-device pass, not just emulator verification, before being called done. |
| 2026-09-07 | FR-WD-01/02 (Android home-screen widget) implemented using the `home_widget` plugin — `PrayerWidgetProvider` (a plain `AppWidgetProvider`/RemoteViews widget, not Jetpack Glance, though the plugin pulls Glance in as a transitive dependency either way) renders whatever's in shared storage, and `HomeWidgetScheduler.refresh` (Dart) writes the rolling window's events as JSON and calls `HomeWidget.scheduleWidgetUpdates` with each event's adhan/iqamah/window-end boundary — the plugin's own alarm scheduling and `HomeWidgetScheduledUpdateReceiver` (registered in the manifest, same "not merge-registered by the plugin itself" pattern as FR-NT-07/FR-NT-08) handle exact-alarm-backed refresh and reboot survival natively, needing no custom Kotlin for either. The widget never ships a phase label (unlike the in-app card or the live notification) — just name, adhan time, and a bare countdown, matching FR-WD-01's literal wording; FR-WD-03's status dots are deferred (still "S" priority). Verified live on the real OnePlus device: correct data/Arabic content, a single correctly-timed scheduler alarm, and the widget rendering and ticking correctly once pinned to the home screen | Product decision — `home_widget`'s own scheduler already does exactly what FR-LA-07 needed custom native code for (exact alarms + reboot survival), so no bespoke alarm/boot-receiver pair was needed here, unlike FR-LA-07's genuine one-id-one-alarm constraint. |
| 2026-09-07 | Discovered while testing FR-WD-01's countdown: `RemoteViews.setChronometer`'s `countDown=true` does not show a plain positive number decreasing to zero — its raw `elapsedRealtime() − base` value is negative until `base` is reached (displayed with a leading "−", i.e. "T-minus" style, matching how iOS's own system countdown timers commonly display too) and only positive after, counting up from there. Confirmed via two timed screenshots that the magnitude was genuinely decreasing at the correct rate (not a wrong-direction bug) — superseded the same day by the next entry, which replaces the format entirely rather than keeping this convention | Initially kept as-is (a recognized platform convention, not a bug), but the user asked for both a visual redesign and a non-"T-minus", non-colon-separated countdown, which this entry's reasoning no longer reflects — left here for the debugging trail, not as the shipped behavior. |
| 2026-09-07 | FR-WD-01's widget redesigned end-to-end: (1) countdown changed from a ticking `Chronometer` to a plain static string like "1h 20m left" (Arabic: "متبقٍ 1س 20د"), precomputed in Dart (`HomeWidgetScheduler`) and just *selected* (not formatted) natively — two of the three phase strings are exact durations between two already-known timestamps (`iqamahAt − adhanAt`, `endAt − iqamahAt`), so they're never stale despite not depending on "now" at read time; (2) visual redesign: a flat rounded card with a colored accent bar, bold prayer name, muted adhan-time line, and the countdown in the accent color, using new theme-aware `values`/`values-night` color resources drawn from `AppTheme`'s own light/dark palette so the widget follows the system theme like the rest of the app. Hit and fixed one bug along the way: a plain `<View>` used for the accent bar isn't in RemoteViews' view-class whitelist ("Class not allowed to be inflated") — swapped for a childless `FrameLayout`, which is allowed. Verified live on the real device in both light and dark system theme | Product decision, in response to explicit feedback that the ticking colon-separated "T-minus" countdown and the plain teal-block visual were both unwanted — chose static hours+minutes text over keeping any live ticking, since a widget refreshed only a few times per prayer can't honestly show second-level precision anyway. |
| 2026-09-07 | FR-NT-02 extended with a Android-only "custom" adhan sound, sourced from either the system ringtone/notification picker or an imported audio file (user asked for both). Confirmed against `flutter_local_notifications`' own source that a channel's sound is fixed at creation and silently ignored on later `createNotificationChannel` calls with the same ID (Android's own platform behavior, not a plugin limitation) — so the adhan-kind notification's channel is now derived per-prayer, `'adhan_custom_<prayer>_<hash-of-uri>'`, only when that prayer's sound is 'custom'; picking a new file naturally yields a new channel ID (self-managing, no manual version counter), and `_adhanChannelIdFor` sweeps any of that prayer's now-unused custom channels on the next schedule pass. `preAdhan`/`closing`/`endPrompt` are unaffected — they stay on the shared `reminders` channel with the existing default/silent behavior; only the adhan notification itself gets the custom sound. No pub.dev plugin exists for "launch the system ringtone picker and get a URI back," so that half is native (`MainActivity`'s new `sound_picker` channel, `RingtoneManager.ACTION_RINGTONE_PICKER` via classic `startActivityForResult`/`onActivityResult` since `FlutterActivity` extends plain `Activity`, not `ComponentActivity`). The file-import half copies the picked file into `MediaStore`'s Notifications collection (`SoundImporter`, Android 10+ only — scoped storage's `RELATIVE_PATH`/`IS_NOTIFICATION` columns) so the system's notification-manager *process* (not just this app) can read it back at fire time, the same mechanism apps use to add a custom ringtone; a raw SAF `content://` grant from the file picker is scoped to this app only and isn't reliably readable by that other process. `file_picker`'s `.path` is only non-null for `file://` URIs, so the picked bytes are read and staged to a temp file before handing a plain path to native code. Verified live: on a Pixel-profile emulator (Android 17), `ACTION_RINGTONE_PICKER` launches a real, fully interactive system sound picker and a cancelled pick returns cleanly (`resultCode=0`, `uri=null`, prayer stays on its previous setting); the raw-file path correctly launches an Audio-filtered SAF browser. On the real OnePlus 7T Pro (Android 12, OxygenOS), the *same* intent resolves to two OEM handlers ("Select sound", "Sound & vibration") that both return an immediate `RESULT_CANCELED` with no picker UI shown at all, regardless of `EXTRA_RINGTONE_SHOW_DEFAULT` — confirmed via logcat as a clean, non-crashing return, not a bug in this app's code, and treated as an OEM limitation on that device rather than something fixable in-app. The raw-file-import path is unaffected by this and works on both. Also fixed a real overflow: the new three-segment Default/Silent/Custom control plus an "edit" icon didn't fit squeezed into the same row as the prayer name and enable switch (worse in Arabic, whose labels run longer) — the per-prayer tile was restructured so the sound control gets its own full-width row below the name/switch row | Product decision — scoped to Android only, matching every other OS-integration feature this session (C1: iOS caps notification sounds at 30s and this dev environment has no Xcode/macOS to build or test an iOS counterpart anyway). Custom sound applies only to the adhan-kind notification, not the reminder-kind ones, since a user-picked file (potentially a multi-minute adhan recitation) blaring for a "5 minutes left" ping would be poor UX, and the existing per-prayer Default/Silent toggle already covers those. |
| 2026-09-07 | FR-WD-03 implemented: five small status dots on the widget, one per prayer (Fajr..Isha), tinted by that prayer's log status for today. `HomeWidgetScheduler.refresh` now also fetches today's logs (`PrayerLogRepository.getForDay`) and writes a `todayStatus` JSON array (5 entries, `PrayerStatus.name` or `null` for not-logged, in `Prayer.values` order) alongside the existing `events` array; `PrayerWidgetProvider` parses it and calls `RemoteViews.setInt(dotId, "setColorFilter", color)` on five pre-declared `ImageView`s, picking one of five new theme-aware color resources (`widget_status_jamaah/on_time/late/missed/not_logged`, chosen to echo `PrayerColors`' primary/tertiary/secondary/error/outline mapping — RemoteViews can't reach Flutter's Material3-seed-derived scheme directly, so these are independently authored fixed hex values, same approach as the rest of the widget's palette). The dots are only as fresh as the rest of the widget's content — refreshed on app open/resume and on any settings change (`NotificationCoordinator.scheduleUpcomingWindow`'s existing triggers), not on every individual prayer log — logging a prayer doesn't itself trigger a widget refresh today, and adding that trigger was judged disproportionate for an "S"-priority feature. Verified the Dart→native data pipeline directly: after logging Fajr=Jama'ah, Dhuhr=Late, Asr=Missed on the emulator and resuming the app, the on-device `HomeWidgetPreferences.xml` read back exactly `"todayStatus":["jamaah","late","missed",null,null]`, byte-for-byte correct for the actions taken. Pixel-level rendering wasn't additionally screenshotted — ADB's `input`/`motionevent` tools couldn't reliably drive the emulator launcher's long-press-drag-to-place gesture for a widget picker sheet (a tooling limitation, not an app issue) — but the rendering code reuses the identical `JSONArray`-parsing and `RemoteViews.setInt`/view-id pattern already proven correct for the widget's name/time/countdown fields earlier this session | Product decision — kept scope to exactly FR-WD-03's literal wording (five dots, log status only); did not add period-day (FR-EX) awareness or a dedicated log-time refresh trigger, since neither was asked for and both would be scope creep on a low-priority item. |
| 2026-09-08 | Real-device testing (release build, OnePlus 7T Pro) found and fixed: (1) FR-LA-07's live countdown notification never appeared for a prayer whose current phase had already started by the time the app (re)scheduled it — `AndroidLiveNotificationScheduler.scheduleForDay` only ever armed *future* triggers (`if (at.isBefore(now)) cancel`), so opening the app (or a fresh install) partway through a prayer's live-countdown window skipped it entirely instead of catching up; fixed by arming with the phase's literal start time even when already in the past (`AlarmManager.setExactAndAllowWhileIdle` fires an overdue exact alarm immediately rather than dropping it) and only cancelling once a *later* phase's boundary has passed, plus an equivalent fix to the closing phase (posts immediately via `.show()` instead of `.zonedSchedule()` when already inside that phase) and to `LiveNotificationBootReceiver`'s reboot restoration (same catch-up-by-arming-a-past-time principle, gated on the entry's own countdown target rather than its start, since the boot receiver has no cross-phase context to compare against). (2) The Home screen's countdown correctly ticked every second (`NextPrayerCard`'s own `Timer`) but never advanced to the *next* prayer once the current one's window ended, since *which* event is "next" was only recomputed when Home itself rebuilt (app resume, log, pull-to-refresh) — fixed by converting `HomeScreen` to a `ConsumerStatefulWidget` that schedules a one-shot `Timer` for the current next-event's `endAt` on every build, forcing exactly one rebuild right when the transition should happen, rather than polling. (3) The Home tab's AppBar ("Today"/"اليوم") was removed as redundant, given the date is already shown inline in the body; `body` is now wrapped in `SafeArea` directly since there's no AppBar to handle the top inset anymore. (4) The bottom-nav Home tab was renamed to "Timings"/"المواقيت" (`navHome`). (5) Fixed a real overflow: Settings' Language and Theme rows squeezed a `SegmentedButton` into a `ListTile`'s `trailing` slot, and Theme's three segments left too little width for the "Theme" title, wrapping it one character per line — both now use a new `_SegmentedSettingTile` (label on its own line, segmented control in its own full-width row below, same fix shape as the FR-NT-02 custom-sound tile's earlier overflow) | Bugs 1-2 were found only by using a release build on real hardware across a real elapsed prayer window — nothing in the emulator-based testing pattern this session had exercised "open the app significantly after a live phase should already be showing," which is arguably the *most* realistic real-world case for an always-on countdown feature. |
| 2026-09-08 | FR-SN-04 added and implemented: optional rawatib reminders, one global on/off toggle (no per-item settings). Rawatib have no adhan time of their own, so each item's trigger is derived from its associated fard prayer's own event: the "before" items (`fajrBefore`, `dhuhrBefore`) fire at that prayer's adhan (the conventional adhan-to-iqamah gap they're prayed in); the "after" items (`dhuhrAfter`, `maghribAfter`, `ishaAfter`) fire a fixed buffer past that prayer's iqamah (`PrayerConfig.sunnahAfterOffsetMinutes` = 15, approximating when the fard prayer is likely finished — exact completion isn't tracked); Witr gets a longer buffer (`sunnahWitrOffsetMinutes` = 30) since it's prayed after Isha's own "after" pair. A new `SunnahNotificationScheduler` (parallel to the existing fard/live schedulers, driven by `NotificationCoordinator` the same way) owns this, using ordinary `flutter_local_notifications` one-shot scheduling (no native code needed) with its own IDs (`NotificationIds.forSunnahItem`, a `date*100+90+itemIndex` scheme kept deliberately clear of `forEvent`'s `date*100+prayerIndex*10+kind` range so the two can never collide). Already-completed items are skipped/cancelled at schedule time (`SunnahRepository.getForDay`), and marking an item done from the checklist immediately cancels its own pending reminder (mirroring how logging a fard prayer cancels its closing/end-prompt notifications) rather than waiting for the next scheduling pass. Off by default (existing users shouldn't see a new notification category appear unannounced); unlike the other settings toggles on this screen, flipping it calls `NotificationCoordinator.scheduleUpcomingWindow` immediately instead of waiting for the next app resume, so the feature is testable right away | Product decision, following up on real-device testing feedback ("no settings for sunnah notifications") — confirmed with the user that reminders tied to the associated fard prayer's own timing (rather than fully independent scheduling) was the intended shape before building it. |
