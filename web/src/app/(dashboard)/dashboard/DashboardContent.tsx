"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
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

interface Exercise {
  name: string;
  sets?: number | string;
  reps?: number | string;
}

interface Training {
  type?: string;
  duration?: number;
  rpe?: number;
  exercises?: Exercise[];
}

interface Meal {
  name?: string;
  time?: string;
  calories?: number;
  protein?: number;
  items?: string[];
}

interface Nutrition {
  tdee?: number;
  protein?: number;
  carbs?: number;
  fat?: number;
  meal_timing?: string;
  notes?: string;
  meals?: Meal[];
}

interface Supplement {
  name: string;
  dose?: number | string;
  unit?: string;
  timing?: string;
  source_expert?: string;
}

interface Intervention {
  type?: string;
  name?: string;
  duration?: number;
  source_expert?: string;
}

interface Sleep {
  bedtime?: string;
  wake_time?: string;
  target_hours?: number;
}

interface Protocol {
  training?: Training;
  nutrition?: Nutrition;
  supplements?: Supplement[];
  interventions?: Intervention[];
  sleep?: Sleep;
  summary?: string;
  rationale?: string;
}

// The backend sometimes returns the protocol wrapped in an envelope
// ({ protocol: {...} }) and sometimes inline — accept both shapes.
type ProtocolInput = (Protocol & { protocol?: Protocol }) | null | undefined;

interface DashboardContentProps {
  protocol: ProtocolInput;
  wearable?: unknown;
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
  adherence = [],
  goals = [],
  progressStats,
}: DashboardContentProps) {
  const [showProtocols, setShowProtocols] = useState(true);
  const [generating, setGenerating] = useState(false);
  const router = useRouter();

  const handleGeneratePlan = async () => {
    setGenerating(true);
    try {
      const today = new Date().toISOString().split("T")[0];
      const res = await fetch(`/api/backend/protocols/daily/generate?target_date=${today}`, {
        method: "POST",
      });
      if (!res.ok) throw new Error();
      router.refresh();
    } catch (error) {
      console.error("Failed to generate plan:", error);
    } finally {
      setGenerating(false);
    }
  };

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
      // Re-fetch server data without a full-page reload.
      router.refresh();
    } catch (error) {
      console.error("Failed to log adherence:", error);
    }
  };

  const handleQuickLog = async (message: string) => {
    try {
      await fetch(`/api/backend/progress/adherence/quick-log?message=${encodeURIComponent(message)}`, {
        method: "POST",
      });
      router.refresh();
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
      router.refresh();
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

      {/* Today's Plan */}
      <div className="border border-[var(--surface-elevated)] bg-card">
        <div className="w-full p-[var(--space-md)] flex items-center justify-between gap-3">
          <button
            onClick={() => setShowProtocols(!showProtocols)}
            className="flex items-center gap-[var(--space-sm)]"
          >
            <span className="text-training">{'>'}</span>
            <span className="text-foreground font-semibold">TODAY&apos;S PLAN</span>
            <span className="text-muted">{showProtocols ? '▲' : '▼'}</span>
          </button>
          <button
            onClick={handleGeneratePlan}
            disabled={generating}
            className="shrink-0 rounded-[var(--radius-md)] px-3 py-1.5 text-xs font-medium text-white transition-opacity disabled:opacity-60"
            style={{ background: "var(--accent)" }}
          >
            {generating ? "Generating…" : protocolData ? "Regenerate" : "Generate plan"}
          </button>
        </div>

        {showProtocols && (
          <div className="border-t border-[var(--surface-elevated)]">
            {generating && (
              <div className="p-[var(--space-md)] border-b border-[var(--surface-elevated)] text-sm text-muted">
                Generating your personalized meal plan, workout, and supplements… this can take up to a minute on the local model.
              </div>
            )}
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
                        {training.exercises?.map((ex, i) => (
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

                      {/* Meal plan */}
                      {Array.isArray(nutrition.meals) && nutrition.meals.length > 0 && (
                        <div className="mt-[var(--space-md)] space-y-[var(--space-sm)] border-t border-[var(--surface-elevated)] pt-[var(--space-md)]">
                          {nutrition.meals.map((meal, i) => (
                            <div key={i} className="text-sm">
                              <div className="flex items-baseline justify-between gap-2">
                                <span className="font-medium text-foreground">
                                  {meal.name || `Meal ${i + 1}`}
                                  {meal.time ? <span className="text-muted font-normal"> · {meal.time}</span> : null}
                                </span>
                                {(meal.calories || meal.protein) && (
                                  <span className="font-mono text-xs text-muted">
                                    {meal.calories ? `${meal.calories} kcal` : ""}
                                    {meal.calories && meal.protein ? " · " : ""}
                                    {meal.protein ? `${meal.protein}g P` : ""}
                                  </span>
                                )}
                              </div>
                              {Array.isArray(meal.items) && meal.items.length > 0 && (
                                <p className="text-muted mt-0.5">{meal.items.join(", ")}</p>
                              )}
                            </div>
                          ))}
                        </div>
                      )}

                      {nutrition.notes && (
                        <p className="mt-[var(--space-sm)] text-xs text-muted">{nutrition.notes}</p>
                      )}
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
                        {Array.isArray(supplements) && supplements.map((s, i) => (
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
                        {Array.isArray(interventions) && interventions.map((item, i) => (
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

function generateAdherenceItems(protocol: Protocol | null | undefined): AdherenceItem[] {
  if (!protocol) return [];

  const items: AdherenceItem[] = [];

  // Add supplements as adherence items
  if (Array.isArray(protocol.supplements)) {
    protocol.supplements.forEach((s) => {
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
    protocol.interventions.forEach((i) => {
      items.push({
        item_type: "intervention",
        item_name: i.type || i.name || "Intervention",
        completed: false,
      });
    });
  }

  return items;
}
