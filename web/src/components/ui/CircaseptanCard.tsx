'use client';

interface CircaseptanCardProps {
  profile: {
    day_of_week: number;
    name: string;
    focus: string;
    training_emphasis?: string;
    nutrition_focus?: string;
    intervention_focus?: string;
    hormonal_notes?: string;
    immune_notes?: string;
  } | null;
  isCompact?: boolean;
}

const dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

const focusConfig: Record<string, { icon: string; color: string; label: string }> = {
  immune_reset: {
    icon: '🛡️',
    color: 'text-recovery-green',
    label: 'Immune Reset',
  },
  muscle_building: {
    icon: '💪',
    color: 'text-training',
    label: 'Muscle Building',
  },
  fat_oxidation: {
    icon: '🔥',
    color: 'text-nutrition',
    label: 'Fat Oxidation',
  },
  adaptation: {
    icon: '⚡',
    color: 'text-recovery-yellow',
    label: 'Hormetic Stress',
  },
  recovery: {
    icon: '🧘',
    color: 'text-interventions',
    label: 'Recovery',
  },
  gut_reset: {
    icon: '🌿',
    color: 'text-supplements',
    label: 'Gut Reset',
  },
};

export function CircaseptanCard({ profile, isCompact = false }: CircaseptanCardProps) {
  if (!profile) {
    return null;
  }

  const focusInfo = focusConfig[profile.focus] || {
    icon: '📅',
    color: 'text-foreground',
    label: profile.focus,
  };

  const dayIndex = profile.day_of_week;
  const dayName = dayNames[dayIndex] || 'Unknown';

  if (isCompact) {
    return (
      <div className="bg-card border border-[var(--surface-elevated)] rounded-[var(--radius-md)] p-[var(--space-md)]">
        <div className="flex items-center gap-[var(--space-sm)]">
          <span className="text-2xl">{focusInfo.icon}</span>
          <div>
            <p className={`font-semibold ${focusInfo.color}`}>{focusInfo.label}</p>
            <p className="text-xs text-muted">{dayName} • 7-Day Rhythm</p>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="bg-card border border-[var(--surface-elevated)] rounded-[var(--radius-md)] overflow-hidden">
      {/* Header */}
      <div className="flex items-center justify-between p-[var(--space-md)] border-b border-[var(--surface-elevated)]">
        <div className="flex items-center gap-[var(--space-sm)]">
          <span className="text-2xl">{focusInfo.icon}</span>
          <div>
            <p className={`font-semibold ${focusInfo.color}`}>{focusInfo.label}</p>
            <p className="text-xs text-muted">{dayName} • Circaseptan Rhythm</p>
          </div>
        </div>
        <div className="flex gap-1">
          {dayNames.map((_, idx) => (
            <div
              key={idx}
              className={`w-2 h-2 rounded-full transition-all ${
                idx === dayIndex
                  ? `${focusInfo.color.replace('text-', 'bg-')} scale-125`
                  : 'bg-[var(--surface-secondary)]'
              }`}
            />
          ))}
        </div>
      </div>

      {/* Content */}
      <div className="p-[var(--space-md)] space-y-[var(--space-sm)]">
        {/* Training */}
        {profile.training_emphasis && (
          <div className="flex items-start gap-[var(--space-sm)]">
            <span className="text-training text-sm">TRAINING</span>
            <p className="text-foreground text-sm flex-1">{profile.training_emphasis}</p>
          </div>
        )}

        {/* Nutrition */}
        {profile.nutrition_focus && (
          <div className="flex items-start gap-[var(--space-sm)]">
            <span className="text-nutrition text-sm">NUTRITION</span>
            <p className="text-foreground text-sm flex-1">{profile.nutrition_focus}</p>
          </div>
        )}

        {/* Interventions */}
        {profile.intervention_focus && (
          <div className="flex items-start gap-[var(--space-sm)]">
            <span className="text-interventions text-sm">INTERVENTIONS</span>
            <p className="text-foreground text-sm flex-1">{profile.intervention_focus}</p>
          </div>
        )}
      </div>

      {/* Notes */}
      {(profile.hormonal_notes || profile.immune_notes) && (
        <div className="px-[var(--space-md)] pb-[var(--space-md)]">
          <div className="bg-[var(--surface-secondary)] rounded-[var(--radius-sm)] p-[var(--space-sm)]">
            <p className="text-xs text-muted">
              {profile.hormonal_notes && (
                <span className="block">🧬 {profile.hormonal_notes}</span>
              )}
              {profile.immune_notes && (
                <span className="block mt-1">🛡️ {profile.immune_notes}</span>
              )}
            </p>
          </div>
        </div>
      )}
    </div>
  );
}
