import 'dart:io' show Platform;

import 'package:flutter/services.dart';

/// Bridges to native code for picking a custom per-prayer notification sound
/// (SRS FR-NT-02's "custom" option), Android-only: iOS caps notification
/// sounds at 30s (SRS C1) and this app has no macOS/Xcode build available to
/// implement or test an iOS counterpart.
///
/// Two sources, matching the user's choice: the system ringtone/notification
/// picker (any sound already installed on the device), or an arbitrary file
/// imported into the system's Notifications collection so the OS's
/// notification-manager process — a different process than this app — can
/// actually read it back when the notification fires. Both return a
/// `content://` URI suitable for `UriAndroidNotificationSound`.
class SoundPicker {
  const SoundPicker._();

  static const _channel = MethodChannel('sound_picker');

  /// Launches Android's system ringtone/notification picker. Returns the
  /// picked sound's URI, or `null` if the user cancelled.
  static Future<String?> pickSystemRingtone({String? currentUri}) async {
    if (!Platform.isAndroid) return null;
    return _channel.invokeMethod<String>('pickSystemRingtone', {
      'currentUri': currentUri,
    });
  }

  /// Copies the file at [filePath] into the system's Notifications
  /// collection (via `MediaStore`, Android 10+) so it gets a `content://`
  /// URI the notification-manager process can read, and returns that URI.
  static Future<String?> importSoundFile({
    required String filePath,
    required String displayName,
  }) async {
    if (!Platform.isAndroid) return null;
    return _channel.invokeMethod<String>('importSoundFile', {
      'filePath': filePath,
      'displayName': displayName,
    });
  }

  /// Deletes a previously-[importSoundFile]-created entry. A no-op if [uri]
  /// wasn't created by this app (e.g. a system ringtone-picker URI) — used
  /// to avoid leaving orphaned copies behind each time a user swaps files.
  static Future<void> deleteImportedSound(String uri) async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('deleteImportedSound', {'uri': uri});
  }
}
