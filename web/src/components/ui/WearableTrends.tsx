'use client';

import { useEffect, useState } from 'react';

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

// Simple sparkline component
function Sparkline({
  data,
  color,
  height = 40,
}: {
  data: (number | null | undefined)[];
  color: string;
  height?: number;
}) {
  const validData = data.filter((d): d is number => d != null && !isNaN(d));
  if (validData.length < 2) {
    return <div className="text-xs text-muted">Not enough data</div>;
  }

  const min = Math.min(...validData);
  const max = Math.max(...validData);
  const range = max - min || 1;

  const points = data
    .map((value, idx) => {
      if (value == null || isNaN(value)) return null;
      const x = (idx / (data.length - 1)) * 100;
      const y = height - ((value - min) / range) * height;
      return `${x},${y}`;
    })
    .filter(Boolean);

  const pathD = points.reduce((acc, point, idx) => {
    if (idx === 0) return `M ${point}`;
    return `${acc} L ${point}`;
  }, '');

  return (
    <svg
      viewBox={`0 0 100 ${height}`}
      className="w-full"
      style={{ height }}
      preserveAspectRatio="none"
    >
      <path
        d={pathD}
        fill="none"
        stroke={color}
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
        vectorEffect="non-scaling-stroke"
      />
      {/* Current value dot */}
      {points.length > 0 && (
        <circle
          cx={points[points.length - 1]?.split(',')[0]}
          cy={points[points.length - 1]?.split(',')[1]}
          r="3"
          fill={color}
        />
      )}
    </svg>
  );
}

// Metric card with trend
function TrendCard({
  label,
  value,
  unit,
  trend,
  trendData,
  color,
}: {
  label: string;
  value: number | null | undefined;
  unit: string;
  trend?: 'up' | 'down' | 'stable';
  trendData: (number | null | undefined)[];
  color: string;
}) {
  const trendIcon = {
    up: '↑',
    down: '↓',
    stable: '→',
  }[trend || 'stable'];

  const trendColor = {
    up: 'text-recovery-green',
    down: 'text-recovery-red',
    stable: 'text-muted',
  }[trend || 'stable'];

  return (
    <div className="bg-card border border-[var(--surface-elevated)] rounded-[var(--radius-md)] p-[var(--space-md)]">
      <div className="flex items-center justify-between mb-[var(--space-sm)]">
        <span className="text-xs text-muted">{label}</span>
        {trend && (
          <span className={`text-xs ${trendColor}`}>
            {trendIcon} 7d
          </span>
        )}
      </div>
      <div className="flex items-baseline gap-[var(--space-xs)] mb-[var(--space-sm)]">
        <span className="text-2xl font-mono font-semibold text-foreground">
          {value != null ? value.toFixed(label === 'Weight' ? 1 : 0) : '--'}
        </span>
        <span className="text-sm text-muted">{unit}</span>
      </div>
      <Sparkline data={trendData} color={color} />
    </div>
  );
}

function calculateTrend(data: (number | null | undefined)[]): 'up' | 'down' | 'stable' {
  const validData = data.filter((d): d is number => d != null && !isNaN(d));
  if (validData.length < 3) return 'stable';

  const recent = validData.slice(-3);
  const older = validData.slice(0, 3);

  const recentAvg = recent.reduce((a, b) => a + b, 0) / recent.length;
  const olderAvg = older.reduce((a, b) => a + b, 0) / older.length;

  const diff = recentAvg - olderAvg;
  const threshold = olderAvg * 0.05; // 5% change threshold

  if (diff > threshold) return 'up';
  if (diff < -threshold) return 'down';
  return 'stable';
}

export function WearableTrends({ userId }: WearableTrendsProps) {
  const [trends, setTrends] = useState<TrendDataPoint[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    async function fetchTrends() {
      try {
        setLoading(true);
        const resp = await fetch('/api/wearables/trends?days=7');
        if (!resp.ok) {
          throw new Error('Failed to fetch trends');
        }
        const data = await resp.json();
        setTrends(data.trends || []);
      } catch (err) {
        setError(err instanceof Error ? err.message : 'Unknown error');
      } finally {
        setLoading(false);
      }
    }

    fetchTrends();
  }, [userId]);

  if (loading) {
    return (
      <div className="grid grid-cols-2 md:grid-cols-4 gap-[var(--space-md)]">
        {[1, 2, 3, 4].map((i) => (
          <div
            key={i}
            className="bg-card border border-[var(--surface-elevated)] rounded-[var(--radius-md)] p-[var(--space-md)] animate-pulse"
          >
            <div className="h-4 bg-[var(--surface-secondary)] rounded w-16 mb-2" />
            <div className="h-8 bg-[var(--surface-secondary)] rounded w-20 mb-2" />
            <div className="h-10 bg-[var(--surface-secondary)] rounded" />
          </div>
        ))}
      </div>
    );
  }

  if (error || trends.length === 0) {
    return (
      <div className="bg-card border border-[var(--surface-elevated)] rounded-[var(--radius-md)] p-[var(--space-lg)] text-center">
        <p className="text-muted">
          {error || 'No trend data available. Connect a wearable to see your metrics.'}
        </p>
      </div>
    );
  }

  const hrvData = trends.map((t) => t.hrv);
  const rhrData = trends.map((t) => t.rhr);
  const sleepData = trends.map((t) => t.sleep_score);
  const recoveryData = trends.map((t) => t.recovery_score);

  const latestHrv = hrvData.filter((d) => d != null).pop();
  const latestRhr = rhrData.filter((d) => d != null).pop();
  const latestSleep = sleepData.filter((d) => d != null).pop();
  const latestRecovery = recoveryData.filter((d) => d != null).pop();

  return (
    <div className="space-y-[var(--space-md)]">
      <div className="flex items-center justify-between">
        <h3 className="text-sm font-medium text-foreground">7-Day Trends</h3>
        <span className="text-xs text-muted">
          {trends.length} day{trends.length !== 1 ? 's' : ''} of data
        </span>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-4 gap-[var(--space-md)]">
        <TrendCard
          label="HRV"
          value={latestHrv}
          unit="ms"
          trend={calculateTrend(hrvData)}
          trendData={hrvData}
          color="var(--recovery-green)"
        />
        <TrendCard
          label="Resting HR"
          value={latestRhr}
          unit="bpm"
          trend={calculateTrend(rhrData.map((d) => d ? -d : null))} // Invert for RHR (lower is better)
          trendData={rhrData}
          color="var(--recovery-red)"
        />
        <TrendCard
          label="Sleep Score"
          value={latestSleep}
          unit=""
          trend={calculateTrend(sleepData)}
          trendData={sleepData}
          color="var(--interventions)"
        />
        <TrendCard
          label="Recovery"
          value={latestRecovery}
          unit="%"
          trend={calculateTrend(recoveryData)}
          trendData={recoveryData}
          color="var(--training)"
        />
      </div>
    </div>
  );
}
