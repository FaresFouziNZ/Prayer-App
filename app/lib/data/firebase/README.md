# Firebase (not implemented in this skeleton)

Per SRS FR-SY and 02-Architecture.md §3, this module would hold:

- `DeviceDoc` repository: anonymous auth, publishing FCM/push-to-start/activity
  tokens, calculation params, iqamah profile, Ramadan mode, travel/buffer
  minutes to `devices/{id}`.
- Schedule publisher: writes the app's computed `PrayerEvent`s to
  `devices/{id}/schedule/{date}` for the next 30 days.

Deliberately out of scope for this pass (see the "Flutter app only" skeleton
scope). Tracker, sunnah, qada, and notes must never be sent to the backend
(FR-SY-05) — keep that in mind if this module is implemented later.
