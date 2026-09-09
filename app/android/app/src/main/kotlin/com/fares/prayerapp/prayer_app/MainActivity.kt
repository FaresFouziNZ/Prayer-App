package com.fares.prayerapp.prayer_app

import android.content.Intent
import android.media.RingtoneManager
import android.net.Uri
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Hosts the `live_notification` method channel (SRS FR-LA-07): Dart computes
 * *when* and *what*, native code owns arming the exact alarms that fire
 * [LiveNotificationReceiver] even with the app killed. See that class and
 * live_notification_scheduler.dart for why this bypasses
 * `flutter_local_notifications`' own scheduling for these two phases.
 * Reboot survival for these alarms is [LiveNotificationBootReceiver]'s job,
 * fed by the same [LiveNotificationReceiver.arm] persisting each one.
 *
 * Also hosts `sound_picker` (SRS FR-NT-02's custom sound): no pub.dev plugin
 * launches Android's system ringtone/notification picker and returns the
 * picked URI, so that half is native here. `FlutterActivity` extends the
 * plain `Activity` class, not `ComponentActivity`, so the modern Activity
 * Result API isn't available — this uses the classic
 * `startActivityForResult`/`onActivityResult` pair instead. The raw-file
 * half hands off to [SoundImporter].
 */
class MainActivity : FlutterActivity() {
    private val liveNotificationChannel = "live_notification"
    private val soundPickerChannel = "sound_picker"
    private val ringtonePickerRequestCode = 4201
    private var pendingRingtoneResult: MethodChannel.Result? = null

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == ringtonePickerRequestCode) {
            @Suppress("DEPRECATION")
            val uri: Uri? = data?.getParcelableExtra(RingtoneManager.EXTRA_RINGTONE_PICKED_URI)
            pendingRingtoneResult?.success(uri?.toString())
            pendingRingtoneResult = null
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, liveNotificationChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "schedule" -> {
                        @Suppress("UNCHECKED_CAST")
                        val args = call.arguments as Map<String, Any>
                        LiveNotificationReceiver.arm(
                            context = this,
                            requestCode = (args["requestCode"] as Number).toInt(),
                            triggerAtMillis = (args["triggerAtMillis"] as Number).toLong(),
                            notifyId = (args["notifyId"] as Number).toInt(),
                            title = args["title"] as String,
                            text = args["text"] as String,
                            whenMillis = (args["whenMillis"] as Number).toLong(),
                            countDown = args["countDown"] as Boolean,
                        )
                        result.success(null)
                    }
                    "scheduleDismiss" -> {
                        @Suppress("UNCHECKED_CAST")
                        val args = call.arguments as Map<String, Any>
                        LiveNotificationReceiver.armDismiss(
                            context = this,
                            requestCode = (args["requestCode"] as Number).toInt(),
                            triggerAtMillis = (args["triggerAtMillis"] as Number).toLong(),
                            notifyId = (args["notifyId"] as Number).toInt(),
                        )
                        result.success(null)
                    }
                    "cancel" -> {
                        @Suppress("UNCHECKED_CAST")
                        val args = call.arguments as Map<String, Any>
                        @Suppress("UNCHECKED_CAST")
                        val requestCodes = args["requestCodes"] as List<Any>
                        for (code in requestCodes) {
                            LiveNotificationReceiver.cancel(this, (code as Number).toInt())
                        }
                        val notifyId = (args["notifyId"] as Number).toInt()
                        NotificationManagerCompat.from(this).cancel(notifyId)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, soundPickerChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pickSystemRingtone" -> {
                        if (pendingRingtoneResult != null) {
                            result.error("busy", "A sound picker is already open", null)
                            return@setMethodCallHandler
                        }
                        pendingRingtoneResult = result
                        @Suppress("UNCHECKED_CAST")
                        val args = call.arguments as Map<String, Any?>
                        val currentUri = args["currentUri"] as String?
                        val intent = Intent(RingtoneManager.ACTION_RINGTONE_PICKER).apply {
                            putExtra(
                                RingtoneManager.EXTRA_RINGTONE_TYPE,
                                RingtoneManager.TYPE_NOTIFICATION,
                            )
                            putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_SILENT, false)
                            putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_DEFAULT, true)
                            if (currentUri != null) {
                                putExtra(
                                    RingtoneManager.EXTRA_RINGTONE_EXISTING_URI,
                                    Uri.parse(currentUri),
                                )
                            }
                        }
                        startActivityForResult(intent, ringtonePickerRequestCode)
                    }
                    "importSoundFile" -> {
                        @Suppress("UNCHECKED_CAST")
                        val args = call.arguments as Map<String, Any>
                        if (!SoundImporter.isSupported()) {
                            result.error(
                                "unsupported",
                                "Importing a custom sound file needs Android 10 or newer",
                                null,
                            )
                            return@setMethodCallHandler
                        }
                        // Copies file bytes — kept off the platform thread that
                        // owns this channel, then hops back to post the result.
                        val filePath = args["filePath"] as String
                        val displayName = args["displayName"] as String
                        Thread {
                            try {
                                val uri = SoundImporter.importFile(this, filePath, displayName)
                                runOnUiThread { result.success(uri.toString()) }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("import_failed", e.message, null) }
                            }
                        }.start()
                    }
                    "deleteImportedSound" -> {
                        @Suppress("UNCHECKED_CAST")
                        val args = call.arguments as Map<String, Any>
                        SoundImporter.deleteIfOwned(this, Uri.parse(args["uri"] as String))
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
