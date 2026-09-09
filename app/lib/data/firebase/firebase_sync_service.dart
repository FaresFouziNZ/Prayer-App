import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../app/providers.dart';
import '../../config/prayer_config.dart';
import '../../config/settings_keys.dart';
import '../../domain/prayer_engine/prayer.dart';
import '../../domain/schedule/iqamah_profile.dart';
import '../../domain/schedule/prayer_event.dart';
import '../db/codecs.dart';
import '../db/repositories/iqamah_profile_repository.dart';

/// Publishes this device's settings, push tokens, and prayer schedule to
/// Firestore (SRS FR-SY-01/02/03; docs/02-Architecture.md §3.1) so the
/// Firebase backend can drive the iOS Live Activity push timeline.
///
/// Best-effort throughout, matching §1 principle 1 ("the phone is the
/// source of truth"): offline, no signed-in user, or any Firestore error is
/// swallowed rather than surfaced — nothing local depends on this
/// succeeding, and callers never need to handle a failure here differently
/// from a successful sync.
class FirebaseSyncService {
  const FirebaseSyncService._();

  /// FR-SY-03: "published by the app, 30 days ahead".
  static const int scheduleWindowDays = 30;

  static Future<void> sync(ProviderContainer container) async {
    try {
      await _sync(container);
    } catch (_) {
      // Deliberately swallowed — see class doc.
    }
  }

  static Future<void> _sync(ProviderContainer container) async {
    var user = FirebaseAuth.instance.currentUser;
    user ??= (await FirebaseAuth.instance.signInAnonymously()).user; // FR-SY-01
    if (user == null) return;

    final deviceRef = FirebaseFirestore.instance
        .collection('devices')
        .doc(user.uid);

    await _publishDevice(container, deviceRef);

    final today = container.read(todayProvider);
    for (var i = 0; i < scheduleWindowDays; i++) {
      final date = today.add(Duration(days: i));
      final snapshot = await container.read(daySnapshotProvider(date).future);
      await _publishScheduleDay(deviceRef, date, snapshot.events);
    }
  }

  /// FR-SY-02: platform/tz/location/calc/iqamah/ramadanMode/closingOffsetMin
  /// and the FCM registration token, merged so fields the app doesn't own
  /// (`tokens.pushToStart`/`tokens.activity`, written by the future iOS
  /// ActivityKit bridge) are left untouched.
  static Future<void> _publishDevice(
    ProviderContainer container,
    DocumentReference<Map<String, dynamic>> deviceRef,
  ) async {
    final settings = container.read(settingsRepositoryProvider);
    final coordinates = await container.read(coordinatesProvider.future);
    final locationLabel = await settings.getString(SettingsKeys.locationLabel);
    final ramadanMode = await settings.getBool(SettingsKeys.ramadanMode) ?? false;
    final closingOffsetMinutes =
        await settings.getInt(SettingsKeys.closingOffsetMinutes) ??
        PrayerConfig.defaultClosingOffsetMinutes;

    final profileSettingKey = ramadanMode
        ? SettingsKeys.ramadanIqamahProfileId
        : SettingsKeys.normalIqamahProfileId;
    final defaultProfileId = ramadanMode
        ? IqamahProfileRepository.ramadanProfileId
        : IqamahProfileRepository.normalProfileId;
    final activeProfileId =
        await settings.getString(profileSettingKey) ?? defaultProfileId;
    final activeProfile =
        await container
            .read(iqamahProfileRepositoryProvider)
            .getById(activeProfileId) ??
        IqamahProfile(
          id: IqamahProfileRepository.normalProfileId,
          name: 'Normal',
          offsetMinutes: PrayerConfig.normalIqamahOffsets,
          isBuiltin: true,
        );

    String? fcmToken;
    try {
      await FirebaseMessaging.instance.requestPermission();
      fcmToken = await FirebaseMessaging.instance.getToken();
    } catch (_) {
      // Notifications permission denied, or no Google Play services — the
      // device doc simply goes without a token until a later sync succeeds.
    }

    final localTimezone = await FlutterTimezone.getLocalTimezone();
    final packageInfo = await PackageInfo.fromPlatform();

    await deviceRef.set({
      'platform': Platform.isIOS ? 'ios' : 'android',
      'appVersion': packageInfo.version,
      'tz': localTimezone.identifier,
      'location': {
        'lat': coordinates.latitude,
        'lng': coordinates.longitude,
        if (locationLabel != null) 'label': locationLabel,
      },
      // Fixed today (SRS A1) — no per-user calculation-method setting yet.
      'calc': {'method': 'umm_al_qura', 'madhab': 'shafi'},
      'iqamah': {
        'profileId': activeProfile.id,
        'offsets': {
          for (final prayer in Prayer.values)
            prayer.name: activeProfile.offsetMinutes[prayer] ?? 0,
        },
        'mosqueOverride': activeProfile.mosqueOverride == null
            ? null
            : {
                for (final entry in activeProfile.mosqueOverride!.entries)
                  entry.key.name: entry.value,
              },
      },
      'ramadanMode': ramadanMode,
      'closingOffsetMin': closingOffsetMinutes,
      if (fcmToken != null) 'tokens': {'fcm': fcmToken},
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// FR-SY-03: one `devices/{id}/schedule/{YYYY-MM-DD}` doc per day, field
  /// layout matching `functions/src/types.ts`'s `ScheduleDayDoc` exactly.
  /// `liveStartAt` isn't a stored [PrayerEvent] field (see
  /// `live_notification_scheduler.dart`) so it's derived the same way here.
  static Future<void> _publishScheduleDay(
    DocumentReference<Map<String, dynamic>> deviceRef,
    DateTime date,
    List<PrayerEvent> events,
  ) async {
    final data = <String, dynamic>{
      'source': 'app',
      'publishedAt': FieldValue.serverTimestamp(),
    };
    for (final event in events) {
      final liveStartAt = event.adhanAt.add(
        const Duration(minutes: PrayerConfig.liveStartGraceMinutes),
      );
      data[event.prayer.name] = {
        'adhanAt': event.adhanAt.toUtc().toIso8601String(),
        'liveStartAt': liveStartAt.toUtc().toIso8601String(),
        'iqamahAt': event.iqamahAt.toUtc().toIso8601String(),
        'closingAt': event.closingAt.toUtc().toIso8601String(),
        'endAt': event.endAt.toUtc().toIso8601String(),
      };
    }
    await deviceRef.collection('schedule').doc(Codecs.dateKey(date)).set(data);
  }
}
