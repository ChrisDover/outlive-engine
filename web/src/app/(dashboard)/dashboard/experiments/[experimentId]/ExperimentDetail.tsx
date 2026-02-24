"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { OutliveButton } from "@/components/ui/OutliveButton";

const inputClass =
  "w-full p-2 bg-[var(--surface-secondary)] border border-[var(--surface-elevated)] rounded-[var(--radius-sm)] text-foreground";

interface Snapshot {
  id?: string;
  date: string;
  notes: string;
  measurements?: Record<string, any>;
}

interface Experiment {
  id: string;
  title: string;
  hypothesis: string;
  status: "active" | "completed" | "abandoned";
  start_date: string;
  end_date?: string;
  metrics?: Record<string, any>;
  snapshots?: Snapshot[];
  created_at: string;
  updated_at: string;
}

interface ExperimentDetailProps {
  experiment: Experiment;
}

interface MeasurementEntry {
  key: string;
  value: string;
}

const statusBadgeStyles: Record<string, string> = {
  active: "bg-recovery-green text-white",
  completed: "bg-training text-white",
  abandoned: "bg-[var(--surface-elevated)] text-muted",
};

export function ExperimentDetail({ experiment: initial }: ExperimentDetailProps) {
  const [experiment, setExperiment] = useState<Experiment>(initial);
  const [updatingStatus, setUpdatingStatus] = useState(false);
  const [showSnapshotForm, setShowSnapshotForm] = useState(false);
  const [snapshotDate, setSnapshotDate] = useState("");
  const [snapshotNotes, setSnapshotNotes] = useState("");
  const [measurements, setMeasurements] = useState<MeasurementEntry[]>([{ key: "", value: "" }]);
  const [savingSnapshot, setSavingSnapshot] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const router = useRouter();

  async function handleStatusChange(newStatus: string) {
    setUpdatingStatus(true);
    setError(null);

    try {
      const res = await fetch(`/api/backend/experiments/${experiment.id}`, {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ status: newStatus }),
      });

      if (!res.ok) throw new Error("Failed to update status");

      const updated = await res.json();
      setExperiment(updated);
    } catch {
      setError("Failed to update status. Please try again.");
    } finally {
      setUpdatingStatus(false);
    }
  }

  function addMeasurement() {
    setMeasurements((prev) => [...prev, { key: "", value: "" }]);
  }

  function removeMeasurement(index: number) {
    setMeasurements((prev) => prev.filter((_, i) => i !== index));
  }

  function updateMeasurement(index: number, field: "key" | "value", val: string) {
    setMeasurements((prev) =>
      prev.map((m, i) => (i === index ? { ...m, [field]: val } : m))
    );
  }

  async function handleAddSnapshot(e: React.FormEvent) {
    e.preventDefault();
    if (!snapshotDate) return;

    setSavingSnapshot(true);
    setError(null);

    try {
      const measurementsObj: Record<string, string> = {};
      for (const m of measurements) {
        if (m.key.trim()) {
          measurementsObj[m.key.trim()] = m.value.trim();
        }
      }

      const res = await fetch(`/api/backend/experiments/${experiment.id}/snapshots`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          date: snapshotDate,
          notes: snapshotNotes.trim(),
          measurements: measurementsObj,
        }),
      });

      if (!res.ok) throw new Error("Failed to add snapshot");

      const updatedExperiment = await res.json();
      setExperiment(updatedExperiment);

      // Reset form
      setSnapshotDate("");
      setSnapshotNotes("");
      setMeasurements([{ key: "", value: "" }]);
      setShowSnapshotForm(false);
    } catch {
      setError("Failed to add snapshot. Please try again.");
    } finally {
      setSavingSnapshot(false);
    }
  }

  const snapshots = experiment.snapshots ?? [];
  const sortedSnapshots = [...snapshots].sort(
    (a, b) => new Date(b.date).getTime() - new Date(a.date).getTime()
  );

  return (
    <div className="space-y-[var(--space-lg)]">
      {/* Back link */}
      <Link
        href="/dashboard/experiments"
        className="text-sm text-training hover:underline inline-flex items-center gap-1"
      >
        <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
        </svg>
        Back to Experiments
      </Link>

      {/* Header */}
      <div className="bg-card rounded-[var(--radius-md)] border border-[var(--surface-elevated)] p-[var(--space-md)]">
        <div className="flex items-start justify-between">
          <div className="space-y-[var(--space-xs)]">
            <div className="flex items-center gap-[var(--space-sm)]">
              <h1 className="text-2xl font-bold text-foreground">{experiment.title}</h1>
              <span
                className={`px-2 py-0.5 rounded-full text-xs font-medium ${statusBadgeStyles[experiment.status] ?? ""}`}
              >
                {experiment.status.charAt(0).toUpperCase() + experiment.status.slice(1)}
              </span>
            </div>

            {experiment.hypothesis && (
              <p className="text-muted">{experiment.hypothesis}</p>
            )}

            <div className="flex items-center gap-[var(--space-sm)] text-sm text-muted">
              <span>
                {new Date(experiment.start_date).toLocaleDateString("en-US", {
                  month: "short",
                  day: "numeric",
                  year: "numeric",
                })}
                {experiment.end_date && (
                  <>
                    {" — "}
                    {new Date(experiment.end_date).toLocaleDateString("en-US", {
                      month: "short",
                      day: "numeric",
                      year: "numeric",
                    })}
                  </>
                )}
              </span>
            </div>

            {experiment.metrics && Object.keys(experiment.metrics).length > 0 && (
              <div className="flex flex-wrap gap-[var(--space-xs)] mt-[var(--space-xs)]">
                {Object.entries(experiment.metrics).map(([key, value]) => (
                  <span
                    key={key}
                    className="px-2 py-0.5 bg-[var(--surface-secondary)] rounded-full text-xs text-muted"
                  >
                    {key}: {String(value)}
                  </span>
                ))}
              </div>
            )}
          </div>

          {/* Status update */}
          {experiment.status === "active" && (
            <div className="flex gap-[var(--space-xs)]">
              <OutliveButton
                variant="primary"
                onClick={() => handleStatusChange("completed")}
                loading={updatingStatus}
                className="text-sm px-[var(--space-sm)] py-1"
              >
                Complete
              </OutliveButton>
              <OutliveButton
                variant="secondary"
                onClick={() => handleStatusChange("abandoned")}
                loading={updatingStatus}
                className="text-sm px-[var(--space-sm)] py-1"
              >
                Abandon
              </OutliveButton>
            </div>
          )}
        </div>
      </div>

      {error && <p className="text-sm text-recovery-red">{error}</p>}

      {/* Snapshots */}
      <div>
        <div className="flex items-center justify-between mb-[var(--space-md)]">
          <h2 className="text-lg font-semibold text-foreground">
            Snapshots ({snapshots.length})
          </h2>
          {!showSnapshotForm && (
            <OutliveButton onClick={() => setShowSnapshotForm(true)} className="text-sm">
              Add Snapshot
            </OutliveButton>
          )}
        </div>

        {/* Add snapshot form */}
        {showSnapshotForm && (
          <form
            onSubmit={handleAddSnapshot}
            className="bg-card rounded-[var(--radius-md)] border border-[var(--surface-elevated)] p-[var(--space-md)] mb-[var(--space-md)] space-y-[var(--space-md)]"
          >
            <h3 className="font-semibold text-foreground">New Snapshot</h3>

            <div>
              <label className="block text-sm font-medium text-foreground mb-1">Date</label>
              <input
                type="date"
                value={snapshotDate}
                onChange={(e) => setSnapshotDate(e.target.value)}
                className={inputClass}
                required
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-foreground mb-1">Notes</label>
              <textarea
                value={snapshotNotes}
                onChange={(e) => setSnapshotNotes(e.target.value)}
                placeholder="How are things going? Any observations?"
                rows={3}
                className={inputClass}
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-foreground mb-1">
                Measurements
              </label>
              <div className="space-y-[var(--space-xs)]">
                {measurements.map((m, i) => (
                  <div key={i} className="flex gap-[var(--space-xs)] items-center">
                    <input
                      type="text"
                      value={m.key}
                      onChange={(e) => updateMeasurement(i, "key", e.target.value)}
                      placeholder="Metric name"
                      className={inputClass}
                    />
                    <input
                      type="text"
                      value={m.value}
                      onChange={(e) => updateMeasurement(i, "value", e.target.value)}
                      placeholder="Value"
                      className={inputClass}
                    />
                    {measurements.length > 1 && (
                      <button
                        type="button"
                        onClick={() => removeMeasurement(i)}
                        className="text-muted hover:text-recovery-red transition-colors shrink-0 p-1"
                      >
                        <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                        </svg>
                      </button>
                    )}
                  </div>
                ))}
              </div>
              <button
                type="button"
                onClick={addMeasurement}
                className="mt-[var(--space-xs)] text-sm text-training hover:underline"
              >
                + Add measurement
              </button>
            </div>

            <div className="flex gap-[var(--space-sm)]">
              <OutliveButton type="submit" loading={savingSnapshot}>
                Save Snapshot
              </OutliveButton>
              <OutliveButton variant="secondary" onClick={() => setShowSnapshotForm(false)}>
                Cancel
              </OutliveButton>
            </div>
          </form>
        )}

        {/* Snapshot timeline */}
        {sortedSnapshots.length === 0 ? (
          <div className="bg-card rounded-[var(--radius-md)] border border-[var(--surface-elevated)] p-[var(--space-md)]">
            <p className="text-sm text-muted text-center">
              No snapshots yet. Add one to start tracking progress.
            </p>
          </div>
        ) : (
          <div className="space-y-[var(--space-sm)]">
            {sortedSnapshots.map((snapshot, i) => (
              <div
                key={snapshot.id ?? i}
                className="bg-card rounded-[var(--radius-md)] border border-[var(--surface-elevated)] p-[var(--space-md)]"
              >
                <div className="flex items-center gap-[var(--space-sm)] mb-[var(--space-xs)]">
                  <div className="w-2 h-2 rounded-full bg-training shrink-0" />
                  <span className="text-sm font-medium text-foreground">
                    {new Date(snapshot.date).toLocaleDateString("en-US", {
                      weekday: "short",
                      month: "short",
                      day: "numeric",
                      year: "numeric",
                    })}
                  </span>
                </div>

                {snapshot.notes && (
                  <p className="text-sm text-muted ml-[var(--space-md)] mb-[var(--space-xs)]">
                    {snapshot.notes}
                  </p>
                )}

                {snapshot.measurements && Object.keys(snapshot.measurements).length > 0 && (
                  <div className="ml-[var(--space-md)] flex flex-wrap gap-[var(--space-xs)]">
                    {Object.entries(snapshot.measurements).map(([key, value]) => (
                      <span
                        key={key}
                        className="px-2 py-0.5 bg-[var(--surface-secondary)] rounded-full text-xs text-muted"
                      >
                        {key}: {String(value)}
                      </span>
                    ))}
                  </div>
                )}
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
