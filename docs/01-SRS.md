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
| FR-PT-03 | M | Location: automatic (device GPS, coarse is sufficient) or manual (city search / coordinates). The active mode and last known location are persisted. |
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
| FR-NT-02 | M | Selectable adhan sound per prayer: system default, bundled adhan clip (≤30 s on iOS), or silent. |
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
| FR-TR-05 | M | Records can be edited or deleted; `logged_at` is updated on edit. |
| FR-TR-06 | M | Travel flag: a day or prayer can be marked *travelling*. When two prayers are combined, both are logged as on time under one timestamp with `combined_with` set. |
| FR-TR-07 | M | Jumu'ah logged as prayed is always `jamaah`. |
| FR-TR-08 | M | Optional note per record. |

**Acceptance criteria**
- AC-TR-1: A prayer cannot have two records for the same date (unique constraint enforced).
- AC-TR-2: A prayer left unlogged for 7 days shows as *not logged*, not *missed*, in every view and statistic.
- AC-TR-3: A backfilled record has `logged_at` later than the prayer's date and is visibly marked as backfilled in history.

### FR-QD — Qada

| ID | Pri | Requirement |
|---|---|---|
| FR-QD-01 | M | Qada balance per prayer = count of `missed` records (plus `late` records if the "late counts as qada" setting is on; default off) minus qada payments. |
| FR-QD-02 | M | The user can record a qada payment (prayer, count, date). History of missed and payments is preserved; balances are derived, never stored. |
| FR-QD-03 | M | The user can set an opening balance per prayer for qada from before the app was used. |
| FR-QD-04 | M | A qada plan: target payments per day/week and projected clearance date. |

**Acceptance criteria**
- AC-QD-1: Balances recompute correctly after editing or deleting a missed record or a payment.
- AC-QD-2: Toggling "late counts as qada" changes balances without altering any stored record.

### FR-SN — Sunnah tracker

| ID | Pri | Requirement |
|---|---|---|
| FR-SN-01 | M | Per day, toggles for rawatib: Fajr 2 before; Dhuhr 4 before, 2 after; Maghrib 2 after; Isha 2 after; Witr. |
| FR-SN-02 | M | Toggles are accessible from the same screen as prayer logging with one tap. |
| FR-SN-03 | S | Duha and other optional prayers. |

**Acceptance criteria**
- AC-SN-1: Sunnah state for any past day can be viewed and edited.

### FR-ST — Statistics

| ID | Pri | Requirement |
|---|---|---|
| FR-ST-01 | M | For a selectable period (7 / 30 / 90 days, Hijri month, all): jama'ah rate, on-time rate (jama'ah + on time alone), late count, missed count, not-logged count. |
| FR-ST-02 | M | Per-prayer breakdown of the same metrics. |
| FR-ST-03 | M | Streak: consecutive days with zero `missed` and all five logged. Current and best. |
| FR-ST-04 | M | Sunnah completion rate per rawatib. |
| FR-ST-05 | M | Not-logged prayers are excluded from rate denominators and shown separately. |

**Acceptance criteria**
- AC-ST-1: Statistics for a fixture dataset of 90 days match hand-computed values.
- AC-ST-2: A not-logged day does not break a streak; a `missed` record does.

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
| FR-UI-02 | M | Light and dark themes following the system by default. |
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
