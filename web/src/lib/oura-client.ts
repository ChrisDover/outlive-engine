import { prisma } from "./prisma";

const OURA_API = "https://api.ouraring.com/v2/usercollection";

interface OuraTokens {
  accessToken: string;
  refreshToken: string;
}

interface WearableMetrics {
  source: string;
  date: string;
  metrics: Record<string, any>;
}

async function refreshOuraToken(userId: string, refreshToken: string): Promise<OuraTokens | null> {
  const resp = await fetch("https://api.ouraring.com/oauth/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "refresh_token",
      refresh_token: refreshToken,
      client_id: process.env.OURA_CLIENT_ID!,
      client_secret: process.env.OURA_CLIENT_SECRET!,
    }),
  });

  if (!resp.ok) return null;

  const tokens = await resp.json();
  await prisma.user.update({
    where: { id: userId },
    data: {
      ouraAccessToken: tokens.access_token,
      ouraRefreshToken: tokens.refresh_token,
    },
  });

  return { accessToken: tokens.access_token, refreshToken: tokens.refresh_token };
}

async function ouraFetch(
  userId: string,
  accessToken: string,
  refreshToken: string,
  path: string,
  params: Record<string, string>,
): Promise<any> {
  const url = new URL(`${OURA_API}/${path}`);
  Object.entries(params).forEach(([k, v]) => url.searchParams.set(k, v));

  let resp = await fetch(url.toString(), {
    headers: { Authorization: `Bearer ${accessToken}` },
  });

  // Token expired — refresh and retry once
  if (resp.status === 401) {
    const newTokens = await refreshOuraToken(userId, refreshToken);
    if (!newTokens) throw new Error("Oura token refresh failed");

    resp = await fetch(url.toString(), {
      headers: { Authorization: `Bearer ${newTokens.accessToken}` },
    });
  }

  if (!resp.ok) throw new Error(`Oura API ${resp.status}`);
  return resp.json();
}

export async function fetchOuraData(
  userId: string,
  accessToken: string,
  refreshToken: string,
  date: string,
): Promise<WearableMetrics> {
  const params = { start_date: date, end_date: date };

  const [sleepData, readinessData, heartRateData] = await Promise.allSettled([
    ouraFetch(userId, accessToken, refreshToken, "daily_sleep", params),
    ouraFetch(userId, accessToken, refreshToken, "daily_readiness", params),
    ouraFetch(userId, accessToken, refreshToken, "heartrate", params),
  ]);

  const sleep = sleepData.status === "fulfilled" ? sleepData.value?.data?.[0] : null;
  const readiness = readinessData.status === "fulfilled" ? readinessData.value?.data?.[0] : null;
  const hr = heartRateData.status === "fulfilled" ? heartRateData.value?.data : null;

  // Normalize to common metrics schema
  const metrics: Record<string, any> = {};

  if (sleep) {
    metrics.sleep_score = sleep.score;
    metrics.total_sleep_duration = sleep.contributors?.total_sleep;
    metrics.rem_sleep_duration = sleep.contributors?.rem_sleep;
    metrics.deep_sleep_duration = sleep.contributors?.deep_sleep;
  }

  if (readiness) {
    metrics.readiness_score = readiness.score;
    metrics.hrv = readiness.contributors?.hrv_balance;
    metrics.resting_heart_rate = readiness.contributors?.resting_heart_rate;
    metrics.recovery_index = readiness.contributors?.recovery_index;
  }

  if (hr && Array.isArray(hr) && hr.length > 0) {
    const bpms = hr.map((h: any) => h.bpm).filter(Boolean);
    if (bpms.length > 0) {
      metrics.avg_heart_rate = Math.round(bpms.reduce((a: number, b: number) => a + b, 0) / bpms.length);
    }
  }

  return { source: "oura", date, metrics };
}
