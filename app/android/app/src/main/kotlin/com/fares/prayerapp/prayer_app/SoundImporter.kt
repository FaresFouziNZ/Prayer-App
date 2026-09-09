package com.fares.prayerapp.prayer_app

import android.content.ContentValues
import android.content.Context
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import java.io.File

/**
 * Copies a user-picked file into the system's Notifications collection (SRS
 * FR-NT-02's custom sound, the raw-file half of it — see `SoundPicker` on
 * the Dart side and [MainActivity]'s `sound_picker` channel for the other
 * half, the system ringtone picker). The notification-manager service reads
 * a notification's sound from a *different* process than this app, so a
 * `content://` URI from the file picker's own Storage Access Framework
 * grant — scoped to this app only — won't play; inserting into `MediaStore`
 * is how apps hand the system a sound it can actually read, the same
 * mechanism Android's own "set custom ringtone" flows use.
 *
 * Requires Android 10+ (scoped storage's `RELATIVE_PATH`/`IS_NOTIFICATION`
 * columns): see [isSupported].
 */
object SoundImporter {
    fun isSupported(): Boolean = Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q

    fun importFile(context: Context, sourcePath: String, displayName: String): Uri {
        check(isSupported()) { "Custom sound import requires Android 10 or newer" }

        val resolver = context.contentResolver
        val values = ContentValues().apply {
            put(MediaStore.Audio.Media.DISPLAY_NAME, displayName)
            put(MediaStore.Audio.Media.MIME_TYPE, "audio/mpeg")
            put(MediaStore.Audio.Media.IS_NOTIFICATION, 1)
            put(
                MediaStore.Audio.Media.RELATIVE_PATH,
                Environment.DIRECTORY_NOTIFICATIONS + "/PrayerApp",
            )
        }

        val collection = MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        val insertedUri = resolver.insert(collection, values)
            ?: throw IllegalStateException("MediaStore rejected the insert")

        resolver.openOutputStream(insertedUri)?.use { out ->
            File(sourcePath).inputStream().use { input -> input.copyTo(out) }
        } ?: run {
            resolver.delete(insertedUri, null, null)
            throw IllegalStateException("Could not open the imported sound for writing")
        }

        return insertedUri
    }

    private val ownedRelativePath = "${Environment.DIRECTORY_NOTIFICATIONS}/PrayerApp"

    /** Deletes [uri] only if it's a row this class itself inserted (living
     * under [ownedRelativePath]) — a system ringtone-picker URI can point at
     * a built-in sound or another app's import, which this app must never
     * delete, so this checks the row's actual location rather than trusting
     * the authority alone (both live under the same `content://media/...`
     * authority). */
    fun deleteIfOwned(context: Context, uri: Uri) {
        if (uri.authority != MediaStore.AUTHORITY) return
        try {
            context.contentResolver
                .query(uri, arrayOf(MediaStore.Audio.Media.RELATIVE_PATH), null, null, null)
                ?.use { cursor ->
                    if (cursor.moveToFirst() &&
                        cursor.getString(0)?.startsWith(ownedRelativePath) == true
                    ) {
                        context.contentResolver.delete(uri, null, null)
                    }
                }
        } catch (e: Exception) {
            // Not a row we can introspect this way (e.g. a legacy/internal
            // volume URI from the ringtone picker) — leave it alone.
        }
    }
}
