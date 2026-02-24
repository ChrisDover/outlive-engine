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

interface BloodworkOCRProps {
  onMarkersExtracted?: (markers: BloodworkMarker[]) => void;
}

export function BloodworkOCR({ onMarkersExtracted }: BloodworkOCRProps) {
  const [file, setFile] = useState<File | null>(null);
  const [preview, setPreview] = useState<string | null>(null);
  const [processing, setProcessing] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [result, setResult] = useState<{
    markers: BloodworkMarker[];
    confidence: number | null;
  } | null>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);

  async function handleProcess() {
    if (!file) return;

    setProcessing(true);
    setError(null);
    setResult(null);

    try {
      // Read file as base64
      const base64 = await new Promise<string>((resolve, reject) => {
        const reader = new FileReader();
        reader.onload = () => {
          const result = reader.result as string;
          // Remove data URL prefix (e.g., "data:image/png;base64,")
          const base64Data = result.split(",")[1];
          resolve(base64Data);
        };
        reader.onerror = reject;
        reader.readAsDataURL(file);
      });

      const response = await fetch("/api/backend/ai/ocr", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          image_base64: base64,
          lab_name: null,
        }),
      });

      if (!response.ok) {
        throw new Error("OCR processing failed");
      }

      const data = await response.json();
      setResult({
        markers: data.markers || [],
        confidence: data.confidence,
      });

      if (data.markers?.length > 0) {
        onMarkersExtracted?.(data.markers);
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : "Processing failed");
    } finally {
      setProcessing(false);
    }
  }

  function handleFileSelect(e: React.ChangeEvent<HTMLInputElement>) {
    const selected = e.target.files?.[0];
    if (!selected) return;

    // Validate file type
    if (!selected.type.startsWith("image/")) {
      setError("Please select an image file (PNG, JPG, etc.)");
      return;
    }

    // Validate file size (max 10MB)
    if (selected.size > 10 * 1024 * 1024) {
      setError("Image is too large. Maximum size is 10MB.");
      return;
    }

    setFile(selected);
    setError(null);
    setResult(null);

    // Create preview
    const reader = new FileReader();
    reader.onload = () => setPreview(reader.result as string);
    reader.readAsDataURL(selected);
  }

  function clearSelection() {
    setFile(null);
    setPreview(null);
    setResult(null);
    if (fileInputRef.current) {
      fileInputRef.current.value = "";
    }
  }

  return (
    <div className="bg-card rounded-[var(--radius-md)] border border-[var(--surface-elevated)] p-[var(--space-md)]">
      <h3 className="text-lg font-semibold text-foreground mb-2">
        Extract from Screenshot
      </h3>
      <p className="text-sm text-muted mb-[var(--space-md)]">
        Upload a photo or screenshot of your lab results to automatically
        extract biomarkers using AI.
      </p>

      <div className="space-y-[var(--space-md)]">
        <div>
          <input
            ref={fileInputRef}
            type="file"
            accept="image/*"
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
        </div>

        {preview && (
          <div className="relative">
            <img
              src={preview}
              alt="Lab results preview"
              className="max-h-64 rounded-[var(--radius-sm)] border border-[var(--surface-elevated)]"
            />
            <button
              onClick={clearSelection}
              className="absolute top-2 right-2 w-6 h-6 bg-black/50 rounded-full text-white hover:bg-black/70 transition-colors"
              aria-label="Remove image"
            >
              &times;
            </button>
          </div>
        )}

        {error && (
          <div className="p-[var(--space-sm)] bg-recovery-red/10 border border-recovery-red/30 rounded-[var(--radius-sm)]">
            <p className="text-sm text-recovery-red">{error}</p>
          </div>
        )}

        {result && (
          <div className="space-y-[var(--space-sm)]">
            {result.markers.length > 0 ? (
              <>
                <div className="p-[var(--space-sm)] bg-recovery-green/10 border border-recovery-green/30 rounded-[var(--radius-sm)]">
                  <p className="text-sm text-recovery-green">
                    Extracted {result.markers.length} markers
                    {result.confidence &&
                      ` (${Math.round(result.confidence * 100)}% confidence)`}
                  </p>
                </div>
                <div className="space-y-2">
                  {result.markers.map((marker, i) => (
                    <div
                      key={i}
                      className="flex items-center justify-between p-2 bg-[var(--surface-secondary)] rounded-[var(--radius-sm)]"
                    >
                      <span className="font-medium text-foreground">
                        {marker.name}
                      </span>
                      <span className="text-muted">
                        {marker.value} {marker.unit}
                        {marker.flag && (
                          <span
                            className={`ml-2 ${
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
              </>
            ) : (
              <div className="p-[var(--space-sm)] bg-training/10 border border-training/30 rounded-[var(--radius-sm)]">
                <p className="text-sm text-training">
                  No markers could be extracted. Try a clearer image.
                </p>
              </div>
            )}
          </div>
        )}

        <div className="flex gap-[var(--space-sm)]">
          <OutliveButton
            onClick={handleProcess}
            disabled={!file || processing}
            loading={processing}
          >
            {processing ? "Processing..." : "Extract Markers"}
          </OutliveButton>
        </div>
      </div>
    </div>
  );
}
