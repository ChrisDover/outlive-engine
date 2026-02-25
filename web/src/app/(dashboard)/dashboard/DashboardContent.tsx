"use client";

import { useState } from "react";
import { ProtocolCard } from "@/components/ui/ProtocolCard";
import { EmptyState } from "@/components/ui/EmptyState";
import { AdherenceLogger } from "@/components/ui/AdherenceLogger";
import { ProgressSection } from "@/components/ui/ProgressSection";

interface AdherenceItem {
  id?: string;
  item_type: string;
  item_name: string;
  completed: boolean;
}

interface Goal {
  id: string;
  category: string;
  target_metric: string;
  target_value?: number;
  target_unit?: string;
  deadline?: string;
  status: string;
}

interface ProgressStats {
  this_week: {
    total: number;
    completed: number;
    rate: number;
  };
  this_month: {
    total: number;
    completed: number;
    rate: number;
  };
  current_streak: number;
  active_goals: number;
}

interface DashboardContentProps {
  protocol: any;
  wearable: any;
  adherence?: AdherenceItem[];
  goals?: Goal[];
  progressStats?: ProgressStats | null;
}

function RationaleToggle({ rationale }: { rationale: string }) {
  const [expanded, setExpanded] = useState(false);

  return (
    <div className="mt-[var(--space-sm)]">
      <button
        onClick={() => setExpanded(!expanded)}
        className="text-xs text-muted hover:text-foreground transition-colors"
      >
        {expanded ? "Hide rationale ▲" : "Why this recommendation? ▼"}
      </button>
      {expanded && (
        <p className="text-xs text-muted mt-1 leading-relaxed">{rationale}</p>
      )}
    </div>
  );
}

