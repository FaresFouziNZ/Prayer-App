import { getMessaging } from "firebase-admin/messaging";

import { Prayer, PrayerEventTimes, PushEvent } from "./types.js";

/** From `flutterfire configure`'s iOS app id (`1:574155009756:ios:...`) —
 * Live Activity pushes need the bundle id directly, APNs doesn't derive it
 * from the FCM app registration the way a normal push does. */
const IOS_BUNDLE_ID = "com.fares.prayerapp.prayerApp";
const APNS_TOPIC = `${IOS_BUNDLE_ID}.push-type.liveactivity`;

/** §3.3: `start`/`window`/`closing`/`end` are our own task-naming vocabulary;
 * APNs only understands three `aps.event` values, with `window` and `closing`
 * both collapsing to `update` (they differ only in the content-state's `phase`). */
export function apnsEventFor(event: PushEvent): "start" | "update" | "end" {
  switch (event) {
    case "start":
      return "start";
    case "window":
    case "closing":
      return "update";
    case "end":
      return "end";
  }
}

/** The content-state's `phase` (§2.7 content model) for a given push event. */
export function phaseFor(event: PushEvent): "iqamah" | "window" | "closing" {
  switch (event) {
    case "start":
      return "iqamah";
    case "window":
      return "window";
    case "closing":
    case "end":
      return "closing";
  }
}

/** Matches §2.7's JSON content model exactly (field-for-field, including unit:
 * the doc's example uses epoch seconds, not ISO strings, since this crosses
 * into the Swift/ActivityKit side). */
export interface LiveActivityContentState {
  phase: "iqamah" | "window" | "closing";
  adhanAt: number;
  liveStartAt: number;
  iqamahAt: number;
  closingAt: number;
  endAt: number;
  logged: boolean;
}

function epochSeconds(iso: string): number {
  return Math.floor(Date.parse(iso) / 1000);
}

export function buildContentState(
  times: PrayerEventTimes,
  event: PushEvent,
  logged: boolean,
): LiveActivityContentState {
  return {
    phase: phaseFor(event),
    adhanAt: epochSeconds(times.adhanAt),
    liveStartAt: epochSeconds(times.liveStartAt),
    iqamahAt: epochSeconds(times.iqamahAt),
    closingAt: epochSeconds(times.closingAt),
    endAt: epochSeconds(times.endAt),
    logged,
  };
}

export interface SendLiveActivityPushParams {
  /** The device's ordinary FCM registration token — required by FCM's
   * `Message` union for routing even though the actual APNs delivery is
   * keyed off `activityToken`; a device can host activities the FCM token
   * alone can't disambiguate. */
  fcmToken: string;
  /** Push-to-start token (event `start`) or the live activity's own token
   * (`window`/`closing`/`end`) — §3.2's `sendLiveActivity` row. */
  activityToken: string;
  prayer: Prayer;
  date: string;
  event: PushEvent;
  times: PrayerEventTimes;
  logged: boolean;
  alert?: { title: string; body: string };
}

/** §3.2 `sendLiveActivity` / §3.3 push timeline — builds and sends one APNs
 * Live Activity push via FCM v1. */
export async function sendLiveActivityPush(params: SendLiveActivityPushParams): Promise<void> {
  const apnsEvent = apnsEventFor(params.event);
  const contentState = buildContentState(params.times, params.event, params.logged);
  const nowSeconds = Math.floor(Date.now() / 1000);

  const aps: Record<string, unknown> = {
    timestamp: nowSeconds,
    event: apnsEvent,
    "content-state": contentState,
    "stale-date": epochSeconds(params.times.endAt),
  };

  if (apnsEvent === "start") {
    aps["attributes-type"] = "PrayerActivityAttributes";
    aps["attributes"] = { prayer: params.prayer, date: params.date };
  }
  if (apnsEvent === "end") {
    aps["dismissal-date"] = nowSeconds;
  }
  if (params.alert) {
    aps["alert"] = params.alert;
  }

  await getMessaging().send({
    token: params.fcmToken,
    apns: {
      liveActivityToken: params.activityToken,
      headers: {
        "apns-topic": APNS_TOPIC,
        "apns-push-type": "liveactivity",
        "apns-priority": "10",
      },
      payload: { aps },
    },
  });
}
