"use client";

import { useState } from "react";
import { EmptyState } from "@/components/ui/EmptyState";
import { OutliveButton } from "@/components/ui/OutliveButton";

interface Entry {
  id: string;
  date: string;
  metrics: {
    weight?: number;
    body_fat_pct?: number;
    lean_mass?: number;
    waist?: number;
  };
  created_at: string;
}

const inputClass =
  "w-full p-2 bg-[var(--surface-secondary)] border border-[var(--surface-elevated)] rounded-[var(--radius-sm)] text-foreground";

function WeightChart({ entries }: { entries: Entry[] }) {
  const withWeight = entries
    .filter((e) => e.metrics.weight != null)
    .sort((a, b) => new Date(a.date).getTime() - new Date(b.date).getTime());

  if (withWeight.length === 0) {
    return (
      <div className="bg-card rounded-[var(--radius-md)] border border-[var(--surface-elevated)] p-[var(--space-lg)] flex items-center justify-center" style={{ height: 300 }}>
        <p className="text-muted">No weight data to chart</p>
      </div>
    );
  }

  const weights = withWeight.map((e) => e.metrics.weight!);
  const minW = Math.min(...weights);
  const maxW = Math.max(...weights);
  const rangeW = maxW - minW || 1;

  const padX = 60;
  const padY = 30;
  const padBottom = 50;
  const svgW = 700;
  const svgH = 300;
  const plotW = svgW - padX - 20;
  const plotH = svgH - padY - padBottom;

  const points = withWeight.map((e, i) => {
    const x = padX + (withWeight.length === 1 ? plotW / 2 : (i / (withWeight.length - 1)) * plotW);
    const y = padY + plotH - ((e.metrics.weight! - minW) / rangeW) * plotH;
    return { x, y, date: e.date, weight: e.metrics.weight! };
  });

  const polyline = points.map((p) => `${p.x},${p.y}`).join(" ");

  // Y-axis ticks
  const tickCount = 5;
  const yTicks = Array.from({ length: tickCount }, (_, i) => {
    const val = minW + (rangeW * i) / (tickCount - 1);
    const y = padY + plotH - ((val - minW) / rangeW) * plotH;
    return { val: Math.round(val * 10) / 10, y };
  });

  return (
    <div className="bg-card rounded-[var(--radius-md)] border border-[var(--surface-elevated)] p-[var(--space-md)] overflow-x-auto">
      <svg viewBox={`0 0 ${svgW} ${svgH}`} className="w-full" style={{ maxHeight: 300 }}>
        {/* Y axis line */}
        <line x1={padX} y1={padY} x2={padX} y2={padY + plotH} stroke="var(--surface-elevated)" strokeWidth="1" />
        {/* X axis line */}
        <line x1={padX} y1={padY + plotH} x2={padX + plotW} y2={padY + plotH} stroke="var(--surface-elevated)" strokeWidth="1" />

        {/* Y ticks */}
        {yTicks.map((t, i) => (
          <g key={i}>
            <line x1={padX - 4} y1={t.y} x2={padX} y2={t.y} stroke="var(--surface-elevated)" strokeWidth="1" />
            <text x={padX - 8} y={t.y + 4} textAnchor="end" fontSize="11" fill="var(--text-muted, #888)">
              {t.val}
            </text>
          </g>
        ))}

        {/* Grid lines */}
        {yTicks.map((t, i) => (
          <line key={`g${i}`} x1={padX} y1={t.y} x2={padX + plotW} y2={t.y} stroke="var(--surface-elevated)" strokeWidth="0.5" opacity="0.4" />
        ))}

        {/* Line */}
        <polyline points={polyline} fill="none" stroke="var(--training, #3b82f6)" strokeWidth="2" />

        {/* Data points */}
        {points.map((p, i) => (
          <circle key={i} cx={p.x} cy={p.y} r="4" fill="var(--training, #3b82f6)" />
        ))}

        {/* X labels */}
        {points.map((p, i) => {
          // Show max ~8 labels to avoid overlap
          if (points.length > 8 && i % Math.ceil(points.length / 8) !== 0 && i !== points.length - 1) return null;
          const label = new Date(p.date + "T00:00:00").toLocaleDateString("en-US", { month: "short", day: "numeric" });
          return (
            <text key={i} x={p.x} y={padY + plotH + 20} textAnchor="middle" fontSize="10" fill="var(--text-muted, #888)">
              {label}
            </text>
          );
        })}

        {/* Y axis label */}
        <text x="14" y={padY + plotH / 2} textAnchor="middle" fontSize="11" fill="var(--text-muted, #888)" transform={`rotate(-90, 14, ${padY + plotH / 2})`}>
          Weight (lbs)
        </text>
      </svg>
    </div>
  );
}

