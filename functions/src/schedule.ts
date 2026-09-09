import {
  CalculationMethod,
  CalculationParameters,
  Coordinates,
  Madhab,
  PrayerTimes,
} from "adhan";

import {
  DeviceCalc,
  DeviceIqamah,
  DeviceLocation,
  Prayer,
  PrayerEventTimes,
  PRAYERS,
} from "./types.js";

/** Mirrors `PrayerConfig.liveStartGraceMinutes` (Dart) — fixed, not exposed
 * as a per-device setting, so it's duplicated here rather than read from
 * any device doc field. */
const LIVE_START_GRACE_MINUTES = 5;

/** Mirrors `PrayerConfig.ramadanIshaAdjustmentMinutes` (Dart, SRS C7). */
const RAMADAN_ISHA_ADJUSTMENT_MINUTES = 30;

/** Maps the device doc's `calc.method` string (written by the Dart client)
 * to the npm `adhan` package's calculation method — only "umm_al_qura" is
 * actually produced by the app today (`PrayerConfig.defaultCalculationParameters`),
 * but the map is left open for the others `adhan`/`adhan_dart` both support. */
const CALCULATION_METHODS: Record<string, keyof typeof CalculationMethod> = {
  muslim_world_league: "MuslimWorldLeague",
  egyptian: "Egyptian",
  karachi: "Karachi",
  umm_al_qura: "UmmAlQura",
  dubai: "Dubai",
  moonsighting_committee: "MoonsightingCommittee",
  north_america: "NorthAmerica",
  kuwait: "Kuwait",
  qatar: "Qatar",
  singapore: "Singapore",
  tehran: "Tehran",
  turkey: "Turkey",
};

function calculationParametersFor(calc: DeviceCalc): CalculationParameters {
  const methodKey = CALCULATION_METHODS[calc.method] ?? "UmmAlQura";
  const params = CalculationMethod[methodKey]();
  params.madhab = calc.madhab === "hanafi" ? Madhab.Hanafi : Madhab.Shafi;
  if (calc.adjustments) {
    for (const prayer of PRAYERS) {
      const minutes = calc.adjustments[prayer];
      if (minutes) params.adjustments[prayer] += minutes;
    }
  }
  return params;
}

/** `YYYY-MM-DD` (the device's own local calendar date, per its `tz`) →
 * midnight UTC on that date. `adhan`'s `PrayerTimes` only needs a date to
 * anchor which day's solar geometry to compute — it returns absolute
 * instants (real UTC-backed `Date`s) regardless of what time zone the
 * input `Date` object claims, so any midnight anchor for the right
 * calendar day produces the correct result. */
function parseDateKey(dateKey: string): Date {
  const [year, month, day] = dateKey.split("-").map(Number);
  return new Date(Date.UTC(year, month - 1, day));
}

function addDays(date: Date, days: number): Date {
  return new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate() + days));
}

function addMinutes(date: Date, minutes: number): Date {
  return new Date(date.getTime() + minutes * 60_000);
}

/**
 * Mirrors `PrayerTimeCalculator.computeForDate` + `ScheduleBuilder.build`
 * (Dart) field-for-field — this is the server-side fallback FR-SY-04
 * requires when the app hasn't published a day's schedule. A parity test
 * in CI (docs/02-Architecture.md §4) is expected to catch any drift
 * between the two implementations; keep this function's shape matched to
 * theirs rather than "simplifying" it independently.
 */
export function computeSchedule(
  dateKey: string,
  location: DeviceLocation,
  calc: DeviceCalc,
  iqamah: DeviceIqamah,
  closingOffsetMin: number,
  ramadanMode: boolean,
): Record<Prayer, PrayerEventTimes> {
  const date = parseDateKey(dateKey);
  const coordinates = new Coordinates(location.lat, location.lng);
  const params = calculationParametersFor(calc);
  if (ramadanMode) {
    params.adjustments.isha += RAMADAN_ISHA_ADJUSTMENT_MINUTES;
  }

  const times = new PrayerTimes(coordinates, date, params);
  const nextFajr = new PrayerTimes(coordinates, addDays(date, 1), params).fajr;

  // SRS: Isha's window ends at Islamic midnight — the midpoint between
  // Maghrib and the *next* day's Fajr (2026-09-05 decision log).
  const islamicMidnight = new Date(
    times.maghrib.getTime() + (nextFajr.getTime() - times.maghrib.getTime()) / 2,
  );

  const adhanAt: Record<Prayer, Date> = {
    fajr: times.fajr,
    dhuhr: times.dhuhr,
    asr: times.asr,
    maghrib: times.maghrib,
    isha: times.isha,
  };

  // SRS FR-PT-04: Fajr → sunrise; Dhuhr → Asr; Asr → Maghrib; Maghrib →
  // Isha; Isha → Islamic midnight.
  const windowEnd: Record<Prayer, Date> = {
    fajr: times.sunrise,
    dhuhr: times.asr,
    asr: times.maghrib,
    maghrib: times.isha,
    isha: islamicMidnight,
  };

  const result = {} as Record<Prayer, PrayerEventTimes>;
  for (const prayer of PRAYERS) {
    const at = adhanAt[prayer];
    const endAt = windowEnd[prayer];
    // Mirrors `IqamahProfile.offsetFor` (Dart) — a mosque override (FR-IQ-03)
    // always wins over the profile's own offset for that prayer.
    const offsetMinutes = iqamah.mosqueOverride?.[prayer] ?? iqamah.offsets[prayer];
    const iqamahAt = addMinutes(at, offsetMinutes);
    const rawClosingAt = addMinutes(endAt, -closingOffsetMin);
    const closingAt = rawClosingAt.getTime() < iqamahAt.getTime() ? iqamahAt : rawClosingAt;

    result[prayer] = {
      adhanAt: at.toISOString(),
      liveStartAt: addMinutes(at, LIVE_START_GRACE_MINUTES).toISOString(),
      iqamahAt: iqamahAt.toISOString(),
      closingAt: closingAt.toISOString(),
      endAt: endAt.toISOString(),
    };
  }
  return result;
}

/** `YYYY-MM-DD` for "today" and "tomorrow" in a given IANA time zone. */
export function localDateKeys(tz: string, now: Date = new Date()): { today: string; tomorrow: string } {
  const formatter = new Intl.DateTimeFormat("en-CA", {
    timeZone: tz,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  });
  const today = formatter.format(now); // en-CA formats as YYYY-MM-DD
  const [y, m, d] = today.split("-").map(Number);
  const tomorrow = addDays(new Date(Date.UTC(y, m - 1, d)), 1).toISOString().slice(0, 10);
  return { today, tomorrow };
}

/** The device's current local hour and minute in its own `tz`, used by
 * `planDay` to find devices in their "just past local midnight" window. */
export function localHourMinute(tz: string, now: Date = new Date()): { hour: number; minute: number } {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: tz,
    hour: "2-digit",
    minute: "2-digit",
    hourCycle: "h23",
  }).formatToParts(now);
  const hour = Number(parts.find((p) => p.type === "hour")?.value ?? "0");
  const minute = Number(parts.find((p) => p.type === "minute")?.value ?? "0");
  return { hour, minute };
}
