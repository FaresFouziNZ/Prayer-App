/**
 * Firestore schema (SRS docs/02-Architecture.md §3.1). `deviceId` is always
 * the device's anonymous Firebase Auth uid (FR-SY-01) — client and Admin
 * SDK code alike key everything off that, never a separately-generated id.
 */

import type { Timestamp } from "firebase-admin/firestore";

export type Prayer = "fajr" | "dhuhr" | "asr" | "maghrib" | "isha";

export const PRAYERS: Prayer[] = ["fajr", "dhuhr", "asr", "maghrib", "isha"];

/** One prayer's four push-worthy moments (§3.3), all ISO 8601 UTC strings —
 * Firestore has no first-class "instant" type friendly to both client SDKs
 * without extra conversion, and these are written by the Dart client too. */
export interface PrayerEventTimes {
  adhanAt: string;
  liveStartAt: string;
  iqamahAt: string;
  closingAt: string;
  endAt: string;
}

/** `devices/{deviceId}/schedule/{YYYY-MM-DD}` */
export interface ScheduleDayDoc {
  fajr: PrayerEventTimes;
  dhuhr: PrayerEventTimes;
  asr: PrayerEventTimes;
  maghrib: PrayerEventTimes;
  isha: PrayerEventTimes;
  source: "app" | "server";
  publishedAt: Timestamp;
}

export interface DeviceLocation {
  lat: number;
  lng: number;
  label?: string;
}

export interface DeviceCalc {
  /** e.g. "umm_al_qura" — matches `adhan`/`adhan_dart`'s `CalculationMethod` names. */
  method: string;
  madhab: "shafi" | "hanafi";
  adjustments?: Partial<Record<Prayer, number>>;
}

export interface DeviceIqamah {
  profileId: string;
  offsets: Record<Prayer, number>;
  mosqueOverride?: Partial<Record<Prayer, number>> | null;
}

export interface DeviceActivityToken {
  token: string;
  prayer: Prayer;
  date: string;
  /** The last phase successfully pushed for this activity — `sendLiveActivity`'s
   * own idempotency check (§3.2) reads this before sending an `update`/`end`
   * so a duplicate or out-of-order task dispatch can't regress the activity
   * to an earlier phase. */
  phase?: PushEvent;
}

export interface DeviceTokens {
  fcm?: string;
  pushToStart?: string;
  activity?: DeviceActivityToken | null;
  invalidAt?: Timestamp;
}

/** `devices/{deviceId}` */
export interface DeviceDoc {
  platform: "ios" | "android";
  appVersion: string;
  tz: string;
  location: DeviceLocation;
  calc: DeviceCalc;
  iqamah: DeviceIqamah;
  ramadanMode: boolean;
  closingOffsetMin: number;
  tokens: DeviceTokens;
  /** The most recent prayer the app itself has logged — consulted by the
   * closing-phase push to decide whether to include an alert (§3.3: "only
   * if logged == false"). Absent/stale is treated as "not logged" (the doc
   * calls this "unknown" and says to send anyway). */
  lastLogged?: {
    date: string;
    prayer: Prayer;
    loggedAt: Timestamp;
  };
  updatedAt: Timestamp;
}

/** The four push-worthy moments per prayer (§3.3) — one Cloud Task each,
 * named `{deviceId}-{date}-{prayer}-{event}`. Distinct from the three
 * `aps.event` values APNs itself understands (`start`/`update`/`end`):
 * `window` and `closing` both send `update`, differing only in the
 * content-state's `phase` — see `fcm.ts`'s `pushEventToApns`. */
export type PushEvent = "start" | "window" | "closing" | "end";

export interface SendLiveActivityPayload {
  deviceId: string;
  date: string; // YYYY-MM-DD
  prayer: Prayer;
  event: PushEvent;
}

/** Fields that, if changed, invalidate today/tomorrow's already-enqueued
 * tasks and require recomputing from the (already re-published) schedule —
 * §3.2's `onDeviceWrite` row. */
export const SCHEDULE_AFFECTING_FIELDS = [
  "location",
  "calc",
  "iqamah",
  "ramadanMode",
  "closingOffsetMin",
] as const;
