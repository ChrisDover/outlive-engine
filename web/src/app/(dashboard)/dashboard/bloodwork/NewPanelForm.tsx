"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { OutliveButton } from "@/components/ui/OutliveButton";
import { BloodworkOCR } from "./BloodworkOCR";

interface MarkerRow {
  name: string;
  value: string;
  unit: string;
  reference_low: string;
  reference_high: string;
}

interface ExtractedMarker {
  name: string;
  value: number;
  unit: string;
  reference_low: number | null;
  reference_high: number | null;
  flag: string | null;
}

const PRESETS: { label: string; name: string; unit: string; ref_low: number; ref_high: number }[] = [
  { label: "Testosterone Total", name: "Testosterone Total", unit: "ng/dL", ref_low: 264, ref_high: 916 },
  { label: "Glucose", name: "Glucose", unit: "mg/dL", ref_low: 65, ref_high: 99 },
  { label: "HbA1c", name: "HbA1c", unit: "%", ref_low: 4.0, ref_high: 5.6 },
  { label: "LDL", name: "LDL", unit: "mg/dL", ref_low: 0, ref_high: 99 },
  { label: "HDL", name: "HDL", unit: "mg/dL", ref_low: 40, ref_high: 200 },
  { label: "Triglycerides", name: "Triglycerides", unit: "mg/dL", ref_low: 0, ref_high: 149 },
  { label: "TSH", name: "TSH", unit: "mIU/L", ref_low: 0.4, ref_high: 4.0 },
  { label: "Vitamin D", name: "Vitamin D", unit: "ng/mL", ref_low: 30, ref_high: 100 },
  { label: "CRP", name: "CRP", unit: "mg/L", ref_low: 0, ref_high: 3.0 },
  { label: "ApoB", name: "ApoB", unit: "mg/dL", ref_low: 0, ref_high: 90 },
];

function emptyMarker(): MarkerRow {
  return { name: "", value: "", unit: "", reference_low: "", reference_high: "" };
}

