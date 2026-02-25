'use client';

interface QuickStatsProps {
  hrv?: number;
  sleepHours?: number;
  recoveryScore?: number;
  streak?: number;
  weeklyAdherence?: number;
}

export function QuickStats({
  hrv,
  sleepHours,
  recoveryScore,
  streak = 0,
  weeklyAdherence = 0,
}: QuickStatsProps) {
  const stats = [
    {
      label: 'HRV',
      value: hrv ? `${hrv}` : '--',
      unit: 'ms',
      color: hrv
        ? hrv >= 55
          ? 'text-[var(--recovery-green)]'
          : hrv >= 40
          ? 'text-[var(--recovery-yellow)]'
          : 'text-[var(--recovery-red)]'
        : 'text-muted',
    },
    {
      label: 'SLEEP',
      value: sleepHours ? sleepHours.toFixed(1) : '--',
      unit: 'hrs',
      color: sleepHours
        ? sleepHours >= 7
          ? 'text-[var(--recovery-green)]'
          : sleepHours >= 6
          ? 'text-[var(--recovery-yellow)]'
          : 'text-[var(--recovery-red)]'
        : 'text-muted',
    },
    {
      label: 'RECOVERY',
      value: recoveryScore ? `${recoveryScore}` : '--',
      unit: '%',
      color: recoveryScore
        ? recoveryScore >= 70
          ? 'text-[var(--recovery-green)]'
          : recoveryScore >= 50
          ? 'text-[var(--recovery-yellow)]'
          : 'text-[var(--recovery-red)]'
        : 'text-muted',
    },
    {
      label: 'STREAK',
      value: streak.toString(),
      unit: 'days',
      color: streak > 7 ? 'text-[var(--recovery-green)]' : streak > 3 ? 'text-[var(--recovery-yellow)]' : 'text-muted',
    },
    {
      label: 'THIS WEEK',
      value: weeklyAdherence ? `${weeklyAdherence}` : '--',
      unit: '%',
      color: weeklyAdherence
        ? weeklyAdherence >= 80
          ? 'text-[var(--recovery-green)]'
          : weeklyAdherence >= 60
          ? 'text-[var(--recovery-yellow)]'
          : 'text-[var(--recovery-red)]'
        : 'text-muted',
    },
  ];

  return (
    <div className="grid grid-cols-5 gap-[var(--space-xs)] bg-card border border-[var(--surface-elevated)] p-[var(--space-sm)]">
      {stats.map((stat) => (
        <div key={stat.label} className="text-center">
          <div className={`text-lg font-semibold ${stat.color}`}>
            {stat.value}
            <span className="text-xs text-muted ml-1">{stat.unit}</span>
          </div>
          <div className="text-xs text-muted">{stat.label}</div>
        </div>
      ))}
    </div>
  );
}
