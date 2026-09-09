import { initializeApp } from "firebase-admin/app";
import { getFirestore, Timestamp } from "firebase-admin/firestore";
import { getFunctions } from "firebase-admin/functions";
import { getMessaging } from "firebase-admin/messaging";
import * as logger from "firebase-functions/logger";
import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { onTaskDispatched } from "firebase-functions/v2/tasks";

import { sendLiveActivityPush } from "./fcm.js";
import { computeSchedule, localDateKeys, localHourMinute } from "./schedule.js";
import {
  DeviceDoc,
  PRAYERS,
  Prayer,
  PrayerEventTimes,
  PushEvent,
  ScheduleDayDoc,
  SCHEDULE_AFFECTING_FIELDS,
  SendLiveActivityPayload,
} from "./types.js";

initializeApp();
const db = getFirestore();

const PUSH_EVENTS: PushEvent[] = ["start", "window", "closing", "end"];

const PRAYER_LABELS: Record<Prayer, string> = {
  fajr: "Fajr",
  dhuhr: "Dhuhr",
  asr: "Asr",
  maghrib: "Maghrib",
  isha: "Isha",
};

function triggerTimeFor(times: PrayerEventTimes, event: PushEvent): Date {
  switch (event) {
    case "start":
      return new Date(times.liveStartAt);
    case "window":
      return new Date(times.iqamahAt);
    case "closing":
      return new Date(times.closingAt);
    case "end":
      return new Date(times.endAt);
  }
}

function taskId(deviceId: string, date: string, prayer: Prayer, event: PushEvent): string {
  return `${deviceId}-${date}-${prayer}-${event}`;
}

function scheduleTimesOf(doc: ScheduleDayDoc): Record<Prayer, PrayerEventTimes> {
  return { fajr: doc.fajr, dhuhr: doc.dhuhr, asr: doc.asr, maghrib: doc.maghrib, isha: doc.isha };
}

function minutesUntil(iso: string): number {
  return Math.max(0, Math.round((Date.parse(iso) - Date.now()) / 60_000));
}

async function computeAndPublish(
  deviceId: string,
  date: string,
  device: DeviceDoc,
): Promise<Record<Prayer, PrayerEventTimes>> {
  const computed = computeSchedule(date, device.location, device.calc, device.iqamah, device.closingOffsetMin, device.ramadanMode);
  const doc: ScheduleDayDoc = { ...computed, source: "server", publishedAt: Timestamp.now() };
  await db.doc(`devices/${deviceId}/schedule/${date}`).set(doc);
  return computed;
}

/** §3.3: enqueues the four push-worthy Cloud Tasks for every prayer on one
 * day. iOS only — Android's timeline runs entirely on local exact alarms. */
async function enqueueDayTasks(
  deviceId: string,
  date: string,
  schedule: Record<Prayer, PrayerEventTimes>,
): Promise<void> {
  const queue = getFunctions().taskQueue<SendLiveActivityPayload>("sendLiveActivity");
  const now = Date.now();
  for (const prayer of PRAYERS) {
    const times = schedule[prayer];
    for (const event of PUSH_EVENTS) {
      const scheduleTime = triggerTimeFor(times, event);
      if (scheduleTime.getTime() <= now) continue;
      try {
        await queue.enqueue(
          { deviceId, date, prayer, event },
          { id: taskId(deviceId, date, prayer, event), scheduleTime },
        );
      } catch (err) {
        const code = (err as { code?: string }).code;
        if (code !== "functions/task-already-exists") throw err;
      }
    }
  }
}

/** Deletes any still-pending tasks for one device+day — Cloud Tasks silently
 * no-ops deleting a task that already ran or never existed. */
async function deleteDayTasks(deviceId: string, date: string): Promise<void> {
  const queue = getFunctions().taskQueue<SendLiveActivityPayload>("sendLiveActivity");
  for (const prayer of PRAYERS) {
    for (const event of PUSH_EVENTS) {
      try {
        await queue.delete(taskId(deviceId, date, prayer, event));
      } catch (err) {
        logger.debug("deleteDayTasks: task already gone", { deviceId, date, prayer, event, err });
      }
    }
  }
}

/**
 * §3.2 `planDay`: hourly scan for devices in their local 00:15–01:14 window;
 * publishes tomorrow's schedule (server fallback, FR-SY-04) if the app
 * hasn't already, enqueues the day's push tasks (iOS), and nudges the app to
 * refresh its own iOS notification window with a silent data push.
 */