export function NewPanelForm() {
  const router = useRouter();
  const [panelDate, setPanelDate] = useState("");
  const [labName, setLabName] = useState("");
  const [notes, setNotes] = useState("");
  const [markers, setMarkers] = useState<MarkerRow[]>([emptyMarker()]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  function handleExtractedMarkers(extracted: ExtractedMarker[]) {
    const newMarkers: MarkerRow[] = extracted.map((m) => ({
      name: m.name,
      value: String(m.value),
      unit: m.unit,
      reference_low: m.reference_low !== null ? String(m.reference_low) : "",
      reference_high: m.reference_high !== null ? String(m.reference_high) : "",
    }));
    // Add extracted markers to existing ones (filter out empty ones first)
    const existingNonEmpty = markers.filter((m) => m.name || m.value);
    setMarkers([...existingNonEmpty, ...newMarkers]);
  }

  function addMarker() {
    setMarkers((prev) => [...prev, emptyMarker()]);
  }

  function addPreset(preset: (typeof PRESETS)[number]) {
    setMarkers((prev) => [
      ...prev,
      {
        name: preset.name,
        value: "",
        unit: preset.unit,
        reference_low: String(preset.ref_low),
        reference_high: String(preset.ref_high),
      },
    ]);
  }

  function removeMarker(index: number) {
    setMarkers((prev) => prev.filter((_, i) => i !== index));
  }

  function updateMarker(index: number, field: keyof MarkerRow, value: string) {
    setMarkers((prev) =>
      prev.map((m, i) => (i === index ? { ...m, [field]: value } : m))
    );
  }

  function computeFlag(value: string, refLow: string, refHigh: string): string | null {
    const v = parseFloat(value);
    const low = parseFloat(refLow);
    const high = parseFloat(refHigh);
    if (isNaN(v)) return null;
    if (!isNaN(high) && v > high) return "H";
    if (!isNaN(low) && v < low) return "L";
    return null;
  }

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError("");

    if (!panelDate) {
      setError("Panel date is required.");
      return;
    }

    const validMarkers = markers.filter((m) => m.name && m.value);
    if (validMarkers.length === 0) {
      setError("Add at least one marker with a name and value.");
      return;
    }

    setLoading(true);

    try {
      const body = {
        panel_date: panelDate,
        lab_name: labName || null,
        notes: notes || null,
        markers: validMarkers.map((m) => ({
          name: m.name,
          value: parseFloat(m.value),
          unit: m.unit,
          reference_low: m.reference_low ? parseFloat(m.reference_low) : null,
          reference_high: m.reference_high ? parseFloat(m.reference_high) : null,
          flag: computeFlag(m.value, m.reference_low, m.reference_high),
        })),
      };

      const res = await fetch("/api/backend/bloodwork", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
      });

      if (!res.ok) throw new Error("Failed to create panel");

      router.push("/dashboard/bloodwork");
    } catch {
      setError("Failed to save panel. Please try again.");
    } finally {
      setLoading(false);
    }
  }

  const inputClass =
    "w-full p-2 bg-[var(--surface-secondary)] border border-[var(--surface-elevated)] rounded-[var(--radius-sm)] text-foreground";

  return (
    <form onSubmit={handleSubmit} className="space-y-[var(--space-lg)]">
      {error && (
        <div className="p-[var(--space-sm)] bg-recovery-red/10 border border-recovery-red/30 rounded-[var(--radius-sm)] text-recovery-red text-sm">
          {error}
        </div>
      )}

      {/* OCR Upload */}
      <BloodworkOCR onMarkersExtracted={handleExtractedMarkers} />

      {/* Panel info */}
      <div className="bg-card rounded-[var(--radius-md)] border border-[var(--surface-elevated)] p-[var(--space-md)] space-y-[var(--space-md)]">
        <h2 className="text-lg font-semibold text-foreground">Panel Info</h2>
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-[var(--space-md)]">
          <div>
            <label className="block text-sm text-muted mb-1">
              Panel Date <span className="text-recovery-red">*</span>
            </label>
            <input
              type="date"
              value={panelDate}
              onChange={(e) => setPanelDate(e.target.value)}
              className={inputClass}
              required
            />
          </div>
          <div>
            <label className="block text-sm text-muted mb-1">Lab Name</label>
            <input
              type="text"
              value={labName}
              onChange={(e) => setLabName(e.target.value)}
              placeholder="e.g., Quest Diagnostics"
              className={inputClass}
            />
          </div>
        </div>
        <div>
          <label className="block text-sm text-muted mb-1">Notes</label>
          <textarea
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
            rows={2}
            placeholder="Optional notes about this panel..."
            className={inputClass}
          />
        </div>
      </div>

      {/* Quick-add presets */}
      <div className="bg-card rounded-[var(--radius-md)] border border-[var(--surface-elevated)] p-[var(--space-md)] space-y-[var(--space-sm)]">
        <h2 className="text-lg font-semibold text-foreground">Quick Add</h2>
        <p className="text-sm text-muted">Click a marker to add it with pre-filled reference ranges.</p>
        <div className="flex flex-wrap gap-2">
          {PRESETS.map((preset) => (
            <button
              key={preset.name}
              type="button"
              onClick={() => addPreset(preset)}
              className="px-3 py-1.5 text-sm bg-bloodwork/10 text-bloodwork border border-bloodwork/20 rounded-full hover:bg-bloodwork/20 transition-colors"
            >
              {preset.label}
            </button>
          ))}
        </div>
      </div>

      {/* Markers */}
      <div className="bg-card rounded-[var(--radius-md)] border border-[var(--surface-elevated)] p-[var(--space-md)] space-y-[var(--space-md)]">
        <div className="flex items-center justify-between">
          <h2 className="text-lg font-semibold text-foreground">Markers</h2>
          <OutliveButton variant="secondary" onClick={addMarker} className="text-sm">
            + Add Marker
          </OutliveButton>
        </div>

        {markers.map((marker, i) => (
          <div
            key={i}
            className="border border-[var(--surface-elevated)] rounded-[var(--radius-sm)] p-[var(--space-sm)] space-y-[var(--space-sm)]"
          >
            <div className="flex items-center justify-between">
              <span className="text-sm font-medium text-muted">
                Marker {i + 1}
              </span>
              {markers.length > 1 && (
                <button
                  type="button"
                  onClick={() => removeMarker(i)}
                  className="text-muted hover:text-recovery-red transition-colors text-lg leading-none"
                  aria-label="Remove marker"
                >
                  &times;
                </button>
              )}
            </div>
            <div className="grid grid-cols-2 sm:grid-cols-5 gap-[var(--space-xs)]">
              <div className="col-span-2 sm:col-span-1">
                <label className="block text-xs text-muted mb-0.5">Name</label>
                <input
                  type="text"
                  value={marker.name}
                  onChange={(e) => updateMarker(i, "name", e.target.value)}
                  placeholder="e.g., LDL"
                  className={inputClass}
                />
              </div>
              <div>
                <label className="block text-xs text-muted mb-0.5">Value</label>
                <input
                  type="number"
                  step="any"
                  value={marker.value}
                  onChange={(e) => updateMarker(i, "value", e.target.value)}
                  placeholder="0"
                  className={inputClass}
                />
              </div>
              <div>
                <label className="block text-xs text-muted mb-0.5">Unit</label>
                <input
                  type="text"
                  value={marker.unit}
                  onChange={(e) => updateMarker(i, "unit", e.target.value)}
                  placeholder="mg/dL"
                  className={inputClass}
                />
              </div>
              <div>
                <label className="block text-xs text-muted mb-0.5">Ref Low</label>
                <input
                  type="number"
                  step="any"
                  value={marker.reference_low}
                  onChange={(e) => updateMarker(i, "reference_low", e.target.value)}
                  placeholder="—"
                  className={inputClass}
                />
              </div>
              <div>
                <label className="block text-xs text-muted mb-0.5">Ref High</label>
                <input
                  type="number"
                  step="any"
                  value={marker.reference_high}
                  onChange={(e) => updateMarker(i, "reference_high", e.target.value)}
                  placeholder="—"
                  className={inputClass}
                />
              </div>
            </div>
            {/* Live flag preview */}
            {marker.value && (
              <div className="text-xs">
                {(() => {
                  const flag = computeFlag(marker.value, marker.reference_low, marker.reference_high);
                  if (flag === "H")
                    return <span className="text-recovery-red font-medium">Flag: High</span>;
                  if (flag === "L")
                    return <span className="text-training font-medium">Flag: Low</span>;
                  if (marker.reference_low || marker.reference_high)
                    return <span className="text-recovery-green font-medium">Flag: Normal</span>;
                  return null;
                })()}
              </div>
            )}
          </div>
        ))}
      </div>

      {/* Submit */}
      <div className="flex items-center gap-[var(--space-md)]">
        <OutliveButton type="submit" loading={loading}>
          Save Panel
        </OutliveButton>
        <OutliveButton
          variant="secondary"
          onClick={() => router.push("/dashboard/bloodwork")}
        >
          Cancel
        </OutliveButton>
      </div>
    </form>
  );
}
