/// Status of a logged prayer. Absence of a record means *not logged*
/// (SRS FR-TR-01) — there is deliberately no `notLogged` value here.
enum PrayerStatus { jamaah, onTimeAlone, late, missed }

/// Where a log entry was written from (SRS §2.3).
enum LogSource { manual, notificationAction, liveActivity, import }
