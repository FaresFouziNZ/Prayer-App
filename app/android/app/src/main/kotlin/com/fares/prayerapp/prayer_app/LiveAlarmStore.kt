package com.fares.prayerapp.prayer_app

import android.content.Context
import org.json.JSONObject

/**
 * Persists pending live-notification native alarms (SRS FR-LA-07) so
 * [LiveNotificationBootReceiver] can re-arm them after a device reboot —
 * `AlarmManager`'s own table is wiped on reboot, and unlike the phase
 * `flutter_local_notifications` schedules, these bypass that plugin's own
 * SharedPreferences-backed reschedule mechanism entirely (see
 * [LiveNotificationReceiver]'s doc comment for why). Mirrors that plugin's
 * approach: a flat key/value cache, one entry per pending alarm, read back
 * in full on boot.
 */
object LiveAlarmStore {
    private const val PREFS_NAME = "live_alarm_store"

    data class Entry(
        val requestCode: Int,
        val triggerAtMillis: Long,
        val notifyId: Int,
        val title: String,
        val text: String,
        val whenMillis: Long,
        val countDown: Boolean,
        val isDismiss: Boolean = false,
    )

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    private fun keyFor(requestCode: Int) = "alarm_$requestCode"

    fun save(
        context: Context,
        requestCode: Int,
        triggerAtMillis: Long,
        notifyId: Int,
        title: String,
        text: String,
        whenMillis: Long,
        countDown: Boolean,
        isDismiss: Boolean = false,
    ) {
        val entry = JSONObject().apply {
            put("requestCode", requestCode)
            put("triggerAtMillis", triggerAtMillis)
            put("notifyId", notifyId)
            put("title", title)
            put("text", text)
            put("whenMillis", whenMillis)
            put("countDown", countDown)
            put("isDismiss", isDismiss)
        }
        prefs(context).edit().putString(keyFor(requestCode), entry.toString()).apply()
    }

    fun remove(context: Context, requestCode: Int) {
        prefs(context).edit().remove(keyFor(requestCode)).apply()
    }

    fun loadAll(context: Context): List<Entry> {
        return prefs(context).all.values.mapNotNull { value ->
            if (value !is String) return@mapNotNull null
            try {
                val json = JSONObject(value)
                Entry(
                    requestCode = json.getInt("requestCode"),
                    triggerAtMillis = json.getLong("triggerAtMillis"),
                    notifyId = json.getInt("notifyId"),
                    title = json.getString("title"),
                    text = json.getString("text"),
                    whenMillis = json.getLong("whenMillis"),
                    countDown = json.getBoolean("countDown"),
                    // Absent on entries persisted before this field existed.
                    isDismiss = json.optBoolean("isDismiss", false),
                )
            } catch (e: Exception) {
                null
            }
        }
    }
}
