"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { OutliveButton } from "@/components/ui/OutliveButton";

const inputClass =
  "w-full p-2 bg-[var(--surface-secondary)] border border-[var(--surface-elevated)] rounded-[var(--radius-sm)] text-foreground";

interface MetricEntry {
  key: string;
  value: string;
}

export function NewExperimentForm() {
  const router = useRouter();
  const [title, setTitle] = useState("");
  const [hypothesis, setHypothesis] = useState("");
  const [startDate, setStartDate] = useState("");
  const [endDate, setEndDate] = useState("");
  const [metrics, setMetrics] = useState<MetricEntry[]>([{ key: "", value: "" }]);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  function addMetric() {
    setMetrics((prev) => [...prev, { key: "", value: "" }]);
  }

  function removeMetric(index: number) {
    setMetrics((prev) => prev.filter((_, i) => i !== index));
  }

  function updateMetric(index: number, field: "key" | "value", val: string) {
    setMetrics((prev) =>
      prev.map((m, i) => (i === index ? { ...m, [field]: val } : m))
    );
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!title.trim() || !startDate) return;

    setSaving(true);
    setError(null);

    try {
      const metricsObj: Record<string, string> = {};
      for (const m of metrics) {
        if (m.key.trim()) {
          metricsObj[m.key.trim()] = m.value.trim();
        }
      }

      const body: Record<string, any> = {
        title: title.trim(),
        hypothesis: hypothesis.trim(),
        start_date: startDate,
        metrics: metricsObj,
      };

      if (endDate) {
        body.end_date = endDate;
      }

      const res = await fetch("/api/backend/experiments", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
      });

      if (!res.ok) throw new Error("Failed to create experiment");

      router.push("/dashboard/experiments");
    } catch {
      setError("Failed to create experiment. Please try again.");
    } finally {
      setSaving(false);
    }
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-[var(--space-md)]">
      <div>
        <label className="block text-sm font-medium text-foreground mb-1">Title</label>
        <input
          type="text"
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          placeholder="e.g. Creatine 5g/day for Cognitive Function"
          className={inputClass}
          required
        />
      </div>

      <div>
        <label className="block text-sm font-medium text-foreground mb-1">Hypothesis</label>
        <textarea
          value={hypothesis}
          onChange={(e) => setHypothesis(e.target.value)}
          placeholder="What do you expect to happen and why?"
          rows={3}
          className={inputClass}
        />
      </div>

      <div className="grid grid-cols-2 gap-[var(--space-md)]">
        <div>
          <label className="block text-sm font-medium text-foreground mb-1">Start Date</label>
          <input
            type="date"
            value={startDate}
            onChange={(e) => setStartDate(e.target.value)}
            className={inputClass}
            required
          />
        </div>
        <div>
          <label className="block text-sm font-medium text-foreground mb-1">
            End Date <span className="text-muted font-normal">(optional)</span>
          </label>
          <input
            type="date"
            value={endDate}
            onChange={(e) => setEndDate(e.target.value)}
            className={inputClass}
          />
        </div>
      </div>

      <div>
        <label className="block text-sm font-medium text-foreground mb-1">
          Metrics to Track
        </label>
        <div className="space-y-[var(--space-xs)]">
          {metrics.map((metric, i) => (
            <div key={i} className="flex gap-[var(--space-xs)] items-center">
              <input
                type="text"
                value={metric.key}
                onChange={(e) => updateMetric(i, "key", e.target.value)}
                placeholder="Metric name"
                className={inputClass}
              />
              <input
                type="text"
                value={metric.value}
                onChange={(e) => updateMetric(i, "value", e.target.value)}
                placeholder="Target / unit"
                className={inputClass}
              />
              {metrics.length > 1 && (
                <button
                  type="button"
                  onClick={() => removeMetric(i)}
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
          onClick={addMetric}
          className="mt-[var(--space-xs)] text-sm text-training hover:underline"
        >
          + Add metric
        </button>
      </div>

      {error && <p className="text-sm text-recovery-red">{error}</p>}

      <div className="flex gap-[var(--space-sm)]">
        <OutliveButton type="submit" loading={saving}>
          Create Experiment
        </OutliveButton>
        <OutliveButton variant="secondary" onClick={() => router.push("/dashboard/experiments")}>
          Cancel
        </OutliveButton>
      </div>
    </form>
  );
}
