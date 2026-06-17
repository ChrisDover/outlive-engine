"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import {
  AreaTrend,
  ChartFrame,
  MultiLineTrend,
  ReferenceRangeChart,
  SampleBadge,
  SERIES_COLORS,
} from "@/components/charts/chart-kit";
import {
  sampleBiomarkers,
  sampleBodyComp,
  sampleWearableTrends,
  type BiomarkerSeries,
  type WearablePoint,
} from "@/lib/sample-data";

const RANGES = [7, 30, 90] as const;
type Range = (typeof RANGES)[number];

function RangeSelector({ value, onChange }: { value: Range; onChange: (r: Range) => void }) {
  return (
    <div className="inline-flex rounded-[var(--radius-md)] border border-[var(--border)] p-0.5">
      {RANGES.map((r) => (
        <button
          key={r}
          onClick={() => onChange(r)}
          className="rounded-[var(--radius-sm)] px-2.5 py-1 text-xs font-medium transition-colors"
          style={{
            background: value === r ? "var(--gray-300)" : "transparent",
            color: value === r ? "var(--text-primary)" : "var(--text-tertiary)",
          }}
        >
          {r}d
        </button>
      ))}
    </div>
  );
}

export function TrendsContent() {
  const [range, setRange] = useState<Range>(30);
  const [trends, setTrends] = useState<WearablePoint[] | null>(null);
  const [loading, setLoading] = useState(true);

  const fetchTrends = useCallback(async (days: Range) => {
    setLoading(true);
    try {
      const res = await fetch(`/api/wearables/trends?days=${days}`);
      const data = res.ok ? await res.json() : { trends: [] };
      setTrends(Array.isArray(data.trends) ? data.trends : []);
    } catch {
      setTrends([]);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchTrends(range);
  }, [fetchTrends, range]);

  const isSample = !loading && (trends?.length ?? 0) === 0;
  const wearable = useMemo<WearablePoint[]>(
    () => (isSample ? sampleWearableTrends(range) : (trends as WearablePoint[]) ?? []),
    [isSample, range, trends]
  );

  const bodyComp = useMemo(() => sampleBodyComp(90), []);

  // Real biomarker series derived from stored bloodwork panels; sample fallback.
  const [bio, setBio] = useState<BiomarkerSeries[]>(sampleBiomarkers);
  const [bioSample, setBioSample] = useState(true);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        const res = await fetch("/api/backend/analytics/biomarkers");
        const json = res.ok ? await res.json() : null;
        if (cancelled) return;
        if (Array.isArray(json) && json.length) {
          setBio(json as BiomarkerSeries[]);
          setBioSample(false);
        }
      } catch {
        /* keep sample fallback */
      }
    })();
    return () => {
      cancelled = true;
    };
  }, []);

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h1>Trends</h1>
          <p className="mt-0.5 text-sm text-muted">
            Your biomarkers and wearable metrics over time, with reference ranges.
          </p>
        </div>
        <RangeSelector value={range} onChange={setRange} />
      </div>

      {/* Recovery & sleep */}
      <ChartFrame
        title="Recovery & Sleep"
        subtitle={`Last ${range} days`}
        right={isSample ? <SampleBadge /> : undefined}
      >
        {loading ? (
          <div className="h-[260px] animate-pulse rounded-[var(--radius-md)] bg-[var(--gray-200)]" />
        ) : (
          <MultiLineTrend
            data={wearable}
            series={[
              { key: "recovery_score", label: "Recovery", color: SERIES_COLORS[4] },
              { key: "hrv", label: "HRV", color: SERIES_COLORS[1] },
              { key: "sleep_score", label: "Sleep", color: SERIES_COLORS[2] },
            ]}
          />
        )}
      </ChartFrame>

      {/* Body composition */}
      <div className="grid gap-6 lg:grid-cols-2">
        <ChartFrame title="Body Composition" subtitle="Weight, 90 days" right={<SampleBadge />}>
          <AreaTrend data={bodyComp} dataKey="weight" label="Weight" unit="kg" color={SERIES_COLORS[0]} />
        </ChartFrame>
        <ChartFrame title="Body Fat & Lean Mass" subtitle="90 days" right={<SampleBadge />}>
          <MultiLineTrend
            data={bodyComp}
            height={220}
            series={[
              { key: "body_fat_pct", label: "Body Fat %", color: SERIES_COLORS[3] },
              { key: "lean_mass", label: "Lean Mass (kg)", color: SERIES_COLORS[1] },
            ]}
          />
        </ChartFrame>
      </div>

      {/* Biomarkers */}
      <div>
        <div className="mb-3 flex items-center justify-between">
          <h2 className="text-base font-semibold text-[var(--text-primary)]">Biomarkers</h2>
          {bioSample && <SampleBadge />}
        </div>
        <div className="grid gap-6 lg:grid-cols-2">
          {bio.map((b) => {
            const latest = b.history[b.history.length - 1];
            const out =
              (b.reference_high != null && latest.value > b.reference_high) ||
              (b.reference_low != null && latest.value < b.reference_low);
            return (
              <ChartFrame
                key={b.name}
                title={b.name}
                subtitle={b.optimal ?? (b.reference_low != null ? `Ref: ${b.reference_low}–${b.reference_high} ${b.unit}` : undefined)}
                right={
                  <div className="text-right">
                    <div className="font-mono text-lg font-semibold" style={{ color: out ? "var(--red)" : "var(--green)" }}>
                      {latest.value} <span className="text-xs text-[var(--text-tertiary)]">{b.unit}</span>
                    </div>
                    <div className="text-[10px] uppercase tracking-wide" style={{ color: out ? "var(--red)" : "var(--green)" }}>
                      {out ? "Out of range" : "In range"}
                    </div>
                  </div>
                }
              >
                <ReferenceRangeChart
                  data={b.history}
                  low={b.reference_low}
                  high={b.reference_high}
                  unit={b.unit}
                  color={out ? "var(--red)" : SERIES_COLORS[1]}
                  height={180}
                />
              </ChartFrame>
            );
          })}
        </div>
      </div>
    </div>
  );
}
