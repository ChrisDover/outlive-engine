"use client";

import { useState, useEffect } from "react";
import { OutliveButton } from "@/components/ui/OutliveButton";

interface WhoopMetrics {
  recovery_score?: number;
  hrv_rmssd?: number;
  resting_heart_rate?: number;
  sleep_performance?: number;
  total_sleep_minutes?: number;
  strain_score?: number;
  calories_burned?: number;
}

export function DailyWhoopInput() {
  const [metrics, setMetrics] = useState<WhoopMetrics>({});
  const [saving, setSaving] = useState(false);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState(false);
  const [existingData, setExistingData] = useState(false);

  const today = new Date().toISOString().split("T")[0];

  useEffect(() => {
    loadTodayData();
  }, []);

  async function loadTodayData() {
    try {
      const response = await fetch("/api/backend/wearables/whoop/today");
      if (response.ok) {
        const data = await response.json();
        if (data?.metrics) {
          setMetrics(data.metrics);
          setExistingData(true);
        }
      }
    } catch {
      // No existing data, that's fine
    } finally {
      setLoading(false);
    }
  }

  async function handleSave() {
    // Filter out empty values
    const validMetrics: WhoopMetrics = {};
    Object.entries(metrics).forEach(([key, value]) => {
      if (value !== undefined && value !== null && value !== "") {
        validMetrics[key as keyof WhoopMetrics] = Number(value);
      }
    });

    if (Object.keys(validMetrics).length === 0) {
      setError("Please enter at least one metric");
      return;
    }

    setSaving(true);
    setError(null);
    setSuccess(false);

    try {
      const response = await fetch("/api/backend/wearables/batch", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          entries: [
            {
              date: today,
              source: "whoop",
              metrics: validMetrics,
            },
          ],
        }),
      });

      if (!response.ok) {
        throw new Error("Failed to save");
      }

      setSuccess(true);
      setExistingData(true);
      setTimeout(() => setSuccess(false), 3000);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Save failed");
    } finally {
      setSaving(false);
    }
  }

  function updateMetric(key: keyof WhoopMetrics, value: string) {
    setMetrics((prev) => ({
      ...prev,
      [key]: value === "" ? undefined : Number(value),
    }));
  }

  const inputClass =
    "w-full p-2 bg-[var(--surface-secondary)] border border-[var(--surface-elevated)] rounded-[var(--radius-sm)] text-foreground";

  if (loading) {
    return (
      <div className="bg-card rounded-[var(--radius-md)] border border-[var(--surface-elevated)] p-[var(--space-md)]">
        <div className="animate-pulse h-32 bg-[var(--surface-secondary)] rounded"></div>
      </div>
    );
  }

  return (
    <div className="bg-card rounded-[var(--radius-md)] border border-[var(--surface-elevated)] p-[var(--space-md)]">
      <div className="flex items-center justify-between mb-[var(--space-md)]">
        <div className="flex items-center gap-3">
          <div className="w-8 h-8 bg-recovery-green/20 rounded-full flex items-center justify-center">
            <span className="text-recovery-green font-bold text-sm">W</span>
          </div>
          <div>
            <h3 className="text-lg font-semibold text-foreground">
              Daily Whoop Entry
            </h3>
            <p className="text-sm text-muted">
              {existingData ? "Update today's metrics" : "Enter today's metrics"}
            </p>
          </div>
        </div>
        <span className="text-sm text-muted">{today}</span>
      </div>

      <div className="grid grid-cols-2 sm:grid-cols-3 gap-[var(--space-md)]">
        <div>
          <label className="block text-sm text-muted mb-1">
            Recovery Score (0-100)
          </label>
          <input
            type="number"
            min="0"
            max="100"
            value={metrics.recovery_score ?? ""}
            onChange={(e) => updateMetric("recovery_score", e.target.value)}
            placeholder="e.g., 72"
            className={inputClass}
          />
        </div>

        <div>
          <label className="block text-sm text-muted mb-1">HRV (ms)</label>
          <input
            type="number"
            min="0"
            step="0.1"
            value={metrics.hrv_rmssd ?? ""}
            onChange={(e) => updateMetric("hrv_rmssd", e.target.value)}
            placeholder="e.g., 45"
            className={inputClass}
          />
        </div>

        <div>
          <label className="block text-sm text-muted mb-1">
            Resting HR (bpm)
          </label>
          <input
            type="number"
            min="0"
            value={metrics.resting_heart_rate ?? ""}
            onChange={(e) => updateMetric("resting_heart_rate", e.target.value)}
            placeholder="e.g., 52"
            className={inputClass}
          />
        </div>

        <div>
          <label className="block text-sm text-muted mb-1">
            Sleep Performance (0-100)
          </label>
          <input
            type="number"
            min="0"
            max="100"
            value={metrics.sleep_performance ?? ""}
            onChange={(e) => updateMetric("sleep_performance", e.target.value)}
            placeholder="e.g., 85"
            className={inputClass}
          />
        </div>

        <div>
          <label className="block text-sm text-muted mb-1">
            Total Sleep (min)
          </label>
          <input
            type="number"
            min="0"
            value={metrics.total_sleep_minutes ?? ""}
            onChange={(e) => updateMetric("total_sleep_minutes", e.target.value)}
            placeholder="e.g., 420"
            className={inputClass}
          />
        </div>

        <div>
          <label className="block text-sm text-muted mb-1">
            Strain (0-21)
          </label>
          <input
            type="number"
            min="0"
            max="21"
            step="0.1"
            value={metrics.strain_score ?? ""}
            onChange={(e) => updateMetric("strain_score", e.target.value)}
            placeholder="e.g., 12.5"
            className={inputClass}
          />
        </div>
      </div>

      {error && (
        <div className="mt-[var(--space-md)] p-[var(--space-sm)] bg-recovery-red/10 border border-recovery-red/30 rounded-[var(--radius-sm)]">
          <p className="text-sm text-recovery-red">{error}</p>
        </div>
      )}

      {success && (
        <div className="mt-[var(--space-md)] p-[var(--space-sm)] bg-recovery-green/10 border border-recovery-green/30 rounded-[var(--radius-sm)]">
          <p className="text-sm text-recovery-green">Saved successfully!</p>
        </div>
      )}

      <div className="mt-[var(--space-md)]">
        <OutliveButton onClick={handleSave} loading={saving}>
          {existingData ? "Update" : "Save"} Today's Data
        </OutliveButton>
      </div>
    </div>
  );
}
