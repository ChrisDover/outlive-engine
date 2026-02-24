"use client";

import Link from "next/link";

interface WearableConnectCardProps {
  ouraConnected: boolean;
  whoopConnected: boolean;
}

export function WearableConnectCard({ ouraConnected, whoopConnected }: WearableConnectCardProps) {
  return (
    <div className="bg-card rounded-[var(--radius-md)] border-2 border-training/40 p-[var(--space-lg)] space-y-[var(--space-md)]">
      {/* Priority banner */}
      <div className="flex items-center gap-2">
        <span className="inline-block px-2 py-0.5 text-xs font-semibold bg-training/15 text-training rounded-full uppercase tracking-wide">
          Priority
        </span>
        <span className="text-xs text-muted">Step 1 of building your protocol</span>
      </div>

      <div>
        <h2 className="text-lg font-semibold text-foreground">
          Connect your wearable to unlock daily protocols
        </h2>
        <p className="text-sm text-muted mt-1">
          The engine uses real-time recovery, sleep, and HRV data to generate personalized
          training and nutrition plans. Without a wearable, protocols are based on defaults only.
        </p>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-2 gap-[var(--space-sm)]">
        {/* Oura */}
        {ouraConnected ? (
          <div className="flex items-center gap-[var(--space-sm)] p-[var(--space-sm)] rounded-[var(--radius-sm)] border border-recovery-green/30 bg-recovery-green/5">
            <span className="text-lg shrink-0">✓</span>
            <div>
              <p className="text-sm font-medium text-foreground">Oura Ring</p>
              <p className="text-xs text-recovery-green">Connected</p>
            </div>
          </div>
        ) : (
          <a
            href="/api/oauth/oura"
            className="flex items-center gap-[var(--space-sm)] p-[var(--space-sm)] rounded-[var(--radius-sm)] border border-training/30 bg-training/5 hover:bg-training/10 hover:border-training/50 transition-colors"
          >
            <span className="text-lg shrink-0">💍</span>
            <div>
              <p className="text-sm font-medium text-foreground">Connect Oura Ring</p>
              <p className="text-xs text-muted">Sleep, readiness, HRV</p>
            </div>
          </a>
        )}

        {/* Whoop */}
        {whoopConnected ? (
          <div className="flex items-center gap-[var(--space-sm)] p-[var(--space-sm)] rounded-[var(--radius-sm)] border border-recovery-green/30 bg-recovery-green/5">
            <span className="text-lg shrink-0">✓</span>
            <div>
              <p className="text-sm font-medium text-foreground">Whoop</p>
              <p className="text-xs text-recovery-green">Connected</p>
            </div>
          </div>
        ) : (
          <a
            href="/api/oauth/whoop"
            className="flex items-center gap-[var(--space-sm)] p-[var(--space-sm)] rounded-[var(--radius-sm)] border border-training/30 bg-training/5 hover:bg-training/10 hover:border-training/50 transition-colors"
          >
            <span className="text-lg shrink-0">⌚</span>
            <div>
              <p className="text-sm font-medium text-foreground">Connect Whoop</p>
              <p className="text-xs text-muted">Recovery, strain, sleep</p>
            </div>
          </a>
        )}

        {/* Apple Watch */}
        <div className="flex items-center gap-[var(--space-sm)] p-[var(--space-sm)] rounded-[var(--radius-sm)] border border-[var(--surface-elevated)] opacity-50">
          <span className="text-lg shrink-0">⌚</span>
          <div>
            <p className="text-sm font-medium text-foreground">Apple Watch</p>
            <p className="text-xs text-muted">Coming soon</p>
          </div>
        </div>

        {/* Manual */}
        <Link
          href="/dashboard/settings"
          className="flex items-center gap-[var(--space-sm)] p-[var(--space-sm)] rounded-[var(--radius-sm)] border border-[var(--surface-elevated)] hover:border-training/40 hover:bg-training/5 transition-colors"
        >
          <span className="text-lg shrink-0">✏️</span>
          <div>
            <p className="text-sm font-medium text-foreground">Manual Entry</p>
            <p className="text-xs text-muted">Enter metrics in settings</p>
          </div>
        </Link>
      </div>

      <p className="text-xs text-muted">
        Need to add API credentials first?{" "}
        <Link href="/dashboard/settings" className="text-training hover:underline">
          Configure them in Settings
        </Link>{" "}
        before connecting.
      </p>
    </div>
  );
}
