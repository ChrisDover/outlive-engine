"use client";

import { useState } from "react";
import { RecoveryBanner } from "@/components/ui/RecoveryBanner";
import { ProtocolCard } from "@/components/ui/ProtocolCard";
import { EmptyState } from "@/components/ui/EmptyState";

interface DashboardContentProps {
  protocol: any;
  wearable: any;
}

function getRecoveryZone(wearable: any): "green" | "yellow" | "red" {
  if (!wearable) return "green";
  const hrv = wearable?.metrics?.hrv;
  if (hrv && hrv < 30) return "red";
  if (hrv && hrv < 50) return "yellow";
  return "green";
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

export function DashboardContent({ protocol, wearable }: DashboardContentProps) {
  const zone = getRecoveryZone(wearable);

  const protocolData = protocol?.protocol || protocol;
  const training = protocolData?.training;
  const nutrition = protocolData?.nutrition;
  const supplements = protocolData?.supplements;
  const interventions = protocolData?.interventions;
  const sleep = protocolData?.sleep;
  const summary = protocolData?.summary;
  const rationale = protocolData?.rationale;

  return (
    <div className="space-y-[var(--space-md)]">
      <RecoveryBanner
        zone={zone}
        hrv={wearable?.metrics?.hrv}
        rhr={wearable?.metrics?.resting_heart_rate}
        sleepScore={wearable?.metrics?.sleep_score}
      />

      {summary && (
        <div className="bg-card rounded-[var(--radius-md)] border border-training/20 p-[var(--space-md)]">
          <p className="text-sm text-foreground">{summary}</p>
          {rationale && <RationaleToggle rationale={rationale} />}
        </div>
      )}

      {!protocolData ? (
        <EmptyState
          title="No protocol for today"
          description="Your daily protocol will appear here once generated. Connect wearables and add health data to get started."
        />
      ) : (
        <div className="space-y-[var(--space-sm)]">
          {training && (
            <ProtocolCard domain="training" title="Training" subtitle={training.type || "Workout"}>
              <div className="space-y-2 text-sm">
                {training.duration && <p className="text-muted">Duration: {training.duration} min</p>}
                {training.rpe && <p className="text-muted">Target RPE: {training.rpe}/10</p>}
                {training.exercises?.map((ex: any, i: number) => (
                  <p key={i} className="text-foreground">{ex.name} — {ex.sets}x{ex.reps}</p>
                ))}
              </div>
            </ProtocolCard>
          )}

          {nutrition && (
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
          )}

          {supplements && (
            <ProtocolCard
              domain="supplements"
              title="Supplements"
              subtitle={`${Array.isArray(supplements) ? supplements.length : 0} items`}
            >
              <ul className="space-y-1 text-sm">
                {Array.isArray(supplements) && supplements.map((s: any, i: number) => (
                  <li key={i} className="text-foreground">
                    {s.name} — {s.dose}{s.unit ? ` ${s.unit}` : ""} <span className="text-muted">({s.timing || "anytime"})</span>
                  </li>
                ))}
              </ul>
            </ProtocolCard>
          )}

          {interventions && (
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
                  </li>
                ))}
              </ul>
            </ProtocolCard>
          )}

          {sleep && (
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
          )}
        </div>
      )}
    </div>
  );
}
