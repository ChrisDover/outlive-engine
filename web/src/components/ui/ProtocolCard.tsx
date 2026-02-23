"use client";

import { useState } from "react";

type Domain = "training" | "nutrition" | "supplements" | "interventions" | "sleep" | "genomics" | "bloodwork";

interface ProtocolCardProps {
  domain: Domain;
  title: string;
  subtitle?: string;
  children?: React.ReactNode;
  defaultExpanded?: boolean;
}

const domainColors: Record<Domain, string> = {
  training: "bg-training",
  nutrition: "bg-nutrition",
  supplements: "bg-supplements",
  interventions: "bg-interventions",
  sleep: "bg-sleep",
  genomics: "bg-genomics",
  bloodwork: "bg-bloodwork",
};

export function ProtocolCard({
  domain,
  title,
  subtitle,
  children,
  defaultExpanded = false,
}: ProtocolCardProps) {
  const [expanded, setExpanded] = useState(defaultExpanded);

  return (
    <div className="bg-card rounded-[var(--radius-md)] overflow-hidden border border-[var(--surface-elevated)]">
      <div className="flex">
        {/* Domain accent strip */}
        <div className={`w-1 ${domainColors[domain]}`} />

        <div className="flex-1 p-[var(--space-md)]">
          <button
            onClick={() => setExpanded(!expanded)}
            className="w-full flex items-center justify-between text-left"
          >
            <div>
              <h3 className="font-semibold text-foreground">{title}</h3>
              {subtitle && (
                <p className="text-sm text-muted mt-0.5">{subtitle}</p>
              )}
            </div>
            <svg
              className={`w-5 h-5 text-muted transition-transform ${expanded ? "rotate-180" : ""}`}
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
            >
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
            </svg>
          </button>

          {expanded && children && (
            <>
              <div className="border-t border-[var(--surface-elevated)] mt-[var(--space-sm)]" />
              <div className="pt-[var(--space-sm)]">{children}</div>
            </>
          )}
        </div>
      </div>
    </div>
  );
}
