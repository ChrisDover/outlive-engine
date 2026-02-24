"use client";

import { useState } from "react";
import Link from "next/link";
import { EmptyState } from "@/components/ui/EmptyState";
import { OutliveButton } from "@/components/ui/OutliveButton";
import { useRouter } from "next/navigation";

interface Marker {
  name: string;
  value: number;
  unit: string;
  reference_low?: number;
  reference_high?: number;
  flag?: string | null;
}

interface Panel {
  id: string;
  panel_date: string;
  lab_name: string;
  markers: Marker[];
  notes?: string;
  created_at: string;
}

interface BloodworkListProps {
  panels: Panel[];
}

export function BloodworkList({ panels: initialPanels }: BloodworkListProps) {
  const [panels, setPanels] = useState<Panel[]>(initialPanels);
  const [deletingId, setDeletingId] = useState<string | null>(null);
  const router = useRouter();

  async function handleDelete(panelId: string) {
    if (!window.confirm("Are you sure you want to delete this panel?")) return;

    setDeletingId(panelId);
    try {
      const res = await fetch(`/api/backend/bloodwork/${panelId}`, {
        method: "DELETE",
      });
      if (!res.ok) throw new Error("Failed to delete");
      setPanels((prev) => prev.filter((p) => p.id !== panelId));
    } catch {
      alert("Failed to delete panel. Please try again.");
    } finally {
      setDeletingId(null);
    }
  }

  if (panels.length === 0) {
    return (
      <EmptyState
        title="No bloodwork panels yet"
        description="Upload lab results or manually enter biomarkers to track trends over time."
        actionLabel="Add Your First Panel"
        onAction={() => router.push("/dashboard/bloodwork/new")}
      />
    );
  }

  return (
    <div className="space-y-[var(--space-md)]">
      {panels.map((panel) => {
        const highCount = panel.markers.filter((m) => m.flag === "H").length;
        const lowCount = panel.markers.filter((m) => m.flag === "L").length;

        return (
          <Link
            key={panel.id}
            href={`/dashboard/bloodwork/${panel.id}`}
            className="block bg-card rounded-[var(--radius-md)] border border-[var(--surface-elevated)] p-[var(--space-md)] hover:border-bloodwork/40 transition-colors"
          >
            <div className="flex items-center justify-between">
              <div className="space-y-1">
                <div className="flex items-center gap-[var(--space-sm)]">
                  <span className="font-semibold text-foreground">
                    {new Date(panel.panel_date).toLocaleDateString("en-US", {
                      year: "numeric",
                      month: "long",
                      day: "numeric",
                    })}
                  </span>
                  {panel.lab_name && (
                    <span className="text-sm text-muted">
                      {panel.lab_name}
                    </span>
                  )}
                </div>
                <div className="flex items-center gap-[var(--space-sm)] text-sm text-muted">
                  <span>{panel.markers.length} markers</span>
                  {highCount > 0 && (
                    <span className="px-2 py-0.5 bg-recovery-red/15 text-recovery-red rounded-full text-xs font-medium">
                      {highCount} High
                    </span>
                  )}
                  {lowCount > 0 && (
                    <span className="px-2 py-0.5 bg-training/15 text-training rounded-full text-xs font-medium">
                      {lowCount} Low
                    </span>
                  )}
                </div>
              </div>
              <div onClick={(e) => { e.preventDefault(); e.stopPropagation(); }}>
                <OutliveButton
                  variant="destructive"
                  onClick={() => handleDelete(panel.id)}
                  loading={deletingId === panel.id}
                  className="text-sm px-[var(--space-sm)] py-1"
                >
                  Delete
                </OutliveButton>
              </div>
            </div>
          </Link>
        );
      })}
    </div>
  );
}
