"use client";

import { useState, useRef } from "react";
import { OutliveButton } from "@/components/ui/OutliveButton";

interface BloodworkMarker {
  name: string;
  value: number;
  unit: string;
  reference_low: number | null;
  reference_high: number | null;
  flag: string | null;
}

interface FileResult {
  filename: string;
  success: boolean;
  markers: BloodworkMarker[];
  raw_text: string | null;
  confidence: number | null;
  error: string | null;
  panel_id: string | null;
}

interface BulkOCRResponse {
  total_files: number;
  successful: number;
  failed: number;
  total_markers: number;
  results: FileResult[];
}

interface BloodworkOCRProps {
  onMarkersExtracted?: (markers: BloodworkMarker[]) => void;
  onPanelCreated?: () => void;
}

export function BloodworkOCR({ onMarkersExtracted, onPanelCreated }: BloodworkOCRProps) {
  const [files, setFiles] = useState<File[]>([]);
  const [previews, setPreviews] = useState<string[]>([]);
  const [processing, setProcessing] = useState(false);
  const [progress, setProgress] = useState<string>("");
  const [error, setError] = useState<string | null>(null);
  const [results, setResults] = useState<BulkOCRResponse | null>(null);
  const [expandedResults, setExpandedResults] = useState<Set<number>>(new Set());
  const [autoSave, setAutoSave] = useState(true);
  const [panelDate, setPanelDate] = useState<string>(new Date().toISOString().split("T")[0]);
  const [labName, setLabName] = useState<string>("");
  const fileInputRef = useRef<HTMLInputElement>(null);

  async function handleProcess() {
    if (files.length === 0) return;

    setProcessing(true);
    setError(null);
    setResults(null);
    setProgress(`Processing ${files.length} file(s)...`);

    try {
      const formData = new FormData();
      files.forEach((file) => {
        formData.append("files", file);
      });
      formData.append("auto_save", String(autoSave));
      formData.append("panel_date", panelDate);
      if (labName) {
        formData.append("lab_name", labName);
      }

      const response = await fetch("/api/backend/bloodwork/upload", {
        method: "POST",
        body: formData,
      });

      if (!response.ok) {
        const errorData = await response.json().catch(() => ({}));
        throw new Error(errorData.detail || "Upload failed");
      }

      const data: BulkOCRResponse = await response.json();
      setResults(data);

      // Collect all successfully extracted markers
      const allMarkers = data.results
        .filter((r) => r.success)
        .flatMap((r) => r.markers);

      if (allMarkers.length > 0) {
        onMarkersExtracted?.(allMarkers);
      }

      if (data.successful > 0 && autoSave) {
        onPanelCreated?.();
      }

      setProgress("");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Processing failed");
      setProgress("");
    } finally {
      setProcessing(false);
    }
  }

  function handleFileSelect(e: React.ChangeEvent<HTMLInputElement>) {
    const selected = Array.from(e.target.files || []);
    if (selected.length === 0) return;

    // Validate file types
    const validFiles: File[] = [];
    const newPreviews: string[] = [];

    for (const file of selected) {
      const isValid =
        file.type === "application/pdf" ||
        file.type.startsWith("image/") ||
        file.name.toLowerCase().endsWith(".pdf");

      if (!isValid) {
        setError(`Skipped ${file.name}: unsupported file type`);
        continue;
      }

      if (file.size > 50 * 1024 * 1024) {
        setError(`Skipped ${file.name}: file too large (max 50MB)`);
        continue;
      }

      validFiles.push(file);

      // Create preview for images only
      if (file.type.startsWith("image/")) {
        const reader = new FileReader();
        reader.onload = () => {
          setPreviews((prev) => [...prev, reader.result as string]);
        };
        reader.readAsDataURL(file);
      } else {
        // PDF placeholder
        newPreviews.push("");
      }
    }

    if (validFiles.length > 0) {
      setFiles((prev) => [...prev, ...validFiles]);
      setError(null);
      setResults(null);
    }
  }

  function removeFile(index: number) {
    setFiles((prev) => prev.filter((_, i) => i !== index));
    setPreviews((prev) => prev.filter((_, i) => i !== index));
  }

  function clearAll() {
    setFiles([]);
    setPreviews([]);
    setResults(null);
    setError(null);
    if (fileInputRef.current) {
      fileInputRef.current.value = "";
    }
  }

  function toggleExpanded(index: number) {
    setExpandedResults((prev) => {
      const next = new Set(prev);
      if (next.has(index)) {
        next.delete(index);
      } else {
        next.add(index);
      }
      return next;
    });
  }

  return (
    <div className="bg-card rounded-[var(--radius-md)] border border-[var(--surface-elevated)] p-[var(--space-md)]">
      <h3 className="text-lg font-semibold text-foreground mb-2">
        Bulk Upload Lab Reports
      </h3>
      <p className="text-sm text-muted mb-[var(--space-md)]">
        Upload photos, screenshots, or PDF files of your lab results. Our AI will
        extract all biomarkers automatically.
      </p>

      <div className="space-y-[var(--space-md)]">
        {/* File Input */}
        <div>
          <input
            ref={fileInputRef}
            type="file"
            accept="image/*,.pdf,application/pdf"
            multiple
            onChange={handleFileSelect}
            disabled={processing}
            className="block w-full text-sm text-muted
              file:mr-4 file:py-2 file:px-4
              file:rounded-[var(--radius-sm)] file:border-0
              file:text-sm file:font-medium
              file:bg-bloodwork/20 file:text-bloodwork
              hover:file:bg-bloodwork/30
              disabled:opacity-50"
          />
          <p className="text-xs text-muted mt-1">
            Supports: PNG, JPG, PDF (up to 50MB each, max 20 files)
          </p>
        </div>

        {/* File List */}
        {files.length > 0 && (
          <div className="space-y-2">
            <div className="flex items-center justify-between">
              <span className="text-sm font-medium text-foreground">
                {files.length} file(s) selected
              </span>
              <button
                onClick={clearAll}
                className="text-xs text-muted hover:text-foreground"
              >
                Clear all
              </button>
            </div>
            <div className="grid grid-cols-2 md:grid-cols-4 gap-2">
              {files.map((file, i) => (
                <div
                  key={i}
                  className="relative p-2 bg-[var(--surface-secondary)] rounded-[var(--radius-sm)] border border-[var(--surface-elevated)]"
                >
                  {previews[i] ? (
                    <img
                      src={previews[i]}
                      alt={file.name}
                      className="w-full h-20 object-cover rounded"
                    />
                  ) : (
                    <div className="w-full h-20 flex items-center justify-center bg-bloodwork/10 rounded">
                      <span className="text-bloodwork text-xs font-medium">PDF</span>
                    </div>
                  )}
                  <p className="text-xs text-muted mt-1 truncate" title={file.name}>
                    {file.name}
                  </p>
                  <button
                    onClick={() => removeFile(i)}
                    className="absolute top-1 right-1 w-5 h-5 bg-black/50 rounded-full text-white text-xs hover:bg-black/70"
                    aria-label="Remove"
                  >
                    &times;
                  </button>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* Options */}
        {files.length > 0 && (
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4 p-4 bg-[var(--surface-secondary)] rounded-[var(--radius-sm)]">
            <div>
              <label className="block text-xs font-medium text-muted mb-1">
                Panel Date
              </label>
              <input
                type="date"
                value={panelDate}
                onChange={(e) => setPanelDate(e.target.value)}
                className="w-full px-3 py-2 text-sm bg-background border border-[var(--surface-elevated)] rounded-[var(--radius-sm)] text-foreground"
              />
            </div>
            <div>
              <label className="block text-xs font-medium text-muted mb-1">
                Lab Name (optional)
              </label>
              <input
                type="text"
                value={labName}
                onChange={(e) => setLabName(e.target.value)}
                placeholder="e.g., Quest, LabCorp"
                className="w-full px-3 py-2 text-sm bg-background border border-[var(--surface-elevated)] rounded-[var(--radius-sm)] text-foreground placeholder:text-muted"
              />
            </div>
            <div className="flex items-end">
              <label className="flex items-center gap-2 cursor-pointer">
                <input
                  type="checkbox"
                  checked={autoSave}
                  onChange={(e) => setAutoSave(e.target.checked)}
                  className="w-4 h-4 rounded border-[var(--surface-elevated)]"
                />
                <span className="text-sm text-foreground">Auto-save panels</span>
              </label>
            </div>
          </div>
        )}

        {/* Error */}
        {error && (
          <div className="p-[var(--space-sm)] bg-recovery-red/10 border border-recovery-red/30 rounded-[var(--radius-sm)]">
            <p className="text-sm text-recovery-red">{error}</p>
          </div>
        )}

        {/* Progress */}
        {processing && progress && (
          <div className="p-[var(--space-sm)] bg-bloodwork/10 border border-bloodwork/30 rounded-[var(--radius-sm)]">
            <p className="text-sm text-bloodwork">{progress}</p>
          </div>
        )}

        {/* Results */}
        {results && (
          <div className="space-y-[var(--space-sm)]">
            {/* Summary */}
            <div className={`p-[var(--space-sm)] rounded-[var(--radius-sm)] border ${
              results.failed === 0
                ? "bg-recovery-green/10 border-recovery-green/30"
                : results.successful === 0
                ? "bg-recovery-red/10 border-recovery-red/30"
                : "bg-training/10 border-training/30"
            }`}>
              <p className={`text-sm font-medium ${
                results.failed === 0
                  ? "text-recovery-green"
                  : results.successful === 0
                  ? "text-recovery-red"
                  : "text-training"
              }`}>
                Processed {results.total_files} files: {results.successful} successful, {results.failed} failed
                {results.total_markers > 0 && ` (${results.total_markers} total markers extracted)`}
              </p>
            </div>

            {/* Individual Results */}
            <div className="space-y-2">
              {results.results.map((result, i) => (
                <div
                  key={i}
                  className={`border rounded-[var(--radius-sm)] overflow-hidden ${
                    result.success
                      ? "border-recovery-green/30"
                      : "border-recovery-red/30"
                  }`}
                >
                  {/* Header */}
                  <button
                    onClick={() => toggleExpanded(i)}
                    className={`w-full p-3 flex items-center justify-between text-left ${
                      result.success ? "bg-recovery-green/5" : "bg-recovery-red/5"
                    }`}
                  >
                    <div className="flex items-center gap-2">
                      <span className={`text-lg ${result.success ? "text-recovery-green" : "text-recovery-red"}`}>
                        {result.success ? "✓" : "✗"}
                      </span>
                      <span className="font-medium text-foreground">{result.filename}</span>
                      {result.success && (
                        <span className="text-xs text-muted">
                          ({result.markers.length} markers, {Math.round((result.confidence || 0) * 100)}% confidence)
                        </span>
                      )}
                    </div>
                    <span className="text-muted">{expandedResults.has(i) ? "▼" : "▶"}</span>
                  </button>

                  {/* Expanded Content */}
                  {expandedResults.has(i) && (
                    <div className="p-3 border-t border-[var(--surface-elevated)]">
                      {result.success ? (
                        <div className="space-y-2">
                          {result.panel_id && (
                            <p className="text-xs text-recovery-green">
                              Saved as panel (ID: {result.panel_id.slice(0, 8)}...)
                            </p>
                          )}
                          <div className="grid grid-cols-1 md:grid-cols-2 gap-2">
                            {result.markers.map((marker, j) => (
                              <div
                                key={j}
                                className="flex items-center justify-between p-2 bg-[var(--surface-secondary)] rounded-[var(--radius-sm)]"
                              >
                                <span className="font-medium text-foreground text-sm">
                                  {marker.name}
                                </span>
                                <span className="text-muted text-sm">
                                  {marker.value} {marker.unit}
                                  {marker.flag && (
                                    <span
                                      className={`ml-2 font-medium ${
                                        marker.flag === "H"
                                          ? "text-recovery-red"
                                          : "text-training"
                                      }`}
                                    >
                                      ({marker.flag})
                                    </span>
                                  )}
                                </span>
                              </div>
                            ))}
                          </div>
                        </div>
                      ) : (
                        <p className="text-sm text-recovery-red">{result.error}</p>
                      )}
                    </div>
                  )}
                </div>
              ))}
            </div>
          </div>
        )}

        {/* Actions */}
        <div className="flex gap-[var(--space-sm)]">
          <OutliveButton
            onClick={handleProcess}
            disabled={files.length === 0 || processing}
            loading={processing}
          >
            {processing ? "Processing..." : `Extract from ${files.length} file(s)`}
          </OutliveButton>
        </div>
      </div>
    </div>
  );
}