export function DashboardContent({
  protocol,
  wearable,
  adherence = [],
  goals = [],
  progressStats,
}: DashboardContentProps) {
  const [showProtocols, setShowProtocols] = useState(false);

  const protocolData = protocol?.protocol || protocol;
  const training = protocolData?.training;
  const nutrition = protocolData?.nutrition;
  const supplements = protocolData?.supplements;
  const interventions = protocolData?.interventions;
  const sleep = protocolData?.sleep;
  const summary = protocolData?.summary;
  const rationale = protocolData?.rationale;

  // Generate adherence items from protocol if none exist
  const adherenceItems: AdherenceItem[] = adherence.length > 0 ? adherence : generateAdherenceItems(protocolData);

  const handleToggleAdherence = async (itemType: string, itemName: string, completed: boolean) => {
    try {
      const today = new Date().toISOString().split("T")[0];
      await fetch("/api/backend/progress/adherence", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          date: today,
          item_type: itemType,
          item_name: itemName,
          completed,
        }),
      });
      // Optimistic update - the page will revalidate
      window.location.reload();
    } catch (error) {
      console.error("Failed to log adherence:", error);
    }
  };

  const handleQuickLog = async (message: string) => {
    try {
      await fetch(`/api/backend/progress/adherence/quick-log?message=${encodeURIComponent(message)}`, {
        method: "POST",
      });
      window.location.reload();
    } catch (error) {
      console.error("Failed to quick log:", error);
    }
  };

  const handleUpdateGoalStatus = async (goalId: string, status: string) => {
    try {
      await fetch(`/api/backend/progress/goals/${goalId}`, {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ status }),
      });
      window.location.reload();
    } catch (error) {
      console.error("Failed to update goal:", error);
    }
  };

  return (
    <div className="space-y-[var(--space-md)]">
      {/* Adherence Logger - Quick checkboxes for today's items */}
      <AdherenceLogger
        items={adherenceItems}
        onToggle={handleToggleAdherence}
        onQuickLog={handleQuickLog}
      />

      {/* Progress Section - Goals and trends */}
      {progressStats && (
        <ProgressSection
          goals={goals}
          stats={progressStats}
          onUpdateGoalStatus={handleUpdateGoalStatus}
        />
      )}

      {/* Protocol Details Toggle */}
      <div className="border border-[var(--surface-elevated)] bg-card">
        <button
          onClick={() => setShowProtocols(!showProtocols)}
          className="w-full p-[var(--space-md)] flex items-center justify-between hover:bg-[var(--surface-secondary)] transition-colors"
        >
          <div className="flex items-center gap-[var(--space-sm)]">
            <span className="text-training">{'>'}</span>
            <span className="text-foreground font-semibold">PROTOCOL DETAILS</span>
          </div>
          <span className="text-muted">{showProtocols ? '▲' : '▼'}</span>
        </button>

        {showProtocols && (
          <div className="border-t border-[var(--surface-elevated)]">
            {summary && (
              <div className="p-[var(--space-md)] border-b border-[var(--surface-elevated)]">
                <p className="text-sm text-foreground">{summary}</p>
                {rationale && <RationaleToggle rationale={rationale} />}
              </div>
            )}

            {!protocolData ? (
              <div className="p-[var(--space-lg)]">
                <EmptyState
                  title="No protocol for today"
                  description="Your daily protocol will appear here once generated. Connect wearables and add health data to get started."
                />
              </div>
            ) : (
              <div className="divide-y divide-[var(--surface-elevated)]">
                {training && (
                  <div className="p-[var(--space-md)]">
                    <ProtocolCard domain="training" title="Training" subtitle={training.type || "Workout"}>
                      <div className="space-y-2 text-sm">
                        {training.duration && <p className="text-muted">Duration: {training.duration} min</p>}
                        {training.rpe && <p className="text-muted">Target RPE: {training.rpe}/10</p>}
                        {training.exercises?.map((ex: any, i: number) => (
                          <p key={i} className="text-foreground">{ex.name} — {ex.sets}x{ex.reps}</p>
                        ))}
                      </div>
                    </ProtocolCard>
                  </div>
                )}

                {nutrition && (
                  <div className="p-[var(--space-md)]">
                    <ProtocolCard domain="nutrition" title="Nutrition" subtitle={`${nutrition.tdee || "—"} kcal target`}>
                      <div className="grid grid-cols-3 gap-[var(--space-md)] text-sm text-center">
                        <div>
                          <p className="font-mono font-semibold text-foreground">{nutrition.protein || "—"}g</p>
                          <p className="text-muted">Protein</p>
                        </div>
                        <div>
                          <p className="font-mono font-semibold text-foreground">{nutrition.carbs || "—"}g</p>
                          <p className="text-muted">Carbs</p>
                        </div>
                        <div>
                          <p className="font-mono font-semibold text-foreground">{nutrition.fat || "—"}g</p>
                          <p className="text-muted">Fat</p>
                        </div>
                      </div>
                    </ProtocolCard>
                  </div>
                )}

                {supplements && (
                  <div className="p-[var(--space-md)]">
                    <ProtocolCard
                      domain="supplements"
                      title="Supplements"
                      subtitle={`${Array.isArray(supplements) ? supplements.length : 0} items`}
                    >
                      <ul className="space-y-1 text-sm">
                        {Array.isArray(supplements) && supplements.map((s: any, i: number) => (
                          <li key={i} className="text-foreground">
                            {s.name} — {s.dose}{s.unit ? ` ${s.unit}` : ""} <span className="text-muted">({s.timing || "anytime"})</span>
                            {s.source_expert && <span className="text-subtle ml-2">[{s.source_expert}]</span>}
                          </li>
                        ))}
                      </ul>
                    </ProtocolCard>
                  </div>
                )}

                {interventions && (
                  <div className="p-[var(--space-md)]">
                    <ProtocolCard
                      domain="interventions"
                      title="Interventions"
                      subtitle={`${Array.isArray(interventions) ? interventions.length : 0} activities`}
                    >
                      <ul className="space-y-1 text-sm">
                        {Array.isArray(interventions) && interventions.map((item: any, i: number) => (
                          <li key={i} className="text-foreground">
                            {item.type || item.name}
                            {item.duration ? ` — ${item.duration} min` : ""}
                            {item.source_expert && <span className="text-subtle ml-2">[{item.source_expert}]</span>}
                          </li>
                        ))}
                      </ul>
                    </ProtocolCard>
                  </div>
                )}

                {sleep && (
                  <div className="p-[var(--space-md)]">
                    <ProtocolCard domain="sleep" title="Sleep" subtitle="Target schedule">
                      <div className="flex gap-[var(--space-lg)] text-sm">
                        <div>
                          <p className="text-muted">Bedtime</p>
                          <p className="font-semibold text-foreground">{sleep.bedtime || "—"}</p>
                        </div>
                        <div>
                          <p className="text-muted">Wake</p>
                          <p className="font-semibold text-foreground">{sleep.wake_time || "—"}</p>
                        </div>
                        {sleep.target_hours && (
                          <div>
                            <p className="text-muted">Target</p>
                            <p className="font-semibold text-foreground">{sleep.target_hours}h</p>
                          </div>
                        )}
                      </div>
                    </ProtocolCard>
                  </div>
                )}
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  );
}

function generateAdherenceItems(protocol: any): AdherenceItem[] {
  if (!protocol) return [];

  const items: AdherenceItem[] = [];

  // Add supplements as adherence items
  if (Array.isArray(protocol.supplements)) {
    protocol.supplements.forEach((s: any) => {
      items.push({
        item_type: "supplement",
        item_name: s.name,
        completed: false,
      });
    });
  }

  // Add training as adherence item
  if (protocol.training?.type) {
    items.push({
      item_type: "training",
      item_name: `${protocol.training.type} - ${protocol.training.duration || 45} min`,
      completed: false,
    });
  }

  // Add interventions as adherence items
  if (Array.isArray(protocol.interventions)) {
    protocol.interventions.forEach((i: any) => {
      items.push({
        item_type: "intervention",
        item_name: i.type || i.name,
        completed: false,
      });
    });
  }

  return items;
}
