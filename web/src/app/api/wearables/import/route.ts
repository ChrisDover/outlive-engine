import { NextRequest, NextResponse } from "next/server";
import { getServerSession } from "next-auth";
import { authOptions } from "@/lib/auth";
import { prisma } from "@/lib/prisma";
import { backendClient } from "@/lib/backend-client";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const WEARABLE_KEYS = ["hrv", "rhr", "sleep_score", "recovery_score", "sleep_hours"] as const;
const BODYCOMP_KEYS = ["weight", "body_fat_pct", "lean_mass", "waist"] as const;

type DayMetrics = Record<string, number>;

// date -> metrics
interface Parsed {
  byDay: Map<string, DayMetrics>;
  rows: number;
}

/* ───────────────────────── CSV ───────────────────────── */

const COLUMN_ALIASES: Record<string, string> = {
  date: "date", day: "date", timestamp: "date",
  hrv: "hrv", heart_rate_variability: "hrv", hrv_sdnn: "hrv", hrv_rmssd: "hrv",
  rhr: "rhr", resting_hr: "rhr", resting_heart_rate: "rhr",
  sleep_score: "sleep_score", sleep: "sleep_score",
  recovery: "recovery_score", recovery_score: "recovery_score", readiness: "recovery_score", readiness_score: "recovery_score",
  sleep_hours: "sleep_hours", sleep_duration_hours: "sleep_hours", total_sleep: "sleep_hours",
  weight: "weight", weight_kg: "weight", body_mass: "weight",
  body_fat: "body_fat_pct", body_fat_pct: "body_fat_pct", body_fat_percentage: "body_fat_pct", bodyfat: "body_fat_pct",
  lean_mass: "lean_mass", lean_body_mass: "lean_mass",
  waist: "waist",
};

function splitCsvLine(line: string): string[] {
  const out: string[] = [];
  let cur = "";
  let inQ = false;
  for (let i = 0; i < line.length; i++) {
    const c = line[i];
    if (c === '"') inQ = !inQ;
    else if (c === "," && !inQ) {
      out.push(cur);
      cur = "";
    } else cur += c;
  }
  out.push(cur);
  return out.map((s) => s.trim().replace(/^"|"$/g, ""));
}

function parseCsv(text: string): Parsed {
  const lines = text.split(/\r?\n/).filter((l) => l.trim());
  const byDay = new Map<string, DayMetrics>();
  if (lines.length < 2) return { byDay, rows: 0 };

  const header = splitCsvLine(lines[0]).map((h) =>
    COLUMN_ALIASES[h.toLowerCase().replace(/\s+/g, "_")] ?? ""
  );
  const dateIdx = header.indexOf("date");
  if (dateIdx === -1) throw new Error("CSV needs a 'date' column");

  let rows = 0;
  for (let i = 1; i < lines.length; i++) {
    const cells = splitCsvLine(lines[i]);
    const rawDate = cells[dateIdx];
    if (!rawDate) continue;
    const date = rawDate.slice(0, 10);
    if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) continue;
    const day = byDay.get(date) ?? {};
    for (let c = 0; c < header.length; c++) {
      const key = header[c];
      if (!key || key === "date") continue;
      const n = parseFloat(cells[c]);
      if (!isNaN(n)) day[key] = n;
    }
    byDay.set(date, day);
    rows++;
  }
  return { byDay, rows };
}

/* ───────────────────── Apple Health XML ───────────────────── */

const HK_MAP: Record<string, string> = {
  HKQuantityTypeIdentifierHeartRateVariabilitySDNN: "hrv",
  HKQuantityTypeIdentifierRestingHeartRate: "rhr",
  HKQuantityTypeIdentifierBodyMass: "weight",
  HKQuantityTypeIdentifierBodyFatPercentage: "body_fat_pct",
  HKQuantityTypeIdentifierLeanBodyMass: "lean_mass",
};

function attr(tag: string, name: string): string | null {
  const m = tag.match(new RegExp(`${name}="([^"]*)"`));
  return m ? m[1] : null;
}

// Apple Health dates look like "2026-06-12 06:30:00 -0700". Normalize to ISO so
// Date.parse handles the timezone (space → "T", "-0700" → "-07:00").
function hkDate(s: string): number {
  const iso = s.replace(" ", "T").replace(/ ([+-]\d{2})(\d{2})$/, "$1:$2");
  return new Date(iso).getTime();
}

