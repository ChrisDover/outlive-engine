/**
 * Withings API client for body composition and activity data.
 * All data stays local - only fetches from Withings to your local database.
 */

import { prisma } from "./prisma";

const WITHINGS_API_URL = "https://wbsapi.withings.net";

interface WithingsTokens {
  accessToken: string;
  refreshToken: string;
  userId: string;
}

interface WithingsMeasure {
  value: number;
  type: number;
  unit: number;
}

interface WithingsMeasureGroup {
  grpid: number;
  date: number;
  measures: WithingsMeasure[];
}

// Withings measure type codes
const MEASURE_TYPES = {
  WEIGHT: 1,           // kg
  HEIGHT: 4,           // m
  FAT_FREE_MASS: 5,    // kg
  FAT_RATIO: 6,        // %
  FAT_MASS_WEIGHT: 8,  // kg
  MUSCLE_MASS: 76,     // kg
  BONE_MASS: 88,       // kg
  HYDRATION: 77,       // kg (water mass)
} as const;

function parseWithingsValue(value: number, unit: number): number {
  // Withings stores values as integers with a unit exponent
  // e.g., 7523 with unit -2 = 75.23
  return value * Math.pow(10, unit);
}

async function refreshTokenIfNeeded(
  userId: string,
  tokens: WithingsTokens
): Promise<WithingsTokens> {
  // For now, assume tokens are valid. In production, check expiry and refresh.
  return tokens;
}

