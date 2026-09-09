package com.fares.prayerapp.prayer_app

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

/**
 * Posts/updates the Android live countdown notification (SRS FR-LA-07).
 * Fired directly by an [android.app.AlarmManager] exact alarm scheduled from
 * [MainActivity] — not through `flutter_local_notifications` — since that
 * plugin ties one notification id to exactly one future alarm, which can't
 * express "the same notification, updated at two more points in time" (see
 * live_notification_scheduler.dart's class doc for the full reasoning).
 *
 * Only the two early, non-interactive phases (counting down to Iqamah, then
 * to window end) go through this receiver. The later closing phase (with
 * the log-this-prayer actions) is posted by Dart instead, reusing
 * `flutter_local_notifications`' existing background-isolate action
 * handling rather than duplicating it natively.
 */
class LiveNotificationReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val notifyId = intent.getIntExtra(EXTRA_NOTIFY_ID, -1)
        if (notifyId == -1) {
            Log.w(TAG, "onReceive: missing notifyId, dropping")
            return
        }
        if (intent.getBooleanExtra(EXTRA_DISMISS, false)) {
            // The window-end safety net (see [arm]/[armDismiss] doc) — force
            // the notification away regardless of which phase currently owns
            // this id, independent of whether that phase's own expiry fired.
            NotificationManagerCompat.from(context).cancel(notifyId)
            return
        }
        val title = intent.getStringExtra(EXTRA_TITLE)
        if (title == null) {
            Log.w(TAG, "onReceive: missing title, dropping")
            return
        }
        val text = intent.getStringExtra(EXTRA_TEXT) ?: ""
        val whenMillis = intent.getLongExtra(EXTRA_WHEN, 0L)
        val countDown = intent.getBooleanExtra(EXTRA_COUNT_DOWN, true)

        val notificationManagerCompat = NotificationManagerCompat.from(context)
        if (!notificationManagerCompat.areNotificationsEnabled()) {
            Log.w(TAG, "onReceive: notifications not enabled, dropping")
            return
        }

        ensureChannel(context)

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(context.applicationInfo.icon)
            .setContentTitle(title)
            .setContentText(text)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setShowWhen(true)
            .setWhen(whenMillis)
            .setUsesChronometer(true)
            .setChronometerCountDown(countDown)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_STATUS)
            .build()

        notificationManagerCompat.notify(notifyId, notification)
    }

    companion object {
        private const val TAG = "LiveNotifReceiver"
        const val CHANNEL_ID = "live"
        const val EXTRA_NOTIFY_ID = "notifyId"
        const val EXTRA_TITLE = "title"
        const val EXTRA_TEXT = "text"
        const val EXTRA_WHEN = "when"
        const val EXTRA_COUNT_DOWN = "countDown"
        const val EXTRA_DISMISS = "dismiss"

        /// Matches the channel `initialize()` also creates from Dart
        /// (low importance, no sound) — whichever side runs first wins,
        /// since Android channel settings can't change after creation.
        fun ensureChannel(context: Context) {
            val manager =
                context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (manager.getNotificationChannel(CHANNEL_ID) != null) return
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Live countdown",
                NotificationManager.IMPORTANCE_LOW,
            )
            channel.description = "Ongoing countdown to Iqamah and window close"
            channel.setSound(null, null)
            manager.createNotificationChannel(channel)
        }

        /**
         * Arms (or re-arms) one native alarm targeting this receiver, and
         * persists it to [LiveAlarmStore] so [LiveNotificationBootReceiver]
         * can restore it after a reboot — shared by [MainActivity] (initial
         * scheduling from Dart) and the boot receiver (restoration), so the
         * two never drift apart on how the `PendingIntent` is built.
         */
        fun arm(
            context: Context,
            requestCode: Int,
            triggerAtMillis: Long,
            notifyId: Int,
            title: String,
            text: String,
            whenMillis: Long,
            countDown: Boolean,
            persist: Boolean = true,
        ) {
            val intent = Intent(context, LiveNotificationReceiver::class.java).apply {
                putExtra(EXTRA_NOTIFY_ID, notifyId)
                putExtra(EXTRA_TITLE, title)
                putExtra(EXTRA_TEXT, text)
                putExtra(EXTRA_WHEN, whenMillis)
                putExtra(EXTRA_COUNT_DOWN, countDown)
            }
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                requestCode,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                triggerAtMillis,
                pendingIntent,
            )
            if (persist) {
                LiveAlarmStore.save(
                    context,
                    requestCode,
                    triggerAtMillis,
                    notifyId,
                    title,
                    text,
                    whenMillis,
                    countDown,
                )
            }
        }

        /**
         * Arms a window-end safety-net alarm that force-dismisses [notifyId]
         * outright rather than posting anything — a distinct, third alarm
         * (see [NotificationKind.liveDismiss] on the Dart side) so removal
         * doesn't depend on the closing phase's own `timeoutAfter` actually
         * firing. Persisted the same way as [arm] so a reboot restores it too.
         */
        fun armDismiss(
            context: Context,
            requestCode: Int,
            triggerAtMillis: Long,
            notifyId: Int,
            persist: Boolean = true,
        ) {
            val intent = Intent(context, LiveNotificationReceiver::class.java).apply {
                putExtra(EXTRA_NOTIFY_ID, notifyId)
                putExtra(EXTRA_DISMISS, true)
            }
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                requestCode,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                triggerAtMillis,
                pendingIntent,
            )
            if (persist) {
                LiveAlarmStore.save(
                    context,
                    requestCode,
                    triggerAtMillis,
                    notifyId,
                    title = "",
                    text = "",
                    whenMillis = triggerAtMillis,
                    countDown = false,
                    isDismiss = true,
                )
            }
        }

        fun cancel(context: Context, requestCode: Int) {
            val intent = Intent(context, LiveNotificationReceiver::class.java)
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                requestCode,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            alarmManager.cancel(pendingIntent)
            LiveAlarmStore.remove(context, requestCode)
        }
    }
}
