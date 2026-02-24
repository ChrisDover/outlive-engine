"use client";

import Link from "next/link";
import { useState } from "react";

interface WelcomeCardProps {
  name: string | null;
  hasBloodwork: boolean;
  hasBodyComp: boolean;
  hasGenomics: boolean;
  hasExperiments: boolean;
}

const steps = [
  {
    key: "bloodwork",
    title: "Log bloodwork",
    description: "Add your latest lab panel — testosterone, lipids, metabolic markers, and more.",
    href: "/dashboard/bloodwork/new",
    icon: "🩸",
    field: "hasBloodwork",
  },
  {
    key: "bodycomp",
    title: "Track body composition",
    description: "Log weight, body fat, lean mass, and waist circumference.",
    href: "/dashboard/body-composition",
    icon: "📊",
    field: "hasBodyComp",
  },
  {
    key: "genomics",
    title: "Add genomic risks",
    description: "Enter risk categories from your genetic testing (APOE, MTHFR, etc.).",
    href: "/dashboard/genomics",
    icon: "🧬",
    field: "hasGenomics",
  },
  {
    key: "experiments",
    title: "Start an experiment",
    description: "Design an N=1 experiment — test a supplement, protocol, or lifestyle change.",
    href: "/dashboard/experiments/new",
    icon: "🧪",
    field: "hasExperiments",
  },
] as const;

export function WelcomeCard({
  name,
  hasBloodwork,
  hasBodyComp,
  hasGenomics,
  hasExperiments,
}: WelcomeCardProps) {
  const [dismissed, setDismissed] = useState(false);

  if (dismissed) return null;

  const completionMap: Record<string, boolean> = {
    hasBloodwork,
    hasBodyComp,
    hasGenomics,
    hasExperiments,
  };

  const completedCount = Object.values(completionMap).filter(Boolean).length;
  const allDone = completedCount === steps.length;

  return (
    <div className="bg-card rounded-[var(--radius-md)] border border-training/30 p-[var(--space-lg)] space-y-[var(--space-md)]">
      <div className="flex items-start justify-between">
        <div>
          <h2 className="text-lg font-semibold text-foreground">
            {allDone
              ? "You're all set!"
              : name
                ? `Welcome, ${name}. Let's get started.`
                : "Welcome to Outlive Engine"}
          </h2>
          <p className="text-sm text-muted mt-1">
            {allDone
              ? "You've added data across all categories. Your daily protocol will use this to generate personalized recommendations."
              : "Add your health data so the engine can generate personalized protocols. Start with whatever you have — you can always add more later."}
          </p>
        </div>
        <button
          onClick={() => setDismissed(true)}
          className="text-muted hover:text-foreground transition-colors shrink-0 ml-[var(--space-md)]"
          aria-label="Dismiss"
        >
          ✕
        </button>
      </div>

      {/* Progress */}
      <div className="flex items-center gap-[var(--space-sm)]">
        <div className="flex-1 h-1.5 bg-[var(--surface-elevated)] rounded-full overflow-hidden">
          <div
            className="h-full bg-training rounded-full transition-all duration-500"
            style={{ width: `${(completedCount / steps.length) * 100}%` }}
          />
        </div>
        <span className="text-xs text-muted whitespace-nowrap">
          {completedCount}/{steps.length}
        </span>
      </div>

      {/* Steps */}
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-[var(--space-sm)]">
        {steps.map((step) => {
          const done = completionMap[step.field];
          return (
            <Link
              key={step.key}
              href={step.href}
              className={`flex items-start gap-[var(--space-sm)] p-[var(--space-sm)] rounded-[var(--radius-sm)] border transition-colors ${
                done
                  ? "border-recovery-green/30 bg-recovery-green/5"
                  : "border-[var(--surface-elevated)] hover:border-training/40 hover:bg-training/5"
              }`}
            >
              <span className="text-lg shrink-0">{done ? "✓" : step.icon}</span>
              <div className="min-w-0">
                <p
                  className={`text-sm font-medium ${
                    done ? "text-muted line-through" : "text-foreground"
                  }`}
                >
                  {step.title}
                </p>
                {!done && (
                  <p className="text-xs text-muted mt-0.5">{step.description}</p>
                )}
              </div>
            </Link>
          );
        })}
      </div>
    </div>
  );
}
