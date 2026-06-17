/**
 * Deterministic sample/demo data.
 *
 * Used as a clearly-labelled fallback when no real data is connected yet, so the
 * dashboard and Trends surfaces render as a living product instead of an empty
 * shell. Everything is seeded (no Math.random at render) to stay hydration-safe.
 */

function rng(seed: number) {
  let s = seed >>> 0;
  return () => {
    s = (s * 1664525 + 1013904223) >>> 0;
    return s / 4294967296;
  };
}

function daysAgoISO(n: number): string {
  const d = new Date();
  d.setDate(d.getDate() - n);
  return d.toISOString().slice(0, 10);
}

export interface WearablePoint {
  date: string;
  hrv: number;
  rhr: number;
  sleep_score: number;
  recovery_score: number;
  sleep_hours: number;
  [key: string]: number | string;
}

export function sampleWearableTrends(days = 30): WearablePoint[] {
  const r = rng(days * 7 + 13);
  const out: WearablePoint[] = [];
  for (let i = days - 1; i >= 0; i--) {
    const t = (days - i) / days; // 0 → 1 over time
    const wave = Math.sin(i / 3.2);
    out.push({
      date: daysAgoISO(i),
      hrv: Math.round(52 + t * 10 + wave * 6 + (r() - 0.5) * 5),
      rhr: Math.round(54 - t * 3 + wave * 1.5 + (r() - 0.5) * 3),
      sleep_score: Math.round(78 + t * 6 + wave * 5 + (r() - 0.5) * 6),
      recovery_score: Math.round(62 + t * 12 + wave * 8 + (r() - 0.5) * 7),
      sleep_hours: Math.round((6.8 + t * 0.5 + wave * 0.4 + (r() - 0.5) * 0.6) * 10) / 10,
    });
  }
  return out;
}

export interface BodyCompPoint {
  date: string;
  weight: number;
  body_fat_pct: number;
  lean_mass: number;
  [key: string]: number | string;
}

export function sampleBodyComp(days = 90): BodyCompPoint[] {
  const r = rng(days * 3 + 5);
  const out: BodyCompPoint[] = [];
  // sample weekly so a 90-day window reads cleanly
  for (let i = days - 1; i >= 0; i -= 7) {
    const t = (days - i) / days;
    out.push({
      date: daysAgoISO(i),
      weight: Math.round((84 - t * 3.5 + (r() - 0.5) * 0.6) * 10) / 10,
      body_fat_pct: Math.round((19.5 - t * 3 + (r() - 0.5) * 0.5) * 10) / 10,
      lean_mass: Math.round((64 + t * 1.8 + (r() - 0.5) * 0.4) * 10) / 10,
    });
  }
  return out;
}

export interface BiomarkerSeries {
  name: string;
  unit: string;
  reference_low: number | null;
  reference_high: number | null;
  optimal?: string;
  history: Array<{ date: string; value: number }>;
}

export const sampleBiomarkers: BiomarkerSeries[] = [
  {
    name: "ApoB",
    unit: "mg/dL",
    reference_low: 0,
    reference_high: 90,
    optimal: "< 80 mg/dL for longevity",
    history: [
      { date: daysAgoISO(270), value: 104 },
      { date: daysAgoISO(180), value: 98 },
      { date: daysAgoISO(90), value: 91 },
      { date: daysAgoISO(7), value: 84 },
    ],
  },
  {
    name: "LDL Cholesterol",
    unit: "mg/dL",
    reference_low: 0,
    reference_high: 100,
    history: [
      { date: daysAgoISO(270), value: 138 },
      { date: daysAgoISO(180), value: 126 },
      { date: daysAgoISO(90), value: 115 },
      { date: daysAgoISO(7), value: 104 },
    ],
  },
  {
    name: "HbA1c",
    unit: "%",
    reference_low: 4,
    reference_high: 5.6,
    optimal: "< 5.3% optimal",
    history: [
      { date: daysAgoISO(270), value: 5.6 },
      { date: daysAgoISO(180), value: 5.5 },
      { date: daysAgoISO(90), value: 5.3 },
      { date: daysAgoISO(7), value: 5.2 },
    ],
  },
  {
    name: "hs-CRP",
    unit: "mg/L",
    reference_low: 0,
    reference_high: 1,
    optimal: "< 0.5 mg/L optimal",
    history: [
      { date: daysAgoISO(270), value: 1.4 },
      { date: daysAgoISO(180), value: 1.1 },
      { date: daysAgoISO(90), value: 0.7 },
      { date: daysAgoISO(7), value: 0.5 },
    ],
  },
  {
    name: "Vitamin D",
    unit: "ng/mL",
    reference_low: 30,
    reference_high: 100,
    optimal: "40–60 ng/mL optimal",
    history: [
      { date: daysAgoISO(270), value: 28 },
      { date: daysAgoISO(180), value: 34 },
      { date: daysAgoISO(90), value: 44 },
      { date: daysAgoISO(7), value: 52 },
    ],
  },
  {
    name: "Testosterone",
    unit: "ng/dL",
    reference_low: 300,
    reference_high: 1000,
    history: [
      { date: daysAgoISO(270), value: 520 },
      { date: daysAgoISO(180), value: 580 },
      { date: daysAgoISO(90), value: 640 },
      { date: daysAgoISO(7), value: 710 },
    ],
  },
];

export interface ScoreBreakdown {
  label: string;
  value: number;
  detail: string;
}

export interface LongevityScore {
  score: number;
  delta: number;
  breakdown: ScoreBreakdown[];
}

export function sampleLongevityScore(): LongevityScore {
  const breakdown: ScoreBreakdown[] = [
    { label: "Cardiovascular", value: 74, detail: "ApoB & LDL trending down" },
    { label: "Metabolic", value: 83, detail: "HbA1c 5.2%, glucose stable" },
    { label: "Recovery", value: 86, detail: "HRV up 18% over 30d" },
    { label: "Body Comp", value: 76, detail: "Body fat −3% in 90d" },
    { label: "Inflammation", value: 89, detail: "hs-CRP 0.5 mg/L" },
  ];
  const score = Math.round(
    breakdown.reduce((a, b) => a + b.value, 0) / breakdown.length
  );
  return { score, delta: 4, breakdown };
}
