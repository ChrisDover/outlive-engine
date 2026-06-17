"use client";

import {
  Area,
  AreaChart,
  CartesianGrid,
  Line,
  LineChart,
  ReferenceArea,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";

/* ─────────────────────────  Theme  ───────────────────────── */

export const SERIES_COLORS = [
  "#0070f3", // accent blue
  "#2dd4a7", // green
  "#a78bfa", // violet
  "#f5a623", // amber
  "#22d3ee", // cyan
  "#f472b6", // pink
];

const GRID = "var(--gray-300)";
const AXIS = "var(--text-tertiary)";

function fmtDate(value: string) {
  const d = new Date(value);
  if (isNaN(d.getTime())) return value;
  return d.toLocaleDateString("en-US", { month: "short", day: "numeric" });
}

/* ─────────────────────────  Frame  ───────────────────────── */

export function ChartFrame({
  title,
  subtitle,
  right,
  children,
  className = "",
}: {
  title?: string;
  subtitle?: string;
  right?: React.ReactNode;
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <div
      className={`rounded-[var(--radius-lg)] border border-[var(--border)] bg-[var(--surface-card)] p-4 md:p-5 ${className}`}
    >
      {(title || right) && (
        <div className="mb-4 flex items-start justify-between gap-3">
          <div>
            {title && (
              <h3 className="text-sm font-semibold text-[var(--text-primary)]">{title}</h3>
            )}
            {subtitle && (
              <p className="mt-0.5 text-xs text-[var(--text-tertiary)]">{subtitle}</p>
            )}
          </div>
          {right && <div className="shrink-0">{right}</div>}
        </div>
      )}
      {children}
    </div>
  );
}

export function SampleBadge() {
  return (
    <span
      className="inline-flex items-center gap-1.5 rounded-full border px-2 py-0.5 text-[10px] font-medium uppercase tracking-wide"
      style={{ borderColor: "var(--border)", color: "var(--text-tertiary)" }}
      title="Showing illustrative sample data — connect your sources to see real metrics"
    >
      <span className="h-1.5 w-1.5 rounded-full" style={{ background: "var(--amber)" }} />
      Sample data
    </span>
  );
}

/* ─────────────────────────  Tooltip  ───────────────────────── */

interface TooltipPayloadItem {
  name?: string;
  value?: number | string;
  color?: string;
  dataKey?: string | number;
  unit?: string;
}

function ChartTooltip({
  active,
  payload,
  label,
  unit,
}: {
  active?: boolean;
  payload?: TooltipPayloadItem[];
  label?: string;
  unit?: string;
}) {
  if (!active || !payload?.length) return null;
  return (
    <div className="rounded-[var(--radius-md)] border border-[var(--border-strong)] bg-[var(--gray-100)] px-3 py-2 shadow-[var(--shadow-md)]">
      <div className="mb-1 text-[11px] font-medium text-[var(--text-tertiary)]">
        {label ? fmtDate(label) : ""}
      </div>
      {payload.map((p, i) => (
        <div key={i} className="flex items-center gap-2 text-xs">
          <span className="h-2 w-2 rounded-full" style={{ background: p.color }} />
          <span className="text-[var(--text-secondary)]">{p.name}</span>
          <span className="ml-auto font-mono font-medium text-[var(--text-primary)]">
            {typeof p.value === "number" ? Math.round(p.value * 10) / 10 : p.value}
            {unit ? ` ${unit}` : ""}
          </span>
        </div>
      ))}
    </div>
  );
}

/* ─────────────────────────  Area trend  ───────────────────────── */

export function AreaTrend({
  data,
  dataKey,
  label,
  color = SERIES_COLORS[0],
  unit,
  height = 220,
  domain,
}: {
  data: Array<Record<string, number | string | null>>;
  dataKey: string;
  label?: string;
  color?: string;
  unit?: string;
  height?: number;
  domain?: [number | "auto" | "dataMin", number | "auto" | "dataMax"];
}) {
  const gid = `grad-${dataKey}`;
  return (
    <ResponsiveContainer width="100%" height={height}>
      <AreaChart data={data} margin={{ top: 6, right: 6, left: 0, bottom: 0 }}>
        <defs>
          <linearGradient id={gid} x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor={color} stopOpacity={0.32} />
            <stop offset="100%" stopColor={color} stopOpacity={0} />
          </linearGradient>
        </defs>
        <CartesianGrid stroke={GRID} strokeDasharray="3 3" vertical={false} />
        <XAxis
          dataKey="date"
          tickFormatter={fmtDate}
          tick={{ fill: AXIS, fontSize: 11 }}
          tickLine={false}
          axisLine={{ stroke: GRID }}
          minTickGap={24}
        />
        <YAxis
          domain={domain ?? ["auto", "auto"]}
          tick={{ fill: AXIS, fontSize: 11 }}
          tickLine={false}
          axisLine={false}
          width={34}
        />
        <Tooltip
          content={<ChartTooltip unit={unit} />}
          cursor={{ stroke: GRID, strokeWidth: 1 }}
        />
        <Area
          type="monotone"
          dataKey={dataKey}
          name={label ?? dataKey}
          stroke={color}
          strokeWidth={2}
          fill={`url(#${gid})`}
          dot={false}
          activeDot={{ r: 4, strokeWidth: 0 }}
          connectNulls
          isAnimationActive
        />
      </AreaChart>
    </ResponsiveContainer>
  );
}

/* ─────────────────────────  Multi-line trend  ───────────────────────── */

export function MultiLineTrend({
  data,
  series,
  height = 260,
}: {
  data: Array<Record<string, number | string | null>>;
  series: Array<{ key: string; label: string; color: string }>;
  height?: number;
}) {
  return (
    <div>
      <ResponsiveContainer width="100%" height={height}>
        <LineChart data={data} margin={{ top: 6, right: 6, left: 0, bottom: 0 }}>
          <CartesianGrid stroke={GRID} strokeDasharray="3 3" vertical={false} />
          <XAxis
            dataKey="date"
            tickFormatter={fmtDate}
            tick={{ fill: AXIS, fontSize: 11 }}
            tickLine={false}
            axisLine={{ stroke: GRID }}
            minTickGap={24}
          />
          <YAxis
            tick={{ fill: AXIS, fontSize: 11 }}
            tickLine={false}
            axisLine={false}
            width={34}
          />
          <Tooltip content={<ChartTooltip />} cursor={{ stroke: GRID, strokeWidth: 1 }} />
          {series.map((s) => (
            <Line
              key={s.key}
              type="monotone"
              dataKey={s.key}
              name={s.label}
              stroke={s.color}
              strokeWidth={2}
              dot={false}
              activeDot={{ r: 4, strokeWidth: 0 }}
              connectNulls
            />
          ))}
        </LineChart>
      </ResponsiveContainer>
      <div className="mt-3 flex flex-wrap gap-x-4 gap-y-1.5">
        {series.map((s) => (
          <div key={s.key} className="flex items-center gap-1.5 text-xs text-[var(--text-secondary)]">
            <span className="h-2 w-2 rounded-full" style={{ background: s.color }} />
            {s.label}
          </div>
        ))}
      </div>
    </div>
  );
}

/* ─────────────────────────  Biomarker reference-range chart  ───────────────────────── */

export function ReferenceRangeChart({
  data,
  low,
  high,
  unit,
  color = SERIES_COLORS[1],
  height = 220,
}: {
  data: Array<{ date: string; value: number }>;
  low?: number | null;
  high?: number | null;
  unit?: string;
  color?: string;
  height?: number;
}) {
  return (
    <ResponsiveContainer width="100%" height={height}>
      <LineChart data={data} margin={{ top: 6, right: 6, left: 0, bottom: 0 }}>
        <CartesianGrid stroke={GRID} strokeDasharray="3 3" vertical={false} />
        {low != null && high != null && (
          <ReferenceArea
            y1={low}
            y2={high}
            fill="var(--green)"
            fillOpacity={0.08}
            stroke="var(--green)"
            strokeOpacity={0.25}
            strokeDasharray="3 3"
            ifOverflow="extendDomain"
          />
        )}
        <XAxis
          dataKey="date"
          tickFormatter={fmtDate}
          tick={{ fill: AXIS, fontSize: 11 }}
          tickLine={false}
          axisLine={{ stroke: GRID }}
          minTickGap={24}
        />
        <YAxis
          tick={{ fill: AXIS, fontSize: 11 }}
          tickLine={false}
          axisLine={false}
          width={40}
        />
        <Tooltip content={<ChartTooltip unit={unit} />} cursor={{ stroke: GRID, strokeWidth: 1 }} />
        <Line
          type="monotone"
          dataKey="value"
          name="Value"
          stroke={color}
          strokeWidth={2}
          dot={{ r: 3, strokeWidth: 0, fill: color }}
          activeDot={{ r: 5, strokeWidth: 0 }}
          connectNulls
        />
      </LineChart>
    </ResponsiveContainer>
  );
}

/* ─────────────────────────  Score ring (pure SVG)  ───────────────────────── */

export function ScoreRing({
  value,
  size = 160,
  stroke = 12,
  label,
  sublabel,
}: {
  value: number;
  size?: number;
  stroke?: number;
  label?: string;
  sublabel?: string;
}) {
  const v = Math.max(0, Math.min(100, value));
  const r = (size - stroke) / 2;
  const c = 2 * Math.PI * r;
  const offset = c * (1 - v / 100);
  const color =
    v >= 75 ? "var(--green)" : v >= 50 ? "var(--amber)" : "var(--red)";

  return (
    <div className="relative inline-flex items-center justify-center" style={{ width: size, height: size }}>
      <svg width={size} height={size} className="-rotate-90">
        <circle cx={size / 2} cy={size / 2} r={r} fill="none" stroke="var(--gray-300)" strokeWidth={stroke} />
        <circle
          cx={size / 2}
          cy={size / 2}
          r={r}
          fill="none"
          stroke={color}
          strokeWidth={stroke}
          strokeLinecap="round"
          strokeDasharray={c}
          strokeDashoffset={offset}
          style={{ transition: "stroke-dashoffset 0.9s cubic-bezier(0.4,0,0.2,1)" }}
        />
      </svg>
      <div className="absolute inset-0 flex flex-col items-center justify-center">
        <span className="font-mono text-3xl font-semibold text-[var(--text-primary)]">{Math.round(v)}</span>
        {label && <span className="text-[11px] uppercase tracking-wider text-[var(--text-tertiary)]">{label}</span>}
        {sublabel && <span className="mt-0.5 text-[11px]" style={{ color }}>{sublabel}</span>}
      </div>
    </div>
  );
}
