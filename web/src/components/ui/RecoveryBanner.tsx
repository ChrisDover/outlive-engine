interface RecoveryBannerProps {
  zone: "green" | "yellow" | "red";
  recoveryScore?: number;
  hrv?: number;
  rhr?: number;
  sleepScore?: number;
  sleepHours?: number;
  circaseptanDay?: {
    name: string;
    focus: string;
    dayOfWeek: number;
  };
  adaptations?: string[];
}

const zoneConfig = {
  green: {
    label: "GREEN",
    sublabel: "Ready to push",
    percentage: "67-100%",
    bg: "bg-recovery-green/10",
    border: "border-recovery-green/30",
    text: "text-recovery-green",
    dot: "bg-recovery-green",
    glow: "shadow-recovery-green/20",
  },
  yellow: {
    label: "YELLOW",
    sublabel: "Train with awareness",
    percentage: "34-66%",
    bg: "bg-recovery-yellow/10",
    border: "border-recovery-yellow/30",
    text: "text-recovery-yellow",
    dot: "bg-recovery-yellow",
    glow: "shadow-recovery-yellow/20",
  },
  red: {
    label: "RED",
    sublabel: "Prioritize recovery",
    percentage: "0-33%",
    bg: "bg-recovery-red/10",
    border: "border-recovery-red/30",
    text: "text-recovery-red",
    dot: "bg-recovery-red",
    glow: "shadow-recovery-red/20",
  },
};

const focusIcons: Record<string, string> = {
  immune_reset: "🛡️",
  muscle_building: "💪",
  fat_oxidation: "🔥",
  adaptation: "⚡",
  recovery: "🧘",
  gut_reset: "🌿",
};

export function RecoveryBanner({
  zone,
  recoveryScore,
  hrv,
  rhr,
  sleepScore,
  sleepHours,
  circaseptanDay,
  adaptations,
}: RecoveryBannerProps) {
  const config = zoneConfig[zone];

  return (
    <div className={`${config.bg} ${config.border} border rounded-[var(--radius-md)] p-[var(--space-md)] shadow-sm`}>
      {/* Main Recovery Section */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-[var(--space-md)]">
          {/* Zone Indicator */}
          <div className="flex items-center gap-[var(--space-sm)]">
            <div className={`w-4 h-4 rounded-full ${config.dot} animate-pulse`} />
            <div>
              <div className="flex items-center gap-[var(--space-xs)]">
                <p className={`font-bold text-lg ${config.text}`}>{config.label}</p>
                {recoveryScore != null && (
                  <span className={`font-mono text-sm ${config.text}`}>
                    {recoveryScore}%
                  </span>
                )}
              </div>
              <p className="text-sm text-muted">{config.sublabel}</p>
            </div>
          </div>

          {/* Circaseptan Badge */}
          {circaseptanDay?.name && (
            <div className="hidden sm:flex items-center gap-[var(--space-xs)] px-[var(--space-sm)] py-1 rounded-full bg-[var(--surface-elevated)] border border-[var(--surface-secondary)]">
              <span>{focusIcons[circaseptanDay.focus] || "📅"}</span>
              <span className="text-xs text-muted">{circaseptanDay.name.split(" - ")[0]}</span>
              {circaseptanDay.name.split(" - ")[1] && (
                <span className="text-xs text-foreground font-medium">{circaseptanDay.name.split(" - ")[1]}</span>
              )}
            </div>
          )}
        </div>

        {/* Metrics */}
        <div className="flex gap-[var(--space-md)]">
          {hrv != null && (
            <div className="text-center">
              <p className="text-lg font-mono font-semibold text-foreground">{hrv}</p>
              <p className="text-xs text-muted">HRV</p>
            </div>
          )}
          {rhr != null && (
            <div className="text-center">
              <p className="text-lg font-mono font-semibold text-foreground">{rhr}</p>
              <p className="text-xs text-muted">RHR</p>
            </div>
          )}
          {sleepScore != null && (
            <div className="text-center">
              <p className="text-lg font-mono font-semibold text-foreground">{sleepScore}</p>
              <p className="text-xs text-muted">Sleep</p>
            </div>
          )}
          {sleepHours != null && (
            <div className="text-center hidden sm:block">
              <p className="text-lg font-mono font-semibold text-foreground">{sleepHours.toFixed(1)}h</p>
              <p className="text-xs text-muted">Duration</p>
            </div>
          )}
        </div>
      </div>

      {/* Adaptations Row */}
      {adaptations && adaptations.length > 0 && (
        <div className="mt-[var(--space-sm)] pt-[var(--space-sm)] border-t border-[var(--surface-elevated)]">
          <div className="flex flex-wrap gap-[var(--space-xs)]">
            {adaptations.map((adaptation, idx) => (
              <span
                key={idx}
                className={`text-xs px-2 py-0.5 rounded-full ${config.bg} ${config.text} border ${config.border}`}
              >
                {adaptation}
              </span>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
