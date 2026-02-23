"use client";

import { signOut, useSession } from "next-auth/react";
import { SessionProvider } from "next-auth/react";

function SettingsContent() {
  const { data: session } = useSession();

  return (
    <div className="max-w-4xl mx-auto">
      <h1 className="text-2xl font-bold text-foreground mb-[var(--space-lg)]">Settings</h1>

      <div className="space-y-[var(--space-md)]">
        {/* Profile */}
        <div className="bg-card rounded-[var(--radius-md)] border border-[var(--surface-elevated)] p-[var(--space-lg)]">
          <h2 className="font-semibold text-foreground mb-[var(--space-md)]">Profile</h2>
          <div className="space-y-[var(--space-sm)] text-sm">
            <div className="flex justify-between">
              <span className="text-muted">Email</span>
              <span className="text-foreground">{session?.user?.email || "—"}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-muted">Name</span>
              <span className="text-foreground">{session?.user?.name || "—"}</span>
            </div>
          </div>
        </div>

        {/* Connected Wearables */}
        <div className="bg-card rounded-[var(--radius-md)] border border-[var(--surface-elevated)] p-[var(--space-lg)]">
          <h2 className="font-semibold text-foreground mb-[var(--space-md)]">Connected Wearables</h2>
          <div className="space-y-[var(--space-sm)]">
            <div className="flex items-center justify-between">
              <span className="text-foreground">Oura Ring</span>
              <span className="text-sm text-muted">Not connected</span>
            </div>
            <div className="flex items-center justify-between">
              <span className="text-foreground">Whoop</span>
              <span className="text-sm text-muted">Not connected</span>
            </div>
          </div>
        </div>

        {/* Sign Out */}
        <button
          onClick={() => signOut({ callbackUrl: "/login" })}
          className="w-full py-[var(--space-sm)] bg-recovery-red text-white rounded-[var(--radius-sm)] font-medium hover:opacity-90 transition-opacity"
        >
          Sign Out
        </button>
      </div>
    </div>
  );
}

export default function SettingsPage() {
  return (
    <SessionProvider>
      <SettingsContent />
    </SessionProvider>
  );
}