export async function fetchWithingsBodyComposition(
  webUserId: string,
  startDate?: Date,
  endDate?: Date
): Promise<{
  date: string;
  weight?: number;
  bodyFatPct?: number;
  muscleMass?: number;
  boneMass?: number;
  waterMass?: number;
  fatMass?: number;
}[]> {
  const user = await prisma.user.findUnique({
    where: { id: webUserId },
    select: {
      withingsAccessToken: true,
      withingsRefreshToken: true,
      withingsUserId: true,
    },
  });

  if (!user?.withingsAccessToken || !user?.withingsUserId) {
    throw new Error("Withings not connected");
  }

  const tokens = await refreshTokenIfNeeded(webUserId, {
    accessToken: user.withingsAccessToken,
    refreshToken: user.withingsRefreshToken || "",
    userId: user.withingsUserId,
  });

  // Default to last 30 days if no dates provided
  const end = endDate || new Date();
  const start = startDate || new Date(end.getTime() - 30 * 24 * 60 * 60 * 1000);

  const params = new URLSearchParams({
    action: "getmeas",
    meastype: [
      MEASURE_TYPES.WEIGHT,
      MEASURE_TYPES.FAT_RATIO,
      MEASURE_TYPES.FAT_MASS_WEIGHT,
      MEASURE_TYPES.MUSCLE_MASS,
      MEASURE_TYPES.BONE_MASS,
      MEASURE_TYPES.HYDRATION,
    ].join(","),
    category: "1", // Real measurements (not goals)
    startdate: Math.floor(start.getTime() / 1000).toString(),
    enddate: Math.floor(end.getTime() / 1000).toString(),
  });

  const response = await fetch(`${WITHINGS_API_URL}/measure?${params}`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${tokens.accessToken}`,
    },
  });

  if (!response.ok) {
    if (response.status === 401) {
      // TODO: Refresh token and retry
      throw new Error("Withings token expired");
    }
    throw new Error(`Withings API error: ${response.status}`);
  }

  const result = await response.json();

  if (result.status !== 0 || !result.body?.measuregrps) {
    throw new Error(`Withings API error: ${result.error || "Unknown error"}`);
  }

  // Group measurements by date
  const measurementsByDate = new Map<string, Record<string, number>>();

  for (const grp of result.body.measuregrps as WithingsMeasureGroup[]) {
    const date = new Date(grp.date * 1000).toISOString().split("T")[0];

    if (!measurementsByDate.has(date)) {
      measurementsByDate.set(date, {});
    }

    const dayData = measurementsByDate.get(date)!;

    for (const measure of grp.measures) {
      const value = parseWithingsValue(measure.value, measure.unit);

      switch (measure.type) {
        case MEASURE_TYPES.WEIGHT:
          dayData.weight = value;
          break;
        case MEASURE_TYPES.FAT_RATIO:
          dayData.bodyFatPct = value;
          break;
        case MEASURE_TYPES.FAT_MASS_WEIGHT:
          dayData.fatMass = value;
          break;
        case MEASURE_TYPES.MUSCLE_MASS:
          dayData.muscleMass = value;
          break;
        case MEASURE_TYPES.BONE_MASS:
          dayData.boneMass = value;
          break;
        case MEASURE_TYPES.HYDRATION:
          dayData.waterMass = value;
          break;
      }
    }
  }

  // Convert to array sorted by date
  return Array.from(measurementsByDate.entries())
    .map(([date, data]) => ({ date, ...data }))
    .sort((a, b) => b.date.localeCompare(a.date));
}

export async function fetchWithingsActivity(
  webUserId: string,
  startDate?: Date,
  endDate?: Date
): Promise<{
  date: string;
  steps?: number;
  calories?: number;
  distance?: number;
  activeMinutes?: number;
}[]> {
  const user = await prisma.user.findUnique({
    where: { id: webUserId },
    select: {
      withingsAccessToken: true,
      withingsRefreshToken: true,
      withingsUserId: true,
    },
  });

  if (!user?.withingsAccessToken || !user?.withingsUserId) {
    throw new Error("Withings not connected");
  }

  const tokens = await refreshTokenIfNeeded(webUserId, {
    accessToken: user.withingsAccessToken,
    refreshToken: user.withingsRefreshToken || "",
    userId: user.withingsUserId,
  });

  // Default to last 30 days if no dates provided
  const end = endDate || new Date();
  const start = startDate || new Date(end.getTime() - 30 * 24 * 60 * 60 * 1000);

  const params = new URLSearchParams({
    action: "getactivity",
    startdateymd: start.toISOString().split("T")[0],
    enddateymd: end.toISOString().split("T")[0],
  });

  const response = await fetch(`${WITHINGS_API_URL}/v2/measure?${params}`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${tokens.accessToken}`,
    },
  });

  if (!response.ok) {
    throw new Error(`Withings API error: ${response.status}`);
  }

  const result = await response.json();

  if (result.status !== 0 || !result.body?.activities) {
    return [];
  }

  return result.body.activities.map((activity: {
    date: string;
    steps?: number;
    calories?: number;
    distance?: number;
    soft?: number;
    moderate?: number;
    intense?: number;
  }) => ({
    date: activity.date,
    steps: activity.steps,
    calories: activity.calories,
    distance: activity.distance,
    activeMinutes: (activity.soft || 0) + (activity.moderate || 0) + (activity.intense || 0),
  }));
}

/**
 * Normalize Withings data to the common wearable metrics format
 * for sending to the backend.
 */
export function normalizeWithingsMetrics(
  bodyComp: Awaited<ReturnType<typeof fetchWithingsBodyComposition>>[0],
  activity?: Awaited<ReturnType<typeof fetchWithingsActivity>>[0]
): {
  source: "withings";
  date: string;
  metrics: Record<string, number | null>;
} {
  return {
    source: "withings",
    date: bodyComp.date,
    metrics: {
      weight_kg: bodyComp.weight ?? null,
      body_fat_pct: bodyComp.bodyFatPct ?? null,
      muscle_mass_kg: bodyComp.muscleMass ?? null,
      bone_mass_kg: bodyComp.boneMass ?? null,
      water_mass_kg: bodyComp.waterMass ?? null,
      fat_mass_kg: bodyComp.fatMass ?? null,
      steps: activity?.steps ?? null,
      calories_burned: activity?.calories ?? null,
      active_minutes: activity?.activeMinutes ?? null,
    },
  };
}