function parseAppleHealth(text: string): Parsed {
  const byDay = new Map<string, DayMetrics>();
  // accumulate averages for hrv/rhr; latest for body metrics; summed sleep
  const avg: Map<string, Map<string, { sum: number; n: number }>> = new Map();
  const sleepMs = new Map<string, number>();
  let rows = 0;

  const recordRe = /<Record\b[^>]*?(?:\/>|>)/g;
  let match: RegExpExecArray | null;
  while ((match = recordRe.exec(text)) !== null) {
    const tag = match[0];
    const type = attr(tag, "type");
    if (!type) continue;
    const start = attr(tag, "startDate");
    if (!start) continue;
    const date = start.slice(0, 10);
    if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) continue;

    if (type === "HKCategoryTypeIdentifierSleepAnalysis") {
      const value = attr(tag, "value") || "";
      if (/Asleep/i.test(value)) {
        const end = attr(tag, "endDate");
        if (end) {
          const ms = hkDate(end) - hkDate(start);
          if (ms > 0) sleepMs.set(date, (sleepMs.get(date) ?? 0) + ms);
        }
      }
      rows++;
      continue;
    }

    const key = HK_MAP[type];
    if (!key) continue;
    const value = parseFloat(attr(tag, "value") || "");
    if (isNaN(value)) continue;
    rows++;

    if (key === "hrv" || key === "rhr") {
      const dayAvg = avg.get(date) ?? new Map();
      const acc = dayAvg.get(key) ?? { sum: 0, n: 0 };
      acc.sum += value;
      acc.n += 1;
      dayAvg.set(key, acc);
      avg.set(date, dayAvg);
    } else {
      // weight (kg), lean_mass (kg), body_fat_pct (fraction → percent) — keep latest
      const day = byDay.get(date) ?? {};
      day[key] = key === "body_fat_pct" && value <= 1 ? Math.round(value * 1000) / 10 : value;
      byDay.set(date, day);
    }
  }

  for (const [date, m] of avg) {
    const day = byDay.get(date) ?? {};
    for (const [key, acc] of m) day[key] = Math.round(acc.sum / acc.n);
    byDay.set(date, day);
  }
  for (const [date, ms] of sleepMs) {
    const day = byDay.get(date) ?? {};
    day.sleep_hours = Math.round((ms / 3600000) * 10) / 10;
    byDay.set(date, day);
  }

  return { byDay, rows };
}

/* ───────────────────────── Route ───────────────────────── */

export async function POST(request: NextRequest) {
  const session = await getServerSession(authOptions);
  if (!session?.user?.id) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }
  const user = await prisma.user.findUnique({
    where: { id: session.user.id },
    select: { backendUserId: true },
  });
  if (!user?.backendUserId) {
    return NextResponse.json({ error: "Backend user not linked" }, { status: 400 });
  }

  let file: File | null = null;
  try {
    const form = await request.formData();
    file = form.get("file") as File | null;
  } catch {
    return NextResponse.json({ error: "Invalid upload" }, { status: 400 });
  }
  if (!file) return NextResponse.json({ error: "No file provided" }, { status: 400 });

  const name = file.name.toLowerCase();
  const text = await file.text();

  let parsed: Parsed;
  let format: string;
  try {
    if (name.endsWith(".xml") || text.includes("<HealthData")) {
      parsed = parseAppleHealth(text);
      format = "apple_health";
    } else {
      parsed = parseCsv(text);
      format = "csv";
    }
  } catch (err) {
    return NextResponse.json(
      { error: err instanceof Error ? err.message : "Could not parse file" },
      { status: 400 }
    );
  }

  // Split each day into wearable vs body-composition metrics.
  const source = format === "apple_health" ? "apple_health" : "import";
  const wearableEntries: { date: string; source: string; metrics: DayMetrics }[] = [];
  const bodyEntries: { date: string; metrics: DayMetrics }[] = [];

  for (const [date, m] of parsed.byDay) {
    const w: DayMetrics = {};
    const b: DayMetrics = {};
    for (const k of WEARABLE_KEYS) if (m[k] != null) w[k] = m[k];
    for (const k of BODYCOMP_KEYS) if (m[k] != null) b[k] = m[k];
    if (Object.keys(w).length) wearableEntries.push({ date, source, metrics: w });
    if (Object.keys(b).length) bodyEntries.push({ date, metrics: b });
  }

  // Most recent first, respect backend caps.
  wearableEntries.sort((a, b) => b.date.localeCompare(a.date));
  bodyEntries.sort((a, b) => b.date.localeCompare(a.date));
  const WEAR_CAP = 365;
  const BODY_CAP = 200;
  const wearTrunc = Math.max(0, wearableEntries.length - WEAR_CAP);
  const bodyTrunc = Math.max(0, bodyEntries.length - BODY_CAP);
  const wear = wearableEntries.slice(0, WEAR_CAP);
  const body = bodyEntries.slice(0, BODY_CAP);

  const errors: string[] = [];
  let wearableDays = 0;
  let bodyDays = 0;

  if (wear.length) {
    try {
      await backendClient("/wearables/batch", {
        method: "POST",
        userId: user.backendUserId,
        body: JSON.stringify({ entries: wear }),
      });
      wearableDays = wear.length;
    } catch {
      errors.push("Failed to save wearable metrics");
    }
  }

  if (body.length) {
    const results = await Promise.allSettled(
      body.map((e) =>
        backendClient("/body-composition", {
          method: "POST",
          userId: user.backendUserId!,
          body: JSON.stringify(e),
        })
      )
    );
    bodyDays = results.filter((r) => r.status === "fulfilled").length;
    if (bodyDays < body.length) errors.push("Some body-composition rows failed to save");
  }

  if (!parsed.rows) {
    return NextResponse.json(
      { error: "No recognizable health records found in the file" },
      { status: 400 }
    );
  }

  return NextResponse.json({
    format,
    recordsParsed: parsed.rows,
    days: parsed.byDay.size,
    wearableDays,
    bodyDays,
    truncated: wearTrunc + bodyTrunc > 0 ? { wearable: wearTrunc, body: bodyTrunc } : undefined,
    errors: errors.length ? errors : undefined,
  });
}
