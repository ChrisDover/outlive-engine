'use client';

import { useState } from 'react';

interface MorningBriefProps {
  brief: {
    date: string;
    greeting: string;
    top_priorities: string[];
    eating_plan: {
      summary: string;
      macros: {
        protein?: number;
        carbs?: number;
        fat?: number;
      };
      meal_timing: string;
    };
    supplement_plan: Array<{
      name: string;
      dose: string;
      unit: string;
      timing: string;
      rationale?: string;
      source_expert?: string;
    }>;
    workout_plan: {
      type?: string;
      duration?: number;
      rpe?: number;
      exercises?: Array<{ name: string; sets: number; reps: string }>;
    };
    interventions_plan: Array<{
      type: string;
      duration?: number;
      notes?: string;
      source_expert?: string;
    }>;
    rationale: string;
    expert_citations: string[];
    recovery_status: {
      status: string;
      hrv?: number;
      sleep_hours?: number;
      recovery_score?: number;
      recommendation: string;
    };
  } | null;
  isLoading?: boolean;
  onRefresh?: () => void;
}

export function MorningBrief({ brief, isLoading, onRefresh }: MorningBriefProps) {
  const [expanded, setExpanded] = useState(false);

  if (isLoading) {
    return (
      <div className="bg-card border border-[var(--surface-elevated)] p-[var(--space-lg)]">
        <div className="animate-pulse space-y-[var(--space-md)]">
          <div className="h-6 bg-[var(--surface-secondary)] w-3/4"></div>
          <div className="h-4 bg-[var(--surface-secondary)] w-full"></div>
          <div className="h-4 bg-[var(--surface-secondary)] w-5/6"></div>
        </div>
      </div>
    );
  }

  if (!brief) {
    return (
      <div className="bg-card border border-[var(--surface-elevated)] p-[var(--space-lg)]">
        <p className="text-muted">No morning brief available. Generate a daily plan to get started.</p>
        {onRefresh && (
          <button
            onClick={onRefresh}
            className="mt-[var(--space-md)] text-training hover:underline"
          >
            Generate Plan
          </button>
        )}
      </div>
    );
  }

  const recoveryColor = {
    good: 'text-[var(--recovery-green)]',
    moderate: 'text-[var(--recovery-yellow)]',
    low: 'text-[var(--recovery-red)]',
    unknown: 'text-muted',
  }[brief.recovery_status?.status || 'unknown'];

  return (
    <div className="bg-card border border-[var(--surface-elevated)] overflow-hidden">
      {/* Header with recovery status */}
      <div className="flex items-center justify-between p-[var(--space-md)] border-b border-[var(--surface-elevated)]">
        <div className="flex items-center gap-[var(--space-sm)]">
          <span className="text-training">{'>'}</span>
          <span className="text-foreground font-semibold">MORNING BRIEF</span>
          <span className="text-muted">// {new Date(brief.date).toLocaleDateString('en-US', { weekday: 'long', month: 'short', day: 'numeric' })}</span>
        </div>
        <div className={`text-sm ${recoveryColor}`}>
          RECOVERY: {brief.recovery_status?.status?.toUpperCase() || 'UNKNOWN'}
          {brief.recovery_status?.hrv && <span className="ml-2">HRV {brief.recovery_status.hrv}</span>}
        </div>
      </div>

      {/* Greeting - the AI-generated conversational content */}
      <div className="p-[var(--space-lg)] border-b border-[var(--surface-elevated)]">
        <p className="text-foreground whitespace-pre-wrap leading-relaxed">
          {brief.greeting}
        </p>
      </div>

      {/* Top Priorities */}
      <div className="p-[var(--space-md)] border-b border-[var(--surface-elevated)]">
        <h4 className="text-muted text-sm mb-[var(--space-sm)]">TODAY&apos;S FOCUS</h4>
        <ul className="space-y-[var(--space-xs)]">
          {brief.top_priorities.map((priority, idx) => (
            <li key={idx} className="flex items-start gap-[var(--space-sm)]">
              <span className="text-training">{idx + 1}.</span>
              <span className="text-foreground">{priority}</span>
            </li>
          ))}
        </ul>
      </div>

      {/* Expandable Details */}
      <button
        onClick={() => setExpanded(!expanded)}
        className="w-full p-[var(--space-sm)] text-muted hover:text-foreground transition-colors flex items-center justify-center gap-[var(--space-xs)]"
      >
        <span>{expanded ? 'COLLAPSE' : 'SHOW DETAILS'}</span>
        <span>{expanded ? '▲' : '▼'}</span>
      </button>

      {expanded && (
        <div className="border-t border-[var(--surface-elevated)]">
          {/* Supplements */}
          {brief.supplement_plan.length > 0 && (
            <div className="p-[var(--space-md)] border-b border-[var(--surface-elevated)]">
              <h4 className="text-supplements text-sm mb-[var(--space-sm)]">SUPPLEMENTS</h4>
              <div className="grid grid-cols-1 md:grid-cols-2 gap-[var(--space-xs)]">
                {brief.supplement_plan.map((supp, idx) => (
                  <div key={idx} className="flex items-center gap-[var(--space-sm)]">
                    <span className="text-muted">•</span>
                    <span className="text-foreground">
                      {supp.name} {supp.dose}{supp.unit}
                    </span>
                    <span className="text-muted text-xs">({supp.timing})</span>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Workout */}
          {brief.workout_plan?.type && (
            <div className="p-[var(--space-md)] border-b border-[var(--surface-elevated)]">
              <h4 className="text-training text-sm mb-[var(--space-sm)]">TRAINING</h4>
              <p className="text-foreground">
                {brief.workout_plan.type} - {brief.workout_plan.duration || 45} min
                {brief.workout_plan.rpe && <span className="text-muted"> (RPE {brief.workout_plan.rpe})</span>}
              </p>
              {brief.workout_plan.exercises && brief.workout_plan.exercises.length > 0 && (
                <ul className="mt-[var(--space-sm)] space-y-[var(--space-xxs)]">
                  {brief.workout_plan.exercises.map((ex, idx) => (
                    <li key={idx} className="text-muted text-sm">
                      • {ex.name}: {ex.sets} x {ex.reps}
                    </li>
                  ))}
                </ul>
              )}
            </div>
          )}

          {/* Interventions */}
          {brief.interventions_plan.length > 0 && (
            <div className="p-[var(--space-md)] border-b border-[var(--surface-elevated)]">
              <h4 className="text-interventions text-sm mb-[var(--space-sm)]">INTERVENTIONS</h4>
              <div className="space-y-[var(--space-xs)]">
                {brief.interventions_plan.map((int, idx) => (
                  <div key={idx} className="flex items-center gap-[var(--space-sm)]">
                    <span className="text-muted">•</span>
                    <span className="text-foreground">{int.type}</span>
                    {int.duration && <span className="text-muted">({int.duration} min)</span>}
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Nutrition */}
          <div className="p-[var(--space-md)] border-b border-[var(--surface-elevated)]">
            <h4 className="text-nutrition text-sm mb-[var(--space-sm)]">NUTRITION</h4>
            <p className="text-foreground">{brief.eating_plan.summary}</p>
            {brief.eating_plan.macros.protein && (
              <p className="text-muted text-sm mt-[var(--space-xs)]">
                P: {brief.eating_plan.macros.protein}g | C: {brief.eating_plan.macros.carbs}g | F: {brief.eating_plan.macros.fat}g
              </p>
            )}
          </div>

          {/* Expert Citations */}
          {brief.expert_citations.length > 0 && (
            <div className="p-[var(--space-md)]">
              <h4 className="text-muted text-sm mb-[var(--space-sm)]">SOURCES</h4>
              <p className="text-subtle text-sm">
                Based on protocols from: {brief.expert_citations.join(', ')}
              </p>
            </div>
          )}

          {/* Rationale */}
          {brief.rationale && (
            <div className="p-[var(--space-md)] bg-[var(--surface-secondary)]">
              <h4 className="text-muted text-sm mb-[var(--space-sm)]">WHY THIS PLAN</h4>
              <p className="text-muted text-sm leading-relaxed">{brief.rationale}</p>
            </div>
          )}
        </div>
      )}
    </div>
  );
}
