import { prisma } from "./prisma";

const WHOOP_API = "https://api.prod.whoop.com/developer/v1";

interface WhoopTokens {
  accessToken: string;
  refreshToken: string;
}

interface WearableMetrics {
  source: string;
  date: string;
  metrics: Record<string, any>;
}

async function refreshWhoopToken(userId: string, refreshToken: string): Promise<WhoopTokens | null> {
  const resp = await fetch("https://api.prod.whoop.com/oauth/oauth2/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "refresh_token",
      refresh_token: refreshToken,
      client_id: process.env.WHOOP_CLIENT_ID!,
      client_secret: process.env.WHOOP_CLIENT_SECRET!,
    }),
  });

  if (!resp.ok) return null;

  const tokens = await resp.json();
  await prisma.user.update({
    where: { id: userId },
    data: {
      whoopAccessToken: tokens.access_token,
      whoopRefreshToken: tokens.refresh_token,
    },
  });

  return { accessToken: tokens.access_token, refreshToken: tokens.refresh_token };
}

async function whoopFetch(
  userId: string,
  accessToken: string,
  refreshToken: string,
  path: string,
): Promise<any> {
  let resp = await fetch(`${WHOOP_API}/${path}`, {
    headers: { Authorization: `Bearer ${accessToken}` },
  });

  if (resp.status === 401) {
    const newTokens = await refreshWhoopToken(userId, refreshToken);
    if (!newTokens) throw new Error("Whoop token refresh failed");

    resp = await fetch(`${WHOOP_API}/${path}`, {
      headers: { Authorization: `Bearer ${newTokens.accessToken}` },
    });
  }

  if (!resp.ok) throw new Error(`Whoop API ${resp.status}`);
  return resp.json();
}

export async function fetchWhoopData(
  userId: string,
  accessToken: string,
  refreshToken: string,
  date: string,
): Promise<WearableMetrics> {
  const [recoveryData, sleepData, cycleData] = await Promise.allSettled([
    whoopFetch(userId, accessToken, refreshToken, `recovery?start=${date}&end=${date}`),
    whoopFetch(userId, accessToken, refreshToken, `activity/sleep?start=${date}&end=${date}`),
    whoopFetch(userId, accessToken, refreshToken, `cycle?start=${date}&end=${date}`),
  ]);

  const recovery = recoveryData.status === "fulfilled" ? recoveryData.value?.records?.[0] : null;
  const sleep = sleepData.status === "fulfilled" ? sleepData.value?.records?.[0] : null;
  const cycle = cycleData.status === "fulfilled" ? cycleData.value?.records?.[0] : null;

  const metrics: Record<string, any> = {};

  if (recovery?.score) {
    metrics.recovery_score = recovery.score.recovery_score;
    metrics.hrv = recovery.score.hrv_rmssd_milli;
    metrics.resting_heart_rate = recovery.score.resting_heart_rate;
    metrics.spo2 = recovery.score.spo2_percentage;
  }

  if (sleep?.score) {
    metrics.sleep_score = sleep.score.stage_summary ? Math.round(
      (sleep.score.stage_summary.total_in_bed_time_milli > 0
        ? (sleep.score.stage_summary.total_sleep_time_milli / sleep.score.stage_summary.total_in_bed_time_milli) * 100
        : 0)
    ) : null;
    metrics.total_sleep_duration = sleep.score.stage_summary?.total_sleep_time_milli
      ? Math.round(sleep.score.stage_summary.total_sleep_time_milli / 60000)
      : null;
  }

  if (cycle?.score) {
    metrics.strain = cycle.score.strain;
    metrics.kilojoules = cycle.score.kilojoule;
    metrics.avg_heart_rate = cycle.score.average_heart_rate;
    metrics.max_heart_rate = cycle.score.max_heart_rate;
  }

  return { source: "whoop", date, metrics };
}
