"use client";

import { useState, useRef } from "react";
import { OutliveButton } from "@/components/ui/OutliveButton";

interface WhoopImportProps {
  onImportComplete?: (count: number) => void;
}

export function WhoopImport({ onImportComplete }: WhoopImportProps) {
  const [file, setFile] = useState<File | null>(null);
  const [uploading, setUploading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<{ days: number } | null>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);

  async function handleUpload() {
    if (!file) return;

    setUploading(true);
    setError(null);
    setSuccess(null);

    try {
      const formData = new FormData();
      formData.append("file", file);

      const response = await fetch("/api/backend/wearables/whoop/import", {
        method: "POST",
        body: formData,
      });

      if (!response.ok) {
        const errorData = await response.json().catch(() => ({}));
        throw new Error(errorData.error || "Import failed");
      }

      const result = await response.json();
      const daysImported = Array.isArray(result) ? result.length : 0;

      setSuccess({ days: daysImported });
      setFile(null);
      if (fileInputRef.current) {
        fileInputRef.current.value = "";
      }
      onImportComplete?.(daysImported);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Import failed");
    } finally {
      setUploading(false);
    }
  }

  function handleFileSelect(e: React.ChangeEvent<HTMLInputElement>) {
    const selected = e.target.files?.[0];
    if (!selected) return;

    // Validate file type
    if (!selected.name.endsWith(".csv")) {
      setError("Please select a CSV file exported from Whoop");
      return;
    }

    // Validate file size (max 50MB)
    if (selected.size > 50 * 1024 * 1024) {
      setError("File is too large. Maximum size is 50MB.");
      return;
    }

    setFile(selected);
    setError(null);
    setSuccess(null);
  }

  return (
    <div className="bg-card rounded-[var(--radius-md)] border border-[var(--surface-elevated)] p-[var(--space-md)]">
      <div className="flex items-center gap-3 mb-2">
        <div className="w-8 h-8 bg-recovery-green/20 rounded-full flex items-center justify-center">
          <span className="text-recovery-green font-bold text-sm">W</span>
        </div>
        <h3 className="text-lg font-semibold text-foreground">
          Import Whoop Data
        </h3>
      </div>
      <p className="text-sm text-muted mb-[var(--space-md)]">
        Upload your exported Whoop CSV file to import recovery, sleep, and
        strain data.
      </p>

      <div className="space-y-[var(--space-md)]">
        <div>
          <label className="block text-sm font-medium text-foreground mb-1">
            Select CSV File
          </label>
          <input
            ref={fileInputRef}
            type="file"
            accept=".csv"
            onChange={handleFileSelect}
            disabled={uploading}
            className="block w-full text-sm text-muted
              file:mr-4 file:py-2 file:px-4
              file:rounded-[var(--radius-sm)] file:border-0
              file:text-sm file:font-medium
              file:bg-recovery-green/20 file:text-recovery-green
              hover:file:bg-recovery-green/30
              disabled:opacity-50"
          />
          <p className="mt-1 text-xs text-muted">
            Export from Whoop: App &gt; Profile &gt; Export My Data
          </p>
        </div>

        {file && (
          <div className="p-[var(--space-sm)] bg-[var(--surface-secondary)] rounded-[var(--radius-sm)]">
            <p className="text-sm text-foreground">
              Selected: <span className="font-medium">{file.name}</span>
            </p>
            <p className="text-xs text-muted">
              {(file.size / 1024).toFixed(1)} KB
            </p>
          </div>
        )}

        {error && (
          <div className="p-[var(--space-sm)] bg-recovery-red/10 border border-recovery-red/30 rounded-[var(--radius-sm)]">
            <p className="text-sm text-recovery-red">{error}</p>
          </div>
        )}

        {success && (
          <div className="p-[var(--space-sm)] bg-recovery-green/10 border border-recovery-green/30 rounded-[var(--radius-sm)]">
            <p className="text-sm text-recovery-green">
              Successfully imported {success.days} days of Whoop data.
            </p>
          </div>
        )}

        <OutliveButton
          onClick={handleUpload}
          disabled={!file || uploading}
          loading={uploading}
        >
          Import Data
        </OutliveButton>
      </div>
    </div>
  );
}
