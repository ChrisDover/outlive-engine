'use client';

import { useState } from 'react';

interface Adaptation {
  type: 'recovery' | 'circaseptan' | 'genetic' | 'biomarker';
  title: string;
  description: string;
  impact?: string;
}

interface AdaptationIndicatorProps {
  adaptations: Adaptation[];
  isCollapsible?: boolean;
}

const typeConfig: Record<string, { icon: string; color: string; bgColor: string; borderColor: string }> = {
  recovery: {
    icon: '🔋',
    color: 'text-recovery-yellow',
    bgColor: 'bg-recovery-yellow/10',
    borderColor: 'border-recovery-yellow/30',
  },
  circaseptan: {
    icon: '📅',
    color: 'text-interventions',
    bgColor: 'bg-interventions/10',
    borderColor: 'border-interventions/30',
  },
  genetic: {
    icon: '🧬',
    color: 'text-supplements',
    bgColor: 'bg-supplements/10',
    borderColor: 'border-supplements/30',
  },
  biomarker: {
    icon: '📊',
    color: 'text-training',
    bgColor: 'bg-training/10',
    borderColor: 'border-training/30',
  },
};

export function AdaptationIndicator({ adaptations, isCollapsible = true }: AdaptationIndicatorProps) {
  const [expanded, setExpanded] = useState(false);

  if (adaptations.length === 0) {
    return null;
  }

  const visibleAdaptations = isCollapsible && !expanded ? adaptations.slice(0, 2) : adaptations;
  const hiddenCount = adaptations.length - visibleAdaptations.length;

  return (
    <div className="space-y-[var(--space-xs)]">
      <div className="flex items-center gap-[var(--space-xs)]">
        <span className="text-xs text-muted font-medium">ADAPTATIONS</span>
        <span className="text-xs text-muted">({adaptations.length})</span>
      </div>

      <div className="space-y-[var(--space-xs)]">
        {visibleAdaptations.map((adaptation, idx) => {
          const config = typeConfig[adaptation.type] || typeConfig.recovery;

          return (
            <div
              key={idx}
              className={`${config.bgColor} ${config.borderColor} border rounded-[var(--radius-sm)] p-[var(--space-sm)]`}
            >
              <div className="flex items-start gap-[var(--space-sm)]">
                <span className="text-sm">{config.icon}</span>
                <div className="flex-1 min-w-0">
                  <p className={`text-sm font-medium ${config.color}`}>
                    {adaptation.title}
                  </p>
                  <p className="text-xs text-muted mt-0.5">
                    {adaptation.description}
                  </p>
                  {adaptation.impact && (
                    <p className="text-xs text-foreground mt-1 font-mono">
                      {adaptation.impact}
                    </p>
                  )}
                </div>
              </div>
            </div>
          );
        })}
      </div>

      {isCollapsible && adaptations.length > 2 && (
        <button
          onClick={() => setExpanded(!expanded)}
          className="text-xs text-muted hover:text-foreground transition-colors"
        >
          {expanded ? '▲ Show less' : `▼ ${hiddenCount} more adaptation${hiddenCount > 1 ? 's' : ''}`}
        </button>
      )}
    </div>
  );
}

// Helper component for inline badges
interface AdaptationBadgeProps {
  type: 'recovery' | 'circaseptan' | 'genetic' | 'biomarker';
  label: string;
  onClick?: () => void;
}

export function AdaptationBadge({ type, label, onClick }: AdaptationBadgeProps) {
  const config = typeConfig[type] || typeConfig.recovery;

  return (
    <button
      onClick={onClick}
      className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs ${config.bgColor} ${config.color} ${config.borderColor} border transition-opacity hover:opacity-80`}
    >
      <span>{config.icon}</span>
      <span>{label}</span>
    </button>
  );
}
