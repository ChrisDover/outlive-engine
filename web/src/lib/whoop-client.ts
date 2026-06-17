import { prisma } from "./prisma";

// Whoop API v2 — v1 recovery/sleep endpoints were deprecated and now 404.
const WHOOP_API = "https://api.prod.whoop.com/developer/v2";
const WHOOP_TOKEN_URL = "https://api.prod.whoop.com/oauth/oauth2/token";

interface WhoopTokens {
  accessToken: string;
  refreshToken: string;
}

interface WearableMetrics {
  source: string;
  date: string;
  metrics: Record<string, number | string | null>;
}

async function refreshWhoopToken(
  userId: string,
  refreshToken: string,
): Promise<WhoopTokens | null> {
  const resp = await fetch(WHOOP_TOKEN_URL, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "refresh_token",
      refresh_token: refreshToken,
      client_id: process.env.WHOOP_CLIENT_ID!,
      client_secret: process.env.WHOOP_CLIENT_SECRET!,
      scope: "offline",
    }),
  });

  if (!resp.ok) return null;

  const tokens = await resp.json();
  await prisma.user.update({
    where: { id: userId },
    data: {
      whoopAccessToken: tokens.access_token,
      // Whoop rotates refresh tokens; keep the old one if none is returned.
      ...(tokens.refresh_token ? { whoopRefreshToken: tokens.refresh_token } : {}),
    },
  });

  return {
    accessToken: tokens.access_token,
    refreshToken: tokens.refresh_token ?? refreshToken,
  };
}

async function whoopFetch(
  userId: string,
  accessToken: string,
  refreshToken: string | null,
  path: string,
): Promise<unknown> {
  let resp = await fetch(`${WHOOP_API}/${path}`, {
    headers: { Authorization: `Bearer ${accessToken}` },
  });

  if (resp.status === 401) {
    if (!refreshToken) {
      throw new Error("Whoop session expired — reconnect Whoop in Settings");
    }
    const newTokens = await refreshWhoopToken(userId, refreshToken);
    if (!newTokens) {
      throw new Error("Whoop token refresh failed — reconnect Whoop in Settings");
    }
    resp = await fetch(`${WHOOP_API}/${path}`, {
      headers: { Authorization: `Bearer ${newTokens.accessToken}` },
    });
  }

  if (!resp.ok) throw new Error(`Whoop API ${resp.status}`);
  return resp.json();
}

interface WhoopRecord {
  score_state?: string;
  score?: Record<string, number>;
  created_at?: string;
  start?: string;
  end?: string;
}

function firstRecord(payload: unknown): WhoopRecord | null {
  const records = (payload as { records?: WhoopRecord[] } | null)?.records;
  return Array.isArray(records) && records.length > 0 ? records[0] : null;
}

function scoredOnly(rec: WhoopRecord | null): WhoopRecord | null {
  if (!rec) return null;
  if (rec.score_state && rec.score_state !== "SCORED") return null;
  return rec.score ? rec : null;
}

/**
 * Fetch the latest Whoop recovery, sleep and cycle and normalize into the
 * canonical metric keys the dashboard/trends/longevity code reads.
 * `refreshToken` may be null (older connections made before the `offline`
 * scope was requested) — in that case an expired token surfaces a clear
 * "reconnect" error rather than a silent failure.
 */
export async function fetchWhoopData(
  userId: string,
  accessToken: string,
  refreshToken: string | null,
  date: string,
): Promise<WearableMetrics> {
  const [recoveryRes, sleepRes, cycleRes] = await Promise.allSettled([
    whoopFetch(userId, accessToken, refreshToken, "recovery?limit=1"),
    whoopFetch(userId, accessToken, refreshToken, "activity/sleep?limit=1"),
    whoopFetch(userId, accessToken, refreshToken, "cycle?limit=1"),
  ]);

  // If every request failed, surface the first error instead of returning empty.
  if (
    recoveryRes.status === "rejected" &&
    sleepRes.status === "rejected" &&
    cycleRes.status === "rejected"
  ) {
    throw recoveryRes.reason instanceof Error
      ? recoveryRes.reason
      : new Error("Whoop API request failed");
  }

  const recovery = scoredOnly(recoveryRes.status === "fulfilled" ? firstRecord(recoveryRes.value) : null);
  const sleep = scoredOnly(sleepRes.status === "fulfilled" ? firstRecord(sleepRes.value) : null);
  const cycle = scoredOnly(cycleRes.status === "fulfilled" ? firstRecord(cycleRes.value) : null);

  const metrics: Record<string, number | string | null> = {};

  if (recovery?.score) {
    const s = recovery.score;
    if (s.recovery_score != null) metrics.recovery_score = Math.round(s.recovery_score);
    if (s.hrv_rmssd_milli != null) metrics.hrv = Math.round(s.hrv_rmssd_milli);
    if (s.resting_heart_rate != null) {
      metrics.rhr = Math.round(s.resting_heart_rate);
      metrics.resting_heart_rate = Math.round(s.resting_heart_rate);
    }
    if (s.spo2_percentage != null) metrics.spo2 = Math.round(s.spo2_percentage * 10) / 10;
    if (s.skin_temp_celsius != null) metrics.skin_temp_celsius = Math.round(s.skin_temp_celsius * 10) / 10;
  }

  if (sleep?.score) {
    const s = sleep.score as Record<string, number> & {
      stage_summary?: Record<string, number>;
      sleep_performance_percentage?: number;
      sleep_efficiency_percentage?: number;
    };
    const stages = s.stage_summary;
    if (s.sleep_performance_percentage != null) {
      metrics.sleep_score = Math.round(s.sleep_performance_percentage);
    }
    if (s.sleep_efficiency_percentage != null) {
      metrics.sleep_efficiency = Math.round(s.sleep_efficiency_percentage);
    }
    if (stages) {
      // v2 has no total_sleep_time_milli — sum the asleep stages.
      const asleepMilli =
        (stages.total_light_sleep_time_milli ?? 0) +
        (stages.total_slow_wave_sleep_time_milli ?? 0) +
        (stages.total_rem_sleep_time_milli ?? 0);
      if (asleepMilli > 0) {
        metrics.total_sleep_duration = Math.round(asleepMilli / 60000);
        metrics.sleep_hours = Math.round((asleepMilli / 3600000) * 10) / 10;
      }
    }
  }

  if (cycle?.score) {
    const s = cycle.score;
    metrics.strain = s.strain;
    metrics.kilojoules = s.kilojoule;
    metrics.avg_heart_rate = s.average_heart_rate;
    metrics.max_heart_rate = s.max_heart_rate;
  }

  // Date the entry from the source record when possible, else the requested day.
  const recordDate =
    (recovery?.created_at || sleep?.end || cycle?.start || date).slice(0, 10);

  return { source: "whoop", date: recordDate, metrics };
}
