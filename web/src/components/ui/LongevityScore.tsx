"use client";

import { useEffect, useState } from "react";
import { ScoreRing, SampleBadge } from "@/components/charts/chart-kit";
import { sampleLongevityScore, type ScoreBreakdown } from "@/lib/sample-data";

function barColor(v: number) {
  return v >= 75 ? "var(--green)" : v >= 50 ? "var(--amber)" : "var(--red)";
}

interface ScoreData {
  score: number;
  delta: number | null;
  breakdown: ScoreBreakdown[];
}

export function LongevityScore() {
  const [data, setData] = useState<ScoreData | null>(null);
  const [isSample, setIsSample] = useState(false);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        const res = await fetch("/api/backend/analytics/longevity-score");
        const json = res.ok ? await res.json() : null;
        if (cancelled) return;
        if (json?.has_data && Array.isArray(json.breakdown) && json.breakdown.length) {
          setData({ score: json.score, delta: json.delta ?? null, breakdown: json.breakdown });
          setIsSample(false);
        } else {
          setData(sampleLongevityScore());
          setIsSample(true);
        }
      } catch {
        if (cancelled) return;
        setData(sampleLongevityScore());
        setIsSample(true);
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, []);

  if (loading || !data) {
    return (
      <div className="h-[228px] animate-pulse rounded-[var(--radius-lg)] border border-[var(--border)] bg-[var(--surface-card)]" />
    );
  }

  const { score, delta, breakdown } = data;
  const sublabel =
    delta != null ? `${delta >= 0 ? "+" : ""}${delta} this month` : undefined;

  return (
    <div className="rounded-[var(--radius-lg)] border border-[var(--border)] bg-[var(--surface-card)] p-5 md:p-6">
      <div className="mb-5 flex items-center justify-between">
        <div>
          <h2 className="text-base font-semibold text-[var(--text-primary)]">Longevity Score</h2>
          <p className="mt-0.5 text-xs text-[var(--text-tertiary)]">
            Composite of cardiovascular, metabolic, recovery & body-composition signals
          </p>
        </div>
        {isSample && <SampleBadge />}
      </div>

      <div className="flex flex-col items-center gap-6 md:flex-row md:items-center md:gap-8">
        <div className="flex shrink-0 flex-col items-center">
          <ScoreRing value={score} size={150} label="Score" sublabel={sublabel} />
        </div>

        <div className="w-full flex-1 space-y-3">
          {breakdown.map((b) => (
            <div key={b.label}>
              <div className="mb-1 flex items-center justify-between text-xs">
                <span className="font-medium text-[var(--text-primary)]">{b.label}</span>
                <span className="font-mono text-[var(--text-secondary)]">{b.value}</span>
              </div>
              <div className="h-1.5 w-full overflow-hidden rounded-full bg-[var(--gray-300)]">
                <div
                  className="h-full rounded-full"
                  style={{
                    width: `${b.value}%`,
                    background: barColor(b.value),
                    transition: "width 0.9s cubic-bezier(0.4,0,0.2,1)",
                  }}
                />
              </div>
              {b.detail && <p className="mt-1 text-[11px] text-[var(--text-tertiary)]">{b.detail}</p>}
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