export const planDay = onSchedule("every 60 minutes", async () => {
  const devicesSnap = await db.collection("devices").get();
  const now = new Date();

  await Promise.all(
    devicesSnap.docs.map(async (deviceSnap) => {
      const device = deviceSnap.data() as DeviceDoc;
      if (!device.tz) return;

      const { hour, minute } = localHourMinute(device.tz, now);
      const minutesPastMidnight = hour * 60 + minute;
      if (minutesPastMidnight < 15 || minutesPastMidnight > 74) return; // 00:15–01:14

      const deviceId = deviceSnap.id;
      const { tomorrow } = localDateKeys(device.tz, now);

      const existing = await db.doc(`devices/${deviceId}/schedule/${tomorrow}`).get();
      const schedule = existing.exists
        ? scheduleTimesOf(existing.data() as ScheduleDayDoc)
        : await computeAndPublish(deviceId, tomorrow, device);

      if (device.platform !== "ios" || !device.tokens?.fcm) return;

      await enqueueDayTasks(deviceId, tomorrow, schedule);
      await getMessaging().send({
        token: device.tokens.fcm,
        data: { type: "reschedule" },
        apns: {
          headers: { "apns-priority": "5", "apns-push-type": "background" },
          payload: { aps: { "content-available": 1 } },
        },
      });
    }),
  );
});

/**
 * §3.2 `onDeviceWrite`: if a schedule-affecting field changed, drop today's
 * and tomorrow's pending tasks and re-derive+re-enqueue from freshly
 * computed times (the app is expected to republish its own `schedule/{day}`
 * docs right after a settings change too; this just keeps the backend from
 * pushing against stale timestamps in the meantime).
 */
export const onDeviceWrite = onDocumentUpdated("devices/{deviceId}", async (event) => {
  const before = event.data?.before.data() as DeviceDoc | undefined;
  const after = event.data?.after.data() as DeviceDoc | undefined;
  if (!before || !after) return;

  const changed = SCHEDULE_AFFECTING_FIELDS.some(
    (field) => JSON.stringify(before[field]) !== JSON.stringify(after[field]),
  );
  if (!changed) return;

  const deviceId = event.params.deviceId;
  const { today, tomorrow } = localDateKeys(after.tz ?? "UTC");

  for (const date of [today, tomorrow]) {
    await deleteDayTasks(deviceId, date);
    const schedule = await computeAndPublish(deviceId, date, after);
    if (after.platform === "ios" && after.tokens?.fcm) {
      await enqueueDayTasks(deviceId, date, schedule);
    }
  }
});

/**
 * §3.2 `sendLiveActivity`: Cloud Tasks-dispatched. Loads the device +
 * schedule, builds the content state, and sends one APNs Live Activity push.
 * Idempotent against out-of-order/duplicate dispatch via the device doc's
 * last-recorded `tokens.activity.phase`.
 */
export const sendLiveActivity = onTaskDispatched<SendLiveActivityPayload>(async (request) => {
  const { deviceId, date, prayer, event } = request.data;
  const deviceRef = db.doc(`devices/${deviceId}`);

  const [deviceSnap, scheduleSnap] = await Promise.all([
    deviceRef.get(),
    db.doc(`devices/${deviceId}/schedule/${date}`).get(),
  ]);
  if (!deviceSnap.exists || !scheduleSnap.exists) {
    logger.warn("sendLiveActivity: missing device or schedule doc", { deviceId, date, prayer, event });
    return;
  }

  const device = deviceSnap.data() as DeviceDoc;
  const schedule = scheduleSnap.data() as ScheduleDayDoc;
  const times = scheduleTimesOf(schedule)[prayer];

  const fcmToken = device.tokens?.fcm;
  const activityToken = event === "start" ? device.tokens?.pushToStart : device.tokens?.activity?.token;
  if (!fcmToken || !activityToken) return;

  const recordedPhase = device.tokens?.activity?.phase;
  if (recordedPhase && PUSH_EVENTS.indexOf(recordedPhase) >= PUSH_EVENTS.indexOf(event)) {
    return; // stale or duplicate dispatch — already at or past this phase
  }

  const logged = device.lastLogged?.date === date && device.lastLogged?.prayer === prayer;

  let alert: { title: string; body: string } | undefined;
  if (event === "start") {
    alert = { title: PRAYER_LABELS[prayer], body: `Iqamah in ${minutesUntil(times.iqamahAt)} min` };
  } else if (event === "closing" && !logged) {
    // §3.3: closing alert only if unlogged — "if unknown, sends anyway".
    alert = { title: PRAYER_LABELS[prayer], body: `${PRAYER_LABELS[prayer]} window ends in ${minutesUntil(times.endAt)} min` };
  }

  await sendLiveActivityPush({ fcmToken, activityToken, prayer, date, event, times, logged, alert });

  if (event !== "start") {
    // `start`'s activity token isn't known yet — the app writes the real one
    // once ActivityKit hands it a `pushTokenUpdates` token after launch.
    await deviceRef.set(
      {
        tokens: {
          activity: event === "end" ? null : { ...device.tokens!.activity!, phase: event },
        },
      },
      { merge: true },
    );
  }
});