export function BodyCompContent({ entries: initialEntries }: { entries: Entry[] }) {
  const [entries, setEntries] = useState<Entry[]>(initialEntries);
  const [showForm, setShowForm] = useState(false);
  const [saving, setSaving] = useState(false);
  const [deletingId, setDeletingId] = useState<string | null>(null);

  // Form state
  const [date, setDate] = useState(new Date().toISOString().split("T")[0]);
  const [weight, setWeight] = useState("");
  const [bodyFat, setBodyFat] = useState("");
  const [leanMass, setLeanMass] = useState("");
  const [waist, setWaist] = useState("");

  const sorted = [...entries].sort((a, b) => new Date(b.date).getTime() - new Date(a.date).getTime());

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setSaving(true);

    const metrics: Record<string, number> = {};
    if (weight) metrics.weight = parseFloat(weight);
    if (bodyFat) metrics.body_fat_pct = parseFloat(bodyFat);
    if (leanMass) metrics.lean_mass = parseFloat(leanMass);
    if (waist) metrics.waist = parseFloat(waist);

    try {
      const res = await fetch("/api/backend/body-composition", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ date, metrics }),
      });

      if (!res.ok) throw new Error("Failed to save");

      const created = await res.json();
      setEntries((prev) => {
        // Upsert by date: replace existing entry for same date, or add new
        const existing = prev.findIndex((p) => p.date === created.date);
        if (existing >= 0) {
          const next = [...prev];
          next[existing] = created;
          return next;
        }
        return [...prev, created];
      });

      // Reset form
      setWeight("");
      setBodyFat("");
      setLeanMass("");
      setWaist("");
      setDate(new Date().toISOString().split("T")[0]);
      setShowForm(false);
    } catch (err) {
      alert(err instanceof Error ? err.message : "Failed to save entry");
    } finally {
      setSaving(false);
    }
  }

  async function handleDelete(id: string) {
    if (!confirm("Delete this entry?")) return;
    setDeletingId(id);

    try {
      const res = await fetch(`/api/backend/body-composition/${id}`, { method: "DELETE" });
      if (!res.ok) throw new Error("Failed to delete");
      setEntries((prev) => prev.filter((e) => e.id !== id));
    } catch (err) {
      alert(err instanceof Error ? err.message : "Failed to delete entry");
    } finally {
      setDeletingId(null);
    }
  }

  if (entries.length === 0 && !showForm) {
    return (
      <>
        <EmptyState
          title="No body composition data yet"
          description="Log weight, body fat, lean mass, and other measurements to track trends."
          actionLabel="Log Entry"
          onAction={() => setShowForm(true)}
        />
        {showForm && renderForm()}
      </>
    );
  }

  return (
    <div className="space-y-[var(--space-lg)]">
      {/* Actions */}
      <div className="flex justify-end">
        <OutliveButton onClick={() => setShowForm(!showForm)}>
          {showForm ? "Cancel" : "Log Entry"}
        </OutliveButton>
      </div>

      {/* Add entry form */}
      {showForm && renderForm()}

      {/* Weight chart */}
      <WeightChart entries={entries} />

      {/* Entry list */}
      <div className="space-y-[var(--space-sm)]">
        {sorted.map((entry) => (
          <div
            key={entry.id}
            className="bg-card rounded-[var(--radius-md)] border border-[var(--surface-elevated)] p-[var(--space-md)] flex items-center justify-between"
          >
            <div className="flex flex-wrap gap-x-[var(--space-lg)] gap-y-[var(--space-xs)]">
              <span className="font-medium text-foreground">
                {new Date(entry.date + "T00:00:00").toLocaleDateString("en-US", {
                  month: "long",
                  day: "numeric",
                  year: "numeric",
                })}
              </span>
              {entry.metrics.weight != null && (
                <span className="text-muted">{entry.metrics.weight} lbs</span>
              )}
              {entry.metrics.body_fat_pct != null && (
                <span className="text-muted">{entry.metrics.body_fat_pct}% BF</span>
              )}
              {entry.metrics.lean_mass != null && (
                <span className="text-muted">{entry.metrics.lean_mass} lbs lean</span>
              )}
              {entry.metrics.waist != null && (
                <span className="text-muted">{entry.metrics.waist} in waist</span>
              )}
            </div>
            <OutliveButton
              variant="destructive"
              loading={deletingId === entry.id}
              onClick={() => handleDelete(entry.id)}
              className="ml-[var(--space-md)] text-sm px-[var(--space-sm)] py-1"
            >
              Delete
            </OutliveButton>
          </div>
        ))}
      </div>
    </div>
  );

  function renderForm() {
    return (
      <form
        onSubmit={handleSubmit}
        className="bg-card rounded-[var(--radius-md)] border border-[var(--surface-elevated)] p-[var(--space-lg)] space-y-[var(--space-md)]"
      >
        <h2 className="text-lg font-medium text-foreground">Log Entry</h2>

        <div>
          <label className="block text-sm text-muted mb-1">Date *</label>
          <input
            type="date"
            required
            value={date}
            onChange={(e) => setDate(e.target.value)}
            className={inputClass}
          />
        </div>

        <div className="grid grid-cols-2 gap-[var(--space-md)]">
          <div>
            <label className="block text-sm text-muted mb-1">Weight (lbs)</label>
            <input
              type="number"
              step="0.1"
              value={weight}
              onChange={(e) => setWeight(e.target.value)}
              placeholder="e.g. 175"
              className={inputClass}
            />
          </div>
          <div>
            <label className="block text-sm text-muted mb-1">Body Fat (%)</label>
            <input
              type="number"
              step="0.1"
              value={bodyFat}
              onChange={(e) => setBodyFat(e.target.value)}
              placeholder="e.g. 15.2"
              className={inputClass}
            />
          </div>
          <div>
            <label className="block text-sm text-muted mb-1">Lean Mass (lbs)</label>
            <input
              type="number"
              step="0.1"
              value={leanMass}
              onChange={(e) => setLeanMass(e.target.value)}
              placeholder="e.g. 148"
              className={inputClass}
            />
          </div>
          <div>
            <label className="block text-sm text-muted mb-1">Waist (in)</label>
            <input
              type="number"
              step="0.1"
              value={waist}
              onChange={(e) => setWaist(e.target.value)}
              placeholder="e.g. 32"
              className={inputClass}
            />
          </div>
        </div>

        <div className="flex gap-[var(--space-sm)]">
          <OutliveButton type="submit" loading={saving}>
            Save
          </OutliveButton>
          <OutliveButton variant="secondary" onClick={() => setShowForm(false)}>
            Cancel
          </OutliveButton>
        </div>
      </form>
    );
  }
}
