"use client";

import { useState } from "react";
import { OutliveButton } from "@/components/ui/OutliveButton";

interface Risk {
  id?: string;
  risk_category: string;
  risk_level: "elevated" | "moderate" | "normal" | "reduced";
  summary: string;
  metadata?: Record<string, any>;
}

interface GenomicsFormProps {
  existing?: Risk;
  onSave: (risk: Risk) => void;
  onCancel: () => void;
}

const inputClass =
  "w-full p-2 bg-[var(--surface-secondary)] border border-[var(--surface-elevated)] rounded-[var(--radius-sm)] text-foreground";

export function GenomicsForm({ existing, onSave, onCancel }: GenomicsFormProps) {
  const [riskCategory, setRiskCategory] = useState(existing?.risk_category ?? "");
  const [riskLevel, setRiskLevel] = useState<Risk["risk_level"]>(existing?.risk_level ?? "normal");
  const [summary, setSummary] = useState(existing?.summary ?? "");
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!riskCategory.trim()) return;

    setSaving(true);
    setError(null);
    setSuccess(false);

    try {
      const res = await fetch("/api/backend/genomics/risks", {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          risks: [
            {
              risk_category: riskCategory.trim(),
              risk_level: riskLevel,
              summary: summary.trim(),
              metadata: existing?.metadata ?? {},
            },
          ],
        }),
      });

      if (!res.ok) throw new Error("Failed to save risk");

      const updated = await res.json();
      setSuccess(true);

      // Find the matching risk from the response
      const savedRisk =
        Array.isArray(updated)
          ? updated.find((r: Risk) => r.risk_category === riskCategory.trim()) ?? updated[0]
          : updated;

      setTimeout(() => onSave(savedRisk), 500);
    } catch {
      setError("Failed to save. Please try again.");
    } finally {
      setSaving(false);
    }
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-[var(--space-md)] mt-[var(--space-md)]">
      <div>
        <label className="block text-sm font-medium text-foreground mb-1">Risk Category</label>
        <input
          type="text"
          value={riskCategory}
          onChange={(e) => setRiskCategory(e.target.value)}
          placeholder="e.g. APOE4 – Alzheimer's"
          className={inputClass}
          required
          disabled={!!existing}
        />
      </div>

      <div>
        <label className="block text-sm font-medium text-foreground mb-1">Risk Level</label>
        <select
          value={riskLevel}
          onChange={(e) => setRiskLevel(e.target.value as Risk["risk_level"])}
          className={inputClass}
        >
          <option value="elevated">Elevated</option>
          <option value="moderate">Moderate</option>
          <option value="normal">Normal</option>
          <option value="reduced">Reduced</option>
        </select>
      </div>

      <div>
        <label className="block text-sm font-medium text-foreground mb-1">Summary</label>
        <textarea
          value={summary}
          onChange={(e) => setSummary(e.target.value)}
          placeholder="Describe the risk, implications, and any recommended actions..."
          rows={3}
          className={inputClass}
        />
      </div>

      {error && <p className="text-sm text-recovery-red">{error}</p>}
      {success && <p className="text-sm text-recovery-green">Saved successfully.</p>}

      <div className="flex gap-[var(--space-sm)]">
        <OutliveButton type="submit" loading={saving}>
          {existing ? "Update Risk" : "Add Risk"}
        </OutliveButton>
        <OutliveButton variant="secondary" onClick={onCancel}>
          Cancel
        </OutliveButton>
      </div>
    </form>
  );
}
