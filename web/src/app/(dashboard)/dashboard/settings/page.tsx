"use client";

import { signOut, useSession } from "next-auth/react";
import { SessionProvider } from "next-auth/react";
import { useState, useEffect } from "react";
import { WhoopImport } from "./WhoopImport";
import { DailyWhoopInput } from "./DailyWhoopInput";

function RestartServerButton() {
  const [restarting, setRestarting] = useState(false);

  async function restart() {
    setRestarting(true);
    try {
      await fetch("/api/settings/restart", { method: "POST" });
      // Wait for server to come back
      await new Promise((r) => setTimeout(r, 3000));
      window.location.reload();
    } catch {
      // Server killed itself — wait and reload
      await new Promise((r) => setTimeout(r, 3000));
      window.location.reload();
    }
  }

  return (
    <button
      onClick={restart}
      disabled={restarting}
      className="px-4 py-[var(--space-sm)] bg-[var(--surface-elevated)] text-foreground rounded-[var(--radius-sm)] font-medium hover:opacity-90 transition-opacity disabled:opacity-50 text-sm whitespace-nowrap"
    >
      {restarting ? "Restarting..." : "Restart Server"}
    </button>
  );
}

function APICredentials() {
  const [values, setValues] = useState<Record<string, string>>({
    OURA_CLIENT_ID: "",
    OURA_CLIENT_SECRET: "",
    WHOOP_CLIENT_ID: "",
    WHOOP_CLIENT_SECRET: "",
  });
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState<{ type: "success" | "error"; text: string } | null>(null);
  const [loaded, setLoaded] = useState(false);

  useEffect(() => {
    fetch("/api/settings/env")
      .then((r) => (r.ok ? r.json() : null))
      .then((data) => {
        if (data) {
          setValues((prev) => ({ ...prev, ...data }));
          setLoaded(true);
        }
      })
      .catch(() => null);
  }, []);

  async function save() {
    setSaving(true);
    setMessage(null);
    try {
      const resp = await fetch("/api/settings/env", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(values),
      });
      const data = await resp.json();
      if (resp.ok) {
        setMessage({ type: "success", text: `Saved ${data.saved?.join(", ")}. Hit "Restart Server" below to apply changes.` });
      } else {
        setMessage({ type: "error", text: data.error || "Failed to save" });
      }
    } catch {
      setMessage({ type: "error", text: "Could not reach settings API" });
    } finally {
      setSaving(false);
    }
  }

  const fields = [
    { key: "WHOOP_CLIENT_ID", label: "Whoop Client ID", secret: false, help: "From developer.whoop.com" },
    { key: "WHOOP_CLIENT_SECRET", label: "Whoop Client Secret", secret: true, help: "From developer.whoop.com" },
    { key: "OURA_CLIENT_ID", label: "Oura Client ID", secret: false, help: "From cloud.ouraring.com" },
    { key: "OURA_CLIENT_SECRET", label: "Oura Client Secret", secret: true, help: "From cloud.ouraring.com" },
  ];

  return (
    <div className="bg-card rounded-[var(--radius-md)] border border-[var(--surface-elevated)] p-[var(--space-lg)]">
      <h2 className="font-semibold text-foreground mb-1">API Credentials</h2>
      <p className="text-xs text-muted mb-[var(--space-md)]">
        Enter your OAuth credentials from the wearable developer portals. These are saved to your local <code>.env</code> file and never leave your machine.
      </p>

      <div className="space-y-[var(--space-sm)]">
        {fields.map((field) => (
          <div key={field.key}>
            <label className="block text-sm font-medium text-foreground mb-1">
              {field.label}
            </label>
            <input
              type={field.secret ? "password" : "text"}
              value={values[field.key] || ""}
              onChange={(e) => setValues((prev) => ({ ...prev, [field.key]: e.target.value }))}
              placeholder={field.help}
              className="w-full bg-[var(--surface-elevated)] rounded-[var(--radius-sm)] px-3 py-2 text-sm text-foreground placeholder:text-muted outline-none focus:ring-1 focus:ring-training/50 font-mono"
            />
          </div>
        ))}
      </div>

      {message && (
        <p className={`text-xs mt-[var(--space-sm)] ${message.type === "success" ? "text-recovery-green" : "text-recovery-red"}`}>
          {message.text}
        </p>
      )}

      <div className="flex gap-2 mt-[var(--space-md)]">
        <button
          onClick={save}
          disabled={saving}
          className="flex-1 py-[var(--space-sm)] bg-training text-white rounded-[var(--radius-sm)] font-medium hover:opacity-90 transition-opacity disabled:opacity-50"
        >
          {saving ? "Saving..." : "Save Credentials"}
        </button>
        <RestartServerButton />
      </div>
    </div>
  );
}

