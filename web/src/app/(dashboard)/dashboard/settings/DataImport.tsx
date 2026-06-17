"use client";

import { useRef, useState } from "react";

interface ImportResult {
  format: string;
  recordsParsed: number;
  days: number;
  wearableDays: number;
  bodyDays: number;
  truncated?: { wearable: number; body: number };
  errors?: string[];
}

const CSV_TEMPLATE =
  "date,hrv,rhr,sleep_score,recovery_score,sleep_hours,weight,body_fat_pct\n" +
  "2026-06-14,54,53,84,71,7.3,82.6,18.5\n" +
  "2026-06-15,58,52,86,76,7.6,82.4,18.3\n" +
  "2026-06-16,61,51,88,79,7.1,82.1,18.1\n";

export function DataImport() {
  const inputRef = useRef<HTMLInputElement>(null);
  const [fileName, setFileName] = useState<string | null>(null);
  const [uploading, setUploading] = useState(false);
  const [result, setResult] = useState<ImportResult | null>(null);
  const [error, setError] = useState<string | null>(null);

  function downloadTemplate() {
    const blob = new Blob([CSV_TEMPLATE], { type: "text/csv" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = "outlive-import-template.csv";
    a.click();
    URL.revokeObjectURL(url);
  }

  async function upload(file: File) {
    setUploading(true);
    setResult(null);
    setError(null);
    try {
      const form = new FormData();
      form.append("file", file);
      const res = await fetch("/api/wearables/import", { method: "POST", body: form });
      const json = await res.json();
      if (!res.ok) {
        setError(json.error || "Import failed");
      } else {
        setResult(json);
      }
    } catch {
      setError("Upload failed — the file may be too large (50MB limit). For big Apple Health exports, try a CSV instead.");
    } finally {
      setUploading(false);
    }
  }

  function onPick(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (file) {
      setFileName(file.name);
      upload(file);
    }
  }

  return (
    <div className="rounded-[var(--radius-lg)] border border-[var(--border)] bg-[var(--surface-card)] p-5">
      <div className="mb-1 flex items-center justify-between gap-3">
        <h2 className="font-semibold text-foreground">Import data</h2>
        <button
          onClick={downloadTemplate}
          className="rounded-[var(--radius-md)] border border-[var(--border)] px-2.5 py-1 text-xs font-medium text-[var(--text-secondary)] hover:border-[var(--border-strong)] hover:text-[var(--text-primary)]"
        >
          Download CSV template
        </button>
      </div>
      <p className="mb-4 text-sm text-muted">
        No device API needed — upload a file. Works with <strong className="text-[var(--text-secondary)]">Apple Health</strong> exports
        and CSVs from any source.
      </p>

      {/* Dropzone-style button */}
      <label
        className="flex cursor-pointer flex-col items-center justify-center gap-2 rounded-[var(--radius-md)] border border-dashed border-[var(--border-strong)] bg-[var(--surface-secondary)] px-4 py-8 text-center transition-colors hover:border-[var(--accent)]"
      >
        <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="var(--accent)" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round">
          <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4M17 8l-5-5-5 5M12 3v12" />
        </svg>
        <span className="text-sm font-medium text-[var(--text-primary)]">
          {uploading ? "Importing…" : fileName ? `Selected: ${fileName}` : "Choose a file to import"}
        </span>
        <span className="text-xs text-[var(--text-tertiary)]">CSV or Apple Health export.xml · up to 50MB</span>
        <input
          ref={inputRef}
          type="file"
          accept=".csv,.xml,text/csv,application/xml,text/xml"
          className="hidden"
          onChange={onPick}
          disabled={uploading}
        />
      </label>

      {/* Result */}
      {error && (
        <div className="mt-3 rounded-[var(--radius-md)] border border-[var(--recovery-red)] bg-[color-mix(in_srgb,var(--recovery-red)_8%,transparent)] p-3 text-sm text-[var(--recovery-red)]">
          {error}
        </div>
      )}
      {result && (
        <div className="mt-3 rounded-[var(--radius-md)] border border-[var(--border)] bg-[var(--surface-secondary)] p-3 text-sm">
          <p className="text-[var(--green)]">
            ✓ Imported {result.days} day{result.days !== 1 ? "s" : ""}
            {result.format === "apple_health" ? " from Apple Health" : ""} ({result.recordsParsed.toLocaleString()} records)
          </p>
          <p className="mt-1 text-xs text-muted">
            {result.wearableDays} day{result.wearableDays !== 1 ? "s" : ""} of wearable metrics ·{" "}
            {result.bodyDays} body-composition entr{result.bodyDays !== 1 ? "ies" : "y"}
          </p>
          {result.truncated && (result.truncated.wearable > 0 || result.truncated.body > 0) && (
            <p className="mt-1 text-xs text-[var(--amber)]">
              Kept the most recent days; {result.truncated.wearable + result.truncated.body} older row(s) were skipped.
            </p>
          )}
          {result.errors?.map((e, i) => (
            <p key={i} className="mt-1 text-xs text-[var(--amber)]">{e}</p>
          ))}
        </div>
      )}

      {/* Help */}
      <details className="mt-4 text-xs text-muted">
        <summary className="cursor-pointer text-[var(--text-secondary)]">How to export from Apple Health</summary>
        <ol className="mt-2 list-decimal space-y-1 pl-4">
          <li>Open the <strong>Health</strong> app → tap your profile photo (top right).</li>
          <li>Scroll down → <strong>Export All Health Data</strong> → confirm.</li>
          <li>Unzip the file and upload <code>export.xml</code> here.</li>
          <li>Large export? Use the CSV template instead (Apple exports can exceed 50MB).</li>
        </ol>
        <p className="mt-2">
          CSV columns (any subset, one row per day): <code>date, hrv, rhr, sleep_score, recovery_score, sleep_hours, weight, body_fat_pct</code>.
        </p>
      </details>
    </div>
  );
}
