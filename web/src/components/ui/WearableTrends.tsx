'use client';

import { useCallback, useEffect, useState } from 'react';
import { SampleBadge } from '@/components/charts/chart-kit';
import { sampleWearableTrends } from '@/lib/sample-data';

interface TrendDataPoint {
  date: string;
  hrv?: number;
  rhr?: number;
  sleep_score?: number;
  recovery_score?: number;
  weight_kg?: number;
  body_fat_percent?: number;
}

interface WearableTrendsProps {
  userId?: string;
}

/* Gradient mini-area sparkline */
function AreaSpark({
  data,
  color,
  id,
  height = 44,
}: {
  data: (number | null | undefined)[];
  color: string;
  id: string;
  height?: number;
}) {
  const valid = data.filter((d): d is number => d != null && !isNaN(d));
  if (valid.length < 2) {
    return <div className="text-xs text-[var(--text-tertiary)]">Not enough data</div>;
  }
  const min = Math.min(...valid);
  const max = Math.max(...valid);
  const range = max - min || 1;
  const pts = data
    .map((value, idx) => {
      if (value == null || isNaN(value)) return null;
      const x = (idx / (data.length - 1)) * 100;
      const y = height - 4 - ((value - min) / range) * (height - 8);
      return { x, y };
    })
    .filter((p): p is { x: number; y: number } => p !== null);

  const line = pts.map((p, i) => `${i === 0 ? 'M' : 'L'} ${p.x},${p.y}`).join(' ');
  const area = `${line} L ${pts[pts.length - 1].x},${height} L ${pts[0].x},${height} Z`;

  return (
    <svg viewBox={`0 0 100 ${height}`} className="w-full" style={{ height }} preserveAspectRatio="none">
      <defs>
        <linearGradient id={id} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor={color} stopOpacity={0.3} />
          <stop offset="100%" stopColor={color} stopOpacity={0} />
        </linearGradient>
      </defs>
      <path d={area} fill={`url(#${id})`} stroke="none" />
      <path d={line} fill="none" stroke={color} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" vectorEffect="non-scaling-stroke" />
      <circle cx={pts[pts.length - 1].x} cy={pts[pts.length - 1].y} r="2.5" fill={color} vectorEffect="non-scaling-stroke" />
    </svg>
  );
}

function calculateTrend(data: (number | null | undefined)[]): 'up' | 'down' | 'stable' {
  const valid = data.filter((d): d is number => d != null && !isNaN(d));
  if (valid.length < 3) return 'stable';
  const recent = valid.slice(-3);
  const older = valid.slice(0, 3);
  const recentAvg = recent.reduce((a, b) => a + b, 0) / recent.length;
  const olderAvg = older.reduce((a, b) => a + b, 0) / older.length;
  const diff = recentAvg - olderAvg;
  const threshold = olderAvg * 0.05;
  if (diff > threshold) return 'up';
  if (diff < -threshold) return 'down';
  return 'stable';
}

function TrendCard({
  label,
  value,
  unit,
  trend,
  trendData,
  color,
  sparkId,
  invert,
}: {
  label: string;
  value: number | null | undefined;
  unit: string;
  trend: 'up' | 'down' | 'stable';
  trendData: (number | null | undefined)[];
  color: string;
  sparkId: string;
  invert?: boolean;
}) {
  // For metrics where down is good (RHR), flip the color semantics.
  const good = invert ? trend === 'down' : trend === 'up';
  const bad = invert ? trend === 'up' : trend === 'down';
  const trendColor = good ? 'var(--green)' : bad ? 'var(--red)' : 'var(--text-tertiary)';
  const arrow = trend === 'up' ? '↑' : trend === 'down' ? '↓' : '→';

  return (
    <div className="rounded-[var(--radius-md)] border border-[var(--border)] bg-[var(--surface-card)] p-4">
      <div className="mb-2 flex items-center justify-between">
        <span className="text-xs text-[var(--text-secondary)]">{label}</span>
        <span className="text-xs font-medium" style={{ color: trendColor }}>{arrow} 7d</span>
      </div>
      <div className="mb-2 flex items-baseline gap-1">
        <span className="font-mono text-2xl font-semibold text-[var(--text-primary)]">
          {value != null ? value.toFixed(label === 'Weight' ? 1 : 0) : '--'}
        </span>
        <span className="text-sm text-[var(--text-tertiary)]">{unit}</span>
      </div>
      <AreaSpark data={trendData} color={color} id={sparkId} />
    </div>
  );
}

export function WearableTrends({ userId }: WearableTrendsProps) {
  const [trends, setTrends] = useState<TrendDataPoint[]>([]);
  const [loading, setLoading] = useState(true);

  const fetchTrends = useCallback(async () => {
    try {
      setLoading(true);
      const resp = await fetch('/api/wearables/trends?days=7');
      if (!resp.ok) throw new Error();
      const data = await resp.json();
      setTrends(data.trends || []);
    } catch {
      setTrends([]);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchTrends();
  }, [fetchTrends, userId]);

  if (loading) {
    return (
      <div className="grid grid-cols-2 gap-4 md:grid-cols-4">
        {[1, 2, 3, 4].map((i) => (
          <div key={i} className="animate-pulse rounded-[var(--radius-md)] border border-[var(--border)] bg-[var(--surface-card)] p-4">
            <div className="mb-3 h-3.5 w-16 rounded bg-[var(--gray-300)]" />
            <div className="mb-3 h-7 w-20 rounded bg-[var(--gray-300)]" />
            <div className="h-11 rounded bg-[var(--gray-300)]" />
          </div>
        ))}
      </div>
    );
  }

  // Fall back to illustrative sample data when nothing is connected yet.
  const isSample = trends.length === 0;
  const display = isSample ? sampleWearableTrends(7) : trends;

  const hrvData = display.map((t) => t.hrv);
  const rhrData = display.map((t) => t.rhr);
  const sleepData = display.map((t) => t.sleep_score);
  const recoveryData = display.map((t) => t.recovery_score);

  const last = (arr: (number | null | undefined)[]) => arr.filter((d) => d != null).pop();

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between">
        <h3 className="text-sm font-semibold text-[var(--text-primary)]">7-Day Trends</h3>
        {isSample ? <SampleBadge /> : (
          <span className="text-xs text-[var(--text-tertiary)]">
            {display.length} day{display.length !== 1 ? 's' : ''} of data
          </span>
        )}
      </div>

      <div className="grid grid-cols-2 gap-4 md:grid-cols-4">
        <TrendCard label="HRV" value={last(hrvData)} unit="ms" trend={calculateTrend(hrvData)} trendData={hrvData} color="var(--green)" sparkId="spark-hrv" />
        <TrendCard label="Resting HR" value={last(rhrData)} unit="bpm" trend={calculateTrend(rhrData)} trendData={rhrData} color="var(--accent)" sparkId="spark-rhr" invert />
        <TrendCard label="Sleep Score" value={last(sleepData)} unit="" trend={calculateTrend(sleepData)} trendData={sleepData} color="#a78bfa" sparkId="spark-sleep" />
        <TrendCard label="Recovery" value={last(recoveryData)} unit="%" trend={calculateTrend(recoveryData)} trendData={recoveryData} color="#22d3ee" sparkId="spark-rec" />
      </div>
    </div>
  );
}
