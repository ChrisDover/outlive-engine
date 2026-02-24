"use client";

import { useState, useRef } from "react";
import { OutliveButton } from "@/components/ui/OutliveButton";

interface GenomeUploadProps {
  onUploadComplete?: () => void;
}

export function GenomeUpload({ onUploadComplete }: GenomeUploadProps) {
  const [file, setFile] = useState<File | null>(null);
  const [uploading, setUploading] = useState(false);
  const [progress, setProgress] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<{ variantCount: number } | null>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);

  async function handleUpload() {
    if (!file) return;

    setUploading(true);
    setError(null);
    setProgress("Uploading file...");

    try {
      const formData = new FormData();
      formData.append("file", file);
      formData.append("source", "23andme");

      const response = await fetch("/api/backend/genomics/upload", {
        method: "POST",
        body: formData,
      });

      if (!response.ok) {
        const errorData = await response.json().catch(() => ({}));
        throw new Error(errorData.error || "Upload failed");
      }

      const result = await response.json();

      setSuccess({
        variantCount: result.variant_count,
      });
      setFile(null);
      if (fileInputRef.current) {
        fileInputRef.current.value = "";
      }
      setProgress(null);
      onUploadComplete?.();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Upload failed");
      setProgress(null);
    } finally {
      setUploading(false);
    }
  }

  function handleFileSelect(e: React.ChangeEvent<HTMLInputElement>) {
    const selected = e.target.files?.[0];
    if (!selected) return;

    // Validate file type
    if (!selected.name.endsWith(".txt") && !selected.name.endsWith(".csv")) {
      setError("Please select a .txt or .csv file from 23andMe");
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
      <h3 className="text-lg font-semibold text-foreground mb-2">
        Upload 23andMe Data
      </h3>
      <p className="text-sm text-muted mb-[var(--space-md)]">
        Upload your raw genome data file from 23andMe to automatically analyze
        health-related genetic variants.
      </p>

      <div className="space-y-[var(--space-md)]">
        <div>
          <label className="block text-sm font-medium text-foreground mb-1">
            Select File
          </label>
          <input
            ref={fileInputRef}
            type="file"
            accept=".txt,.csv"
            onChange={handleFileSelect}
            disabled={uploading}
            className="block w-full text-sm text-muted
              file:mr-4 file:py-2 file:px-4
              file:rounded-[var(--radius-sm)] file:border-0
              file:text-sm file:font-medium
              file:bg-genomics/20 file:text-genomics
              hover:file:bg-genomics/30
              disabled:opacity-50"
          />
          <p className="mt-1 text-xs text-muted">
            Download your raw data from 23andMe: Settings &gt; 23andMe Data &gt;
            Download Raw Data
          </p>
        </div>

        {file && (
          <div className="p-[var(--space-sm)] bg-[var(--surface-secondary)] rounded-[var(--radius-sm)]">
            <p className="text-sm text-foreground">
              Selected: <span className="font-medium">{file.name}</span>
            </p>
            <p className="text-xs text-muted">
              {(file.size / 1024 / 1024).toFixed(2)} MB
            </p>
          </div>
        )}

        {progress && (
          <div className="p-[var(--space-sm)] bg-genomics/10 border border-genomics/30 rounded-[var(--radius-sm)]">
            <p className="text-sm text-genomics">{progress}</p>
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
              Successfully uploaded {success.variantCount.toLocaleString()}{" "}
              genetic variants. Your risk profiles have been updated.
            </p>
          </div>
        )}

        <OutliveButton
          onClick={handleUpload}
          disabled={!file || uploading}
          loading={uploading}
        >
          Upload & Analyze
        </OutliveButton>
      </div>
    </div>
  );
}
