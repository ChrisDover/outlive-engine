"use client";

import Link from "next/link";

interface Marker {
  name: string;
  value: number;
  unit: string;
  reference_low?: number | null;
  reference_high?: number | null;
  flag?: string | null;
}

interface Panel {
  id: string;
  panel_date: string;
  lab_name: string;
  markers: Marker[];
  notes?: string;
  created_at: string;
  updated_at?: string;
}

interface PanelDetailProps {
  panel: Panel;
}

function FlagBadge({ flag }: { flag?: string | null }) {
  if (flag === "H") {
    return (
      <span className="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-recovery-red text-white">
        H
      </span>
    );
  }
  if (flag === "L") {
    return (
      <span className="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-training text-white">
        L
      </span>
    );
  }
  return (
    <span className="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-recovery-green text-white">
      Normal
    </span>
  );
}

export function PanelDetail({ panel }: PanelDetailProps) {
  const formattedDate = new Date(panel.panel_date).toLocaleDateString("en-US", {
    year: "numeric",
    month: "long",
    day: "numeric",
  });

  return (
    <div className="space-y-[var(--space-lg)]">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <Link
            href="/dashboard/bloodwork"
            className="text-sm text-muted hover:text-foreground transition-colors"
          >
            &larr; Back to Bloodwork
          </Link>
          <h1 className="text-2xl font-bold text-foreground mt-1">
            {formattedDate}
          </h1>
          {panel.lab_name && (
            <p className="text-muted">{panel.lab_name}</p>
          )}
        </div>
      </div>

      {/* Markers table */}
      <div className="bg-card rounded-[var(--radius-md)] border border-[var(--surface-elevated)] overflow-hidden">
        <table className="w-full">
          <thead>
            <tr className="border-b border-[var(--surface-elevated)]">
              <th className="text-left text-sm font-medium text-muted px-[var(--space-md)] py-[var(--space-sm)]">
                Marker
              </th>
              <th className="text-left text-sm font-medium text-muted px-[var(--space-md)] py-[var(--space-sm)]">
                Value
              </th>
              <th className="text-left text-sm font-medium text-muted px-[var(--space-md)] py-[var(--space-sm)]">
                Unit
              </th>
              <th className="text-left text-sm font-medium text-muted px-[var(--space-md)] py-[var(--space-sm)]">
                Reference Range
              </th>
              <th className="text-left text-sm font-medium text-muted px-[var(--space-md)] py-[var(--space-sm)]">
                Flag
              </th>
            </tr>
          </thead>
          <tbody>
            {panel.markers.map((marker, i) => (
              <tr
                key={i}
                className="border-b border-[var(--surface-elevated)] last:border-b-0"
              >
                <td className="px-[var(--space-md)] py-[var(--space-sm)] text-foreground font-medium">
                  {marker.name}
                </td>
                <td className="px-[var(--space-md)] py-[var(--space-sm)] text-foreground">
                  {marker.value}
                </td>
                <td className="px-[var(--space-md)] py-[var(--space-sm)] text-muted">
                  {marker.unit}
                </td>
                <td className="px-[var(--space-md)] py-[var(--space-sm)] text-muted">
                  {marker.reference_low != null && marker.reference_high != null
                    ? `${marker.reference_low} – ${marker.reference_high}`
                    : marker.reference_low != null
                    ? `> ${marker.reference_low}`
                    : marker.reference_high != null
                    ? `< ${marker.reference_high}`
                    : "—"}
                </td>
                <td className="px-[var(--space-md)] py-[var(--space-sm)]">
                  <FlagBadge flag={marker.flag} />
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* Notes */}
      {panel.notes && (
        <div className="bg-card rounded-[var(--radius-md)] border border-[var(--surface-elevated)] p-[var(--space-md)]">
          <h2 className="text-lg font-semibold text-foreground mb-[var(--space-xs)]">
            Notes
          </h2>
          <p className="text-muted whitespace-pre-wrap">{panel.notes}</p>
        </div>
      )}

      {/* Back button */}
      <div>
        <Link
          href="/dashboard/bloodwork"
          className="inline-block px-[var(--space-lg)] py-[var(--space-sm)] bg-training text-white rounded-[var(--radius-sm)] font-medium hover:opacity-90 transition-opacity"
        >
          Back to Bloodwork
        </Link>
      </div>
    </div>
  );
}
