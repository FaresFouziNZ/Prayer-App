package com.fares.prayerapp.prayer_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Re-arms the native live-notification alarms (SRS FR-LA-07, FR-NT-07) —
 * the two countdown phases plus the window-end dismiss safety net — after a
 * reboot: `AlarmManager` doesn't persist across one on its own,
 * and unlike the phases `flutter_local_notifications` schedules, these
 * aren't covered by that plugin's own `ScheduledNotificationBootReceiver`.
 * Reads [LiveAlarmStore]'s cache (written by [MainActivity] whenever Dart
 * schedules a live-notification alarm).
 *
 * An entry whose `triggerAtMillis` (this phase's *start*) has already
 * passed is still re-armed as-is, not skipped: `AlarmManager` fires an
 * overdue exact alarm immediately rather than dropping it, which is
 * exactly what's wanted when the phone was off (or mid-boot) at the moment
 * this phase should have started — otherwise a reboot landing inside an
 * already-active phase would silently show no live notification at all
 * until the *next* phase's boundary. Only skip once `whenMillis` (this
 * phase's own countdown *target* — iqamah for the first phase, window-end
 * for the second) has also passed, meaning a later phase now applies
 * instead; that phase's own entry re-arms (and catches up) independently.
 */
class LiveNotificationBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            "android.intent.action.QUICKBOOT_POWERON",
            "com.htc.intent.action.QUICKBOOT_POWERON",
            -> {}
            else -> return
        }

        val now = System.currentTimeMillis()
        for (entry in LiveAlarmStore.loadAll(context)) {
            if (entry.whenMillis <= now) {
                LiveAlarmStore.remove(context, entry.requestCode)
                continue
            }
            if (entry.isDismiss) {
                LiveNotificationReceiver.armDismiss(
                    context,
                    requestCode = entry.requestCode,
                    triggerAtMillis = entry.triggerAtMillis,
                    notifyId = entry.notifyId,
                    persist = false,
                )
            } else {
                LiveNotificationReceiver.arm(
                    context,
                    requestCode = entry.requestCode,
                    triggerAtMillis = entry.triggerAtMillis,
                    notifyId = entry.notifyId,
                    title = entry.title,
                    text = entry.text,
                    whenMillis = entry.whenMillis,
                    countDown = entry.countDown,
                    persist = false,
                )
            }
        }
    }
}
