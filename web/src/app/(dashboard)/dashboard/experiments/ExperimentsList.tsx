"use client";

import { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { EmptyState } from "@/components/ui/EmptyState";
import { OutliveButton } from "@/components/ui/OutliveButton";

interface Experiment {
  id: string;
  title: string;
  hypothesis: string;
  status: "active" | "completed" | "abandoned";
  start_date: string;
  end_date?: string;
  metrics?: Record<string, any>;
  snapshots?: any[];
  created_at: string;
  updated_at: string;
}

interface ExperimentsListProps {
  experiments: Experiment[];
}

const statusBadgeStyles: Record<string, string> = {
  active: "bg-recovery-green text-white",
  completed: "bg-training text-white",
  abandoned: "bg-[var(--surface-elevated)] text-muted",
};

export function ExperimentsList({ experiments: initialExperiments }: ExperimentsListProps) {
  const [experiments, setExperiments] = useState<Experiment[]>(initialExperiments);
  const [deletingId, setDeletingId] = useState<string | null>(null);
  const router = useRouter();

  async function handleDelete(experimentId: string) {
    if (!window.confirm("Are you sure you want to delete this experiment?")) return;

    setDeletingId(experimentId);
    try {
      const res = await fetch(`/api/backend/experiments/${experimentId}`, {
        method: "DELETE",
      });
      if (!res.ok) throw new Error("Failed to delete");
      setExperiments((prev) => prev.filter((exp) => exp.id !== experimentId));
    } catch {
      alert("Failed to delete experiment. Please try again.");
    } finally {
      setDeletingId(null);
    }
  }

  if (experiments.length === 0) {
    return (
      <EmptyState
        title="No experiments yet"
        description="Design N=1 experiments to test supplements, protocols, and lifestyle changes with tracked outcomes."
        actionLabel="Create Your First Experiment"
        onAction={() => router.push("/dashboard/experiments/new")}
      />
    );
  }

  return (
    <div className="space-y-[var(--space-md)]">
      {experiments.map((exp) => {
        const snapshotCount = exp.snapshots?.length ?? 0;

        return (
          <Link
            key={exp.id}
            href={`/dashboard/experiments/${exp.id}`}
            className="block bg-card rounded-[var(--radius-md)] border border-[var(--surface-elevated)] p-[var(--space-md)] hover:border-training/40 transition-colors"
          >
            <div className="flex items-start justify-between">
              <div className="space-y-1 flex-1 min-w-0">
                <div className="flex items-center gap-[var(--space-sm)]">
                  <h3 className="font-semibold text-foreground truncate">{exp.title}</h3>
                  <span
                    className={`px-2 py-0.5 rounded-full text-xs font-medium shrink-0 ${statusBadgeStyles[exp.status] ?? ""}`}
                  >
                    {exp.status.charAt(0).toUpperCase() + exp.status.slice(1)}
                  </span>
                </div>

                {exp.hypothesis && (
                  <p className="text-sm text-muted line-clamp-2">{exp.hypothesis}</p>
                )}

                <div className="flex items-center gap-[var(--space-sm)] text-xs text-muted">
                  <span>
                    {new Date(exp.start_date).toLocaleDateString("en-US", {
                      month: "short",
                      day: "numeric",
                      year: "numeric",
                    })}
                    {exp.end_date && (
                      <>
                        {" — "}
                        {new Date(exp.end_date).toLocaleDateString("en-US", {
                          month: "short",
                          day: "numeric",
                          year: "numeric",
                        })}
                      </>
                    )}
                  </span>
                  <span>{snapshotCount} snapshot{snapshotCount !== 1 ? "s" : ""}</span>
                </div>
              </div>

              <div onClick={(e) => { e.preventDefault(); e.stopPropagation(); }}>
                <OutliveButton
                  variant="destructive"
                  onClick={() => handleDelete(exp.id)}
                  loading={deletingId === exp.id}
                  className="text-sm px-[var(--space-sm)] py-1 ml-[var(--space-sm)]"
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
