"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { EmptyState } from "@/components/ui/EmptyState";
import { ProtocolCard } from "@/components/ui/ProtocolCard";
import { OutliveButton } from "@/components/ui/OutliveButton";
import { GenomicsForm } from "./GenomicsForm";

interface Risk {
  id?: string;
  risk_category: string;
  risk_level: "elevated" | "moderate" | "normal" | "reduced";
  summary: string;
  metadata?: Record<string, any>;
  updated_at?: string;
}

interface GenomicsListProps {
  risks: Risk[];
}

const riskBadgeStyles: Record<string, string> = {
  elevated: "bg-recovery-red text-white",
  moderate: "bg-recovery-yellow text-black",
  normal: "bg-recovery-green text-white",
  reduced: "bg-training text-white",
};

export function GenomicsList({ risks: initialRisks }: GenomicsListProps) {
  const [risks, setRisks] = useState<Risk[]>(initialRisks);
  const [showAddForm, setShowAddForm] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const router = useRouter();

  function handleSaveNew(savedRisk: Risk) {
    setRisks((prev) => {
      const idx = prev.findIndex((r) => r.risk_category === savedRisk.risk_category);
      if (idx >= 0) {
        const updated = [...prev];
        updated[idx] = savedRisk;
        return updated;
      }
      return [...prev, savedRisk];
    });
    setShowAddForm(false);
  }

  function handleSaveEdit(savedRisk: Risk) {
    setRisks((prev) =>
      prev.map((r) => (r.risk_category === savedRisk.risk_category ? savedRisk : r))
    );
    setEditingId(null);
  }

  if (risks.length === 0 && !showAddForm) {
    return (
      <div>
        <EmptyState
          title="No genomic data yet"
          description="Add your genetic risk categories to see personalized recommendations."
          actionLabel="Add Risk Category"
          onAction={() => setShowAddForm(true)}
        />
        {showAddForm && (
          <div className="bg-card rounded-[var(--radius-md)] border border-[var(--surface-elevated)] p-[var(--space-md)] mt-[var(--space-md)]">
            <GenomicsForm onSave={handleSaveNew} onCancel={() => setShowAddForm(false)} />
          </div>
        )}
      </div>
    );
  }

  return (
    <div className="space-y-[var(--space-md)]">
      {risks.map((risk) => {
        const isEditing = editingId === (risk.id ?? risk.risk_category);
        return (
          <ProtocolCard
            key={risk.id ?? risk.risk_category}
            domain="genomics"
            title={risk.risk_category}
            subtitle={risk.summary}
            defaultExpanded={isEditing}
          >
            <div className="space-y-[var(--space-sm)]">
              <div className="flex items-center gap-[var(--space-sm)]">
                <span className="text-sm text-muted">Risk Level:</span>
                <span
                  className={`px-2 py-0.5 rounded-full text-xs font-medium ${riskBadgeStyles[risk.risk_level] ?? ""}`}
                >
                  {risk.risk_level.charAt(0).toUpperCase() + risk.risk_level.slice(1)}
                </span>
              </div>

              {risk.summary && (
                <p className="text-sm text-muted">{risk.summary}</p>
              )}

              {risk.updated_at && (
                <p className="text-xs text-muted">
                  Updated{" "}
                  {new Date(risk.updated_at).toLocaleDateString("en-US", {
                    year: "numeric",
                    month: "short",
                    day: "numeric",
                  })}
                </p>
              )}

              {isEditing ? (
                <GenomicsForm
                  existing={risk}
                  onSave={handleSaveEdit}
                  onCancel={() => setEditingId(null)}
                />
              ) : (
                <OutliveButton
                  variant="secondary"
                  onClick={() => setEditingId(risk.id ?? risk.risk_category)}
                  className="text-sm px-[var(--space-sm)] py-1"
                >
                  Edit
                </OutliveButton>
              )}
            </div>
          </ProtocolCard>
        );
      })}

      {showAddForm ? (
        <div className="bg-card rounded-[var(--radius-md)] border border-[var(--surface-elevated)] p-[var(--space-md)]">
          <h3 className="font-semibold text-foreground mb-[var(--space-sm)]">Add Risk Category</h3>
          <GenomicsForm onSave={handleSaveNew} onCancel={() => setShowAddForm(false)} />
        </div>
      ) : (
        <OutliveButton onClick={() => setShowAddForm(true)}>
          Add Risk Category
        </OutliveButton>
      )}
    </div>
  );
}
