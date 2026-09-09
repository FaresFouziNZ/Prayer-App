package com.fares.prayerapp.prayer_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import androidx.core.content.ContextCompat
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray

/**
 * Android home-screen widget (SRS FR-WD-01/02/03): next prayer name, its
 * adhan time, a countdown, and today's five per-prayer status dots.
 * `home_widget` (see [HomeWidgetProvider]) owns reading the
 * shared-preferences data Dart writes and re-invoking [onUpdate] at each
 * scheduled boundary (armed by `HomeWidgetScheduler.refresh` via
 * `HomeWidget.scheduleWidgetUpdates`) — this class only has to render
 * whatever's currently stored, entirely from raw timestamps, the same way
 * [LiveNotificationReceiver] does for the live notification.
 *
 * The countdown is a plain static string ("1h 19m left"), not a ticking
 * Chronometer — see `home_widget_scheduler.dart`'s class doc for why. This
 * class only *picks* which of the three precomputed strings applies, by
 * comparing the raw timestamps to now; it never formats a duration or
 * touches l10n itself.
 */
class PrayerWidgetProvider : HomeWidgetProvider() {
    private val dotIds = intArrayOf(
        R.id.widget_dot_0,
        R.id.widget_dot_1,
        R.id.widget_dot_2,
        R.id.widget_dot_3,
        R.id.widget_dot_4,
    )

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val event = currentEvent(widgetData)
        val now = System.currentTimeMillis()
        val todayStatus = todayStatus(widgetData)

        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.prayer_widget)
            val pendingIntent = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

            if (event == null) {
                views.setTextViewText(R.id.widget_prayer_name, "")
                views.setTextViewText(R.id.widget_adhan_label, "")
                views.setTextViewText(R.id.widget_countdown, "")
            } else {
                views.setTextViewText(R.id.widget_prayer_name, event.name)
                views.setTextViewText(R.id.widget_adhan_label, event.adhanLabel)

                val countdownText = when {
                    now < event.adhanAt -> event.beforeAdhanText
                    now < event.iqamahAt -> event.iqamahPhaseText
                    else -> event.windowPhaseText
                }
                views.setTextViewText(R.id.widget_countdown, countdownText)
            }

            dotIds.forEachIndexed { index, dotId ->
                val status = todayStatus.getOrNull(index)
                val colorRes = when (status) {
                    "jamaah" -> R.color.widget_status_jamaah
                    "onTimeAlone" -> R.color.widget_status_on_time
                    "late" -> R.color.widget_status_late
                    "missed" -> R.color.widget_status_missed
                    else -> R.color.widget_status_not_logged
                }
                views.setInt(dotId, "setColorFilter", ContextCompat.getColor(context, colorRes))
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    private data class Event(
        val name: String,
        val adhanLabel: String,
        val adhanAt: Long,
        val iqamahAt: Long,
        val endAt: Long,
        val beforeAdhanText: String,
        val iqamahPhaseText: String,
        val windowPhaseText: String,
    )

    /** The first stored event whose window hasn't ended yet — mirrors the
     * app's own `snapshot.events.firstWhere((e) => e.endAt.isAfter(now))`. */
    private fun currentEvent(widgetData: SharedPreferences): Event? {
        val raw = widgetData.getString("events", null) ?: return null
        val now = System.currentTimeMillis()
        return try {
            val array = JSONArray(raw)
            var fallback: Event? = null
            for (i in 0 until array.length()) {
                val obj = array.getJSONObject(i)
                val event = Event(
                    name = obj.getString("name"),
                    adhanLabel = obj.getString("adhanLabel"),
                    adhanAt = obj.getLong("adhanAt"),
                    iqamahAt = obj.getLong("iqamahAt"),
                    endAt = obj.getLong("endAt"),
                    beforeAdhanText = obj.getString("beforeAdhanText"),
                    iqamahPhaseText = obj.getString("iqamahPhaseText"),
                    windowPhaseText = obj.getString("windowPhaseText"),
                )
                fallback = event
                if (event.endAt > now) return event
            }
            fallback
        } catch (e: Exception) {
            null
        }
    }

    /** Five entries (Fajr..Isha), each a [PrayerStatus]-derived name
     * ("jamaah", "onTimeAlone", "late", "missed") or `null`/missing for
     * not-yet-logged — mirrors `Prayer.values` order from the Dart side. */
    private fun todayStatus(widgetData: SharedPreferences): List<String?> {
        val raw = widgetData.getString("todayStatus", null) ?: return emptyList()
        return try {
            val array = JSONArray(raw)
            (0 until array.length()).map { if (array.isNull(it)) null else array.getString(it) }
        } catch (e: Exception) {
            emptyList()
        }
    }
}
