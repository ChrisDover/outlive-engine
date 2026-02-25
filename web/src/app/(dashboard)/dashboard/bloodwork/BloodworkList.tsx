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
  const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set());
  const [deletingId, setDeletingId] = useState<string | null>(null);
  const [bulkDeleting, setBulkDeleting] = useState(false);
  const router = useRouter();

  function toggleSelect(panelId: string) {
    setSelectedIds((prev) => {
      const next = new Set(prev);
      if (next.has(panelId)) {
        next.delete(panelId);
      } else {
        next.add(panelId);
      }
      return next;
    });
  }

  function selectAll() {
    if (selectedIds.size === panels.length) {
      setSelectedIds(new Set());
    } else {
      setSelectedIds(new Set(panels.map((p) => p.id)));
    }
  }

  async function handleDelete(panelId: string) {
    if (!window.confirm("Are you sure you want to delete this panel?")) return;

    setDeletingId(panelId);
    try {
      const res = await fetch(`/api/backend/bloodwork/${panelId}`, {
        method: "DELETE",
      });
      if (!res.ok) throw new Error("Failed to delete");
      setPanels((prev) => prev.filter((p) => p.id !== panelId));
      setSelectedIds((prev) => {
        const next = new Set(prev);
        next.delete(panelId);
        return next;
      });
    } catch {
      alert("Failed to delete panel. Please try again.");
    } finally {
      setDeletingId(null);
    }
  }

  async function handleBulkDelete() {
    if (selectedIds.size === 0) return;
    if (
      !window.confirm(
        `Are you sure you want to delete ${selectedIds.size} panel(s)?`
      )
    )
      return;

    setBulkDeleting(true);
    try {
      const res = await fetch(`/api/backend/bloodwork/bulk-delete`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(Array.from(selectedIds)),
      });
      if (!res.ok) throw new Error("Failed to delete");

      const data = await res.json();
      setPanels((prev) => prev.filter((p) => !selectedIds.has(p.id)));
      setSelectedIds(new Set());
    } catch (e) {
      alert("Failed to delete panels. Please try again.");
    } finally {
      setBulkDeleting(false);
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

  // Group panels by date for better organization
  const panelsByDate = panels.reduce(
    (acc, panel) => {
      const date = panel.panel_date;
      if (!acc[date]) acc[date] = [];
      acc[date].push(panel);
      return acc;
    },
    {} as Record<string, Panel[]>
  );

  const sortedDates = Object.keys(panelsByDate).sort(
    (a, b) => new Date(b).getTime() - new Date(a).getTime()
  );

  return (
    <div className="space-y-[var(--space-md)]">
      {/* Bulk actions bar */}
      <div className="flex items-center justify-between p-3 bg-[var(--surface-secondary)] rounded-[var(--radius-sm)]">
        <div className="flex items-center gap-3">
          <label className="flex items-center gap-2 cursor-pointer">
            <input
              type="checkbox"
              checked={selectedIds.size === panels.length && panels.length > 0}
              onChange={selectAll}
              className="w-4 h-4 rounded border-[var(--surface-elevated)]"
            />
            <span className="text-sm text-muted">
              {selectedIds.size > 0
                ? `${selectedIds.size} selected`
                : "Select all"}
            </span>
          </label>
        </div>
        <div className="flex items-center gap-2">
          {selectedIds.size > 0 && (
            <OutliveButton
              variant="destructive"
              onClick={handleBulkDelete}
              loading={bulkDeleting}
              className="text-sm"
            >
              Delete {selectedIds.size} panel(s)
            </OutliveButton>
          )}
          <span className="text-sm text-muted">
            {panels.length} total panels
          </span>
        </div>
      </div>

      {/* Panels grouped by date */}
      {sortedDates.map((date) => (
        <div key={date} className="space-y-2">
          <h3 className="text-sm font-medium text-muted px-1">
            {new Date(date).toLocaleDateString("en-US", {
              year: "numeric",
              month: "long",
              day: "numeric",
            })}
            {panelsByDate[date].length > 1 && (
              <span className="ml-2 text-xs text-training">
                ({panelsByDate[date].length} panels - possible duplicates)
              </span>
            )}
          </h3>
          {panelsByDate[date].map((panel) => {
            const highCount = panel.markers.filter((m) => m.flag === "H").length;
            const lowCount = panel.markers.filter((m) => m.flag === "L").length;

            return (
              <div
                key={panel.id}
                className={`flex items-center gap-3 bg-card rounded-[var(--radius-md)] border p-[var(--space-md)] transition-colors ${
                  selectedIds.has(panel.id)
                    ? "border-bloodwork"
                    : "border-[var(--surface-elevated)] hover:border-bloodwork/40"
                }`}
              >
                <input
                  type="checkbox"
                  checked={selectedIds.has(panel.id)}
                  onChange={() => toggleSelect(panel.id)}
                  className="w-4 h-4 rounded border-[var(--surface-elevated)]"
                />
                <Link
                  href={`/dashboard/bloodwork/${panel.id}`}
                  className="flex-1 min-w-0"
                >
                  <div className="flex items-center justify-between">
                    <div className="space-y-1">
                      <div className="flex items-center gap-[var(--space-sm)]">
                        <span className="font-semibold text-foreground">
                          {panel.markers.length} markers
                        </span>
                        {panel.lab_name && (
                          <span className="text-sm text-muted">
                            {panel.lab_name}
                          </span>
                        )}
                        <span className="text-xs text-muted">
                          uploaded{" "}
                          {new Date(panel.created_at).toLocaleTimeString(
                            "en-US",
                            {
                              hour: "numeric",
                              minute: "2-digit",
                            }
                          )}
                        </span>
                      </div>
                      <div className="flex items-center gap-[var(--space-sm)] text-sm text-muted">
                        <span className="truncate max-w-md">
                          {panel.markers
                            .slice(0, 5)
                            .map((m) => m.name)
                            .join(", ")}
                          {panel.markers.length > 5 && "..."}
                        </span>
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
                  </div>
                </Link>
                <div onClick={(e) => e.stopPropagation()}>
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
            );
          })}
        </div>
      ))}
    </div>
  );
}
