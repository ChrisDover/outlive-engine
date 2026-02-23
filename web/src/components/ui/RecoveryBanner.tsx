interface RecoveryBannerProps {
  zone: "green" | "yellow" | "red";
  hrv?: number;
  rhr?: number;
  sleepScore?: number;
}

const zoneConfig = {
  green: {
    label: "Recovered",
    sublabel: "Ready to push",
    bg: "bg-recovery-green/10",
    border: "border-recovery-green/30",
    text: "text-recovery-green",
    dot: "bg-recovery-green",
  },
  yellow: {
    label: "Moderate",
    sublabel: "Train with awareness",
    bg: "bg-recovery-yellow/10",
    border: "border-recovery-yellow/30",
    text: "text-recovery-yellow",
    dot: "bg-recovery-yellow",
  },
  red: {
    label: "Suppressed",
    sublabel: "Prioritize recovery",
    bg: "bg-recovery-red/10",
    border: "border-recovery-red/30",
    text: "text-recovery-red",
    dot: "bg-recovery-red",
  },
};

export function RecoveryBanner({ zone, hrv, rhr, sleepScore }: RecoveryBannerProps) {
  const config = zoneConfig[zone];

  return (
    <div className={`${config.bg} ${config.border} border rounded-[var(--radius-md)] p-[var(--space-md)]`}>
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-[var(--space-sm)]">
          <div className={`w-3 h-3 rounded-full ${config.dot}`} />
          <div>
            <p className={`font-semibold ${config.text}`}>{config.label}</p>
            <p className="text-sm text-muted">{config.sublabel}</p>
          </div>
        </div>
        <div className="flex gap-[var(--space-lg)]">
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
        </div>
      </div>
    </div>
  );
}