function WearableConnectionStatus() {
  const [status, setStatus] = useState<{ oura: boolean; whoop: boolean } | null>(null);
  const [disconnecting, setDisconnecting] = useState<string | null>(null);

  useEffect(() => {
    checkStatus();
  }, []);

  async function checkStatus() {
    try {
      const resp = await fetch("/api/oauth/status");
      if (resp.ok) {
        setStatus(await resp.json());
      }
    } catch {
      // Fall back to unknown state
    }
  }

  async function disconnect(provider: string) {
    setDisconnecting(provider);
    try {
      await fetch("/api/oauth/disconnect", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ provider }),
      });
      setStatus((prev) => prev ? { ...prev, [provider]: false } : null);
    } finally {
      setDisconnecting(null);
    }
  }

  return (
    <div className="bg-card rounded-[var(--radius-md)] border border-[var(--surface-elevated)] p-[var(--space-lg)]">
      <h2 className="font-semibold text-foreground mb-[var(--space-md)]">Connected Wearables</h2>
      <div className="space-y-[var(--space-sm)]">
        <div className="flex items-center justify-between">
          <span className="text-foreground">Oura Ring</span>
          {status?.oura ? (
            <button
              onClick={() => disconnect("oura")}
              disabled={disconnecting === "oura"}
              className="text-sm px-3 py-1 rounded-[var(--radius-sm)] bg-recovery-red/10 text-recovery-red hover:bg-recovery-red/20 transition-colors disabled:opacity-50"
            >
              {disconnecting === "oura" ? "Disconnecting..." : "Disconnect"}
            </button>
          ) : (
            <a
              href="/api/oauth/oura"
              className="text-sm px-3 py-1 rounded-[var(--radius-sm)] bg-training/10 text-training hover:bg-training/20 transition-colors"
            >
              Connect
            </a>
          )}
        </div>
        <div className="flex items-center justify-between">
          <span className="text-foreground">Whoop</span>
          {status?.whoop ? (
            <button
              onClick={() => disconnect("whoop")}
              disabled={disconnecting === "whoop"}
              className="text-sm px-3 py-1 rounded-[var(--radius-sm)] bg-recovery-red/10 text-recovery-red hover:bg-recovery-red/20 transition-colors disabled:opacity-50"
            >
              {disconnecting === "whoop" ? "Disconnecting..." : "Disconnect"}
            </button>
          ) : (
            <a
              href="/api/oauth/whoop"
              className="text-sm px-3 py-1 rounded-[var(--radius-sm)] bg-training/10 text-training hover:bg-training/20 transition-colors"
            >
              Connect
            </a>
          )}
        </div>
      </div>
    </div>
  );
}

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

        {/* API Credentials — must be configured before OAuth connect works */}
        <APICredentials />

        {/* Connected Wearables */}
        <WearableConnectionStatus />

        {/* Whoop Data Section */}
        <h2 className="text-xl font-semibold text-foreground mt-[var(--space-lg)]">
          Whoop Data
        </h2>

        {/* Daily Whoop Input */}
        <DailyWhoopInput />

        {/* Whoop Import */}
        <WhoopImport />

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
