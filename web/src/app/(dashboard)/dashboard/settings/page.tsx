"use client";

import { signOut, useSession } from "next-auth/react";
import { SessionProvider } from "next-auth/react";
import { useState, useEffect, Suspense } from "react";
import { useSearchParams } from "next/navigation";
import { WhoopImport } from "./WhoopImport";
import { DailyWhoopInput } from "./DailyWhoopInput";
import { DataImport } from "./DataImport";
import { ExternalAIWarning } from "@/components/ui/ExternalAIWarning";

function StatusBanner() {
  const params = useSearchParams();
  const err = params.get("error");
  const connected = params.get("connected");

  if (connected) {
    const name = connected.charAt(0).toUpperCase() + connected.slice(1);
    return (
      <div className="mb-[var(--space-md)] rounded-[var(--radius-md)] border border-[var(--recovery-green)] bg-[color-mix(in_srgb,var(--recovery-green)_8%,transparent)] p-[var(--space-sm)] text-sm text-[var(--recovery-green)]">
        ✓ {name} connected.
      </div>
    );
  }
  if (!err) return null;

  const provider = err.split("_")[0];
  const name = provider.charAt(0).toUpperCase() + provider.slice(1);
  const message = err.endsWith("not_configured")
    ? `${name} isn't configured yet. Add its Client ID and Secret under API Credentials below, then restart the server.`
    : `Couldn't connect ${name}. Please try again — and double-check the credentials and redirect URI in API Credentials.`;

  return (
    <div className="mb-[var(--space-md)] rounded-[var(--radius-md)] border border-[var(--amber)] bg-[color-mix(in_srgb,var(--amber)_8%,transparent)] p-[var(--space-sm)] text-sm text-[var(--amber)]">
      {message}
    </div>
  );
}

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
    WITHINGS_CLIENT_ID: "",
    WITHINGS_CLIENT_SECRET: "",
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
    { key: "OURA_CLIENT_ID", label: "Oura Client ID", secret: false, help: "From cloud.ouraring.com" },
    { key: "OURA_CLIENT_SECRET", label: "Oura Client Secret", secret: true, help: "From cloud.ouraring.com" },
    { key: "WHOOP_CLIENT_ID", label: "Whoop Client ID", secret: false, help: "From developer.whoop.com" },
    { key: "WHOOP_CLIENT_SECRET", label: "Whoop Client Secret", secret: true, help: "From developer.whoop.com" },
    { key: "WITHINGS_CLIENT_ID", label: "Withings Client ID", secret: false, help: "From developer.withings.com" },
    { key: "WITHINGS_CLIENT_SECRET", label: "Withings Client Secret", secret: true, help: "From developer.withings.com" },
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

interface ConnectionInfo {
  provider: string;
  connected: boolean;
  last_sync: string | null;
  token_expired: boolean;
}

interface SyncStatus {
  connections: Record<string, ConnectionInfo>;
}

function WearableConnectionStatus() {
  const [status, setStatus] = useState<{ oura: boolean; whoop: boolean; withings: boolean } | null>(null);
  const [syncStatus, setSyncStatus] = useState<SyncStatus | null>(null);
  const [disconnecting, setDisconnecting] = useState<string | null>(null);
  const [syncing, setSyncing] = useState<string | null>(null);
  const [syncMessage, setSyncMessage] = useState<{ provider: string; type: "success" | "error"; text: string } | null>(null);

  useEffect(() => {
    checkStatus();
    checkSyncStatus();
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

  async function checkSyncStatus() {
    try {
      const resp = await fetch("/api/wearables/sync/status");
      if (resp.ok) {
        setSyncStatus(await resp.json());
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
      checkSyncStatus();
    } finally {
      setDisconnecting(null);
    }
  }

  async function syncProvider(provider: string) {
    setSyncing(provider);
    setSyncMessage(null);
    try {
      const resp = await fetch(`/api/wearables/sync/${provider}`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ days: 7 }),
      });
      const data = await resp.json();
      if (data.success) {
        setSyncMessage({
          provider,
          type: "success",
          text: `Synced ${data.days_synced} days`,
        });
        checkSyncStatus();
      } else {
        setSyncMessage({
          provider,
          type: "error",
          text: data.error || "Sync failed",
        });
      }
    } catch {
      setSyncMessage({
        provider,
        type: "error",
        text: "Could not reach sync API",
      });
    } finally {
      setSyncing(null);
    }
  }

  function formatLastSync(dateStr: string | null | undefined): string {
    if (!dateStr) return "Never";
    const date = new Date(dateStr);
    const now = new Date();
    const diffMs = now.getTime() - date.getTime();
    const diffHours = Math.floor(diffMs / (1000 * 60 * 60));
    const diffDays = Math.floor(diffHours / 24);

    if (diffHours < 1) return "Just now";
    if (diffHours < 24) return `${diffHours}h ago`;
    if (diffDays === 1) return "Yesterday";
    return `${diffDays}d ago`;
  }

  const wearables = [
    { key: "oura", name: "Oura Ring", icon: "💍" },
    { key: "whoop", name: "Whoop", icon: "⌚" },
    { key: "withings", name: "Withings", icon: "⚖️" },
  ];

  return (
    <div className="bg-card rounded-[var(--radius-md)] border border-[var(--surface-elevated)] p-[var(--space-lg)]">
      <h2 className="font-semibold text-foreground mb-[var(--space-md)]">Connected Wearables</h2>
      <div className="space-y-[var(--space-md)]">
        {wearables.map(({ key, name, icon }) => {
          const isConnected = status?.[key as keyof typeof status];
          const connInfo = syncStatus?.connections?.[key];
          const lastSync = connInfo?.last_sync;
          const tokenExpired = connInfo?.token_expired;

          return (
            <div
              key={key}
              className="flex items-center justify-between p-[var(--space-sm)] rounded-[var(--radius-sm)] bg-[var(--surface-elevated)]"
            >
              <div className="flex items-center gap-[var(--space-sm)]">
                <span className="text-lg">{icon}</span>
                <div>
                  <span className="text-foreground font-medium">{name}</span>
                  {isConnected && (
                    <div className="text-xs text-muted">
                      {tokenExpired ? (
                        <span className="text-recovery-yellow">Token expired</span>
                      ) : (
                        <span>Last sync: {formatLastSync(lastSync)}</span>
                      )}
                    </div>
                  )}
                  {syncMessage?.provider === key && (
                    <div
                      className={`text-xs ${
                        syncMessage.type === "success"
                          ? "text-recovery-green"
                          : "text-recovery-red"
                      }`}
                    >
                      {syncMessage.text}
                    </div>
                  )}
                </div>
              </div>
              <div className="flex items-center gap-2">
                {isConnected ? (
                  <>
                    <button
                      onClick={() => syncProvider(key)}
                      disabled={syncing === key}
                      className="text-sm px-3 py-1 rounded-[var(--radius-sm)] bg-training/10 text-training hover:bg-training/20 transition-colors disabled:opacity-50"
                    >
                      {syncing === key ? "Syncing..." : "Sync"}
                    </button>
                    <button
                      onClick={() => disconnect(key)}
                      disabled={disconnecting === key}
                      className="text-sm px-3 py-1 rounded-[var(--radius-sm)] bg-recovery-red/10 text-recovery-red hover:bg-recovery-red/20 transition-colors disabled:opacity-50"
                    >
                      {disconnecting === key ? "..." : "✕"}
                    </button>
                  </>
                ) : (
                  <a
                    href={`/api/oauth/${key}`}
                    className="text-sm px-3 py-1 rounded-[var(--radius-sm)] bg-training/10 text-training hover:bg-training/20 transition-colors"
                  >
                    Connect
                  </a>
                )}
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}

function AIConfiguration() {
  const [prefs, setPrefs] = useState<{
    use_local_only: boolean;
    external_provider: string | null;
    has_external_api_key: boolean;
    acknowledged_external_warning: boolean;
    preferred_model: string;
  } | null>(null);
  const [status, setStatus] = useState<{
    local_available: boolean;
    local_model: string | null;
    external_configured: boolean;
    current_mode: string;
  } | null>(null);
  const [showWarning, setShowWarning] = useState(false);
  const [apiKey, setApiKey] = useState("");
  const [saving, setSaving] = useState(false);
  const [testing, setTesting] = useState(false);
  const [testResult, setTestResult] = useState<{
    local: { available?: boolean; model?: string; error?: string };
    external: { available?: boolean; provider?: string; error?: string };
  } | null>(null);

  useEffect(() => {
    loadPreferences();
    loadStatus();
  }, []);

  async function loadPreferences() {
    try {
      const resp = await fetch("/api/backend/ai/preferences");
      if (resp.ok) {
        setPrefs(await resp.json());
      }
    } catch {
      // Ignore
    }
  }

  async function loadStatus() {
    try {
      const resp = await fetch("/api/backend/ai/status");
      if (resp.ok) {
        setStatus(await resp.json());
      }
    } catch {
      // Ignore
    }
  }

  async function handleAcknowledge() {
    try {
      const resp = await fetch("/api/backend/ai/acknowledge-external", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ acknowledged: true }),
      });
      if (resp.ok) {
        await loadPreferences();
        setShowWarning(false);
      }
    } catch {
      // Ignore
    }
  }

  async function updatePreferences(update: Record<string, unknown>) {
    setSaving(true);
    try {
      const resp = await fetch("/api/backend/ai/preferences", {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(update),
      });
      if (resp.ok) {
        await loadPreferences();
        await loadStatus();
      }
    } catch {
      // Ignore
    } finally {
      setSaving(false);
    }
  }

  async function testConnection() {
    setTesting(true);
    setTestResult(null);
    try {
      const resp = await fetch("/api/backend/ai/test-connection", {
        method: "POST",
      });
      if (resp.ok) {
        setTestResult(await resp.json());
      }
    } catch {
      // Ignore
    } finally {
      setTesting(false);
    }
  }

  function handleToggleExternal() {
    if (prefs?.use_local_only) {
      // Switching to external
      if (!prefs.acknowledged_external_warning) {
        setShowWarning(true);
      } else {
        updatePreferences({ use_local_only: false });
      }
    } else {
      // Switching to local
      updatePreferences({ use_local_only: true });
    }
  }

  return (
    <>
      <div className="bg-card rounded-[var(--radius-md)] border border-[var(--surface-elevated)] p-[var(--space-lg)]">
        <div className="flex items-center justify-between mb-[var(--space-md)]">
          <h2 className="font-semibold text-foreground">AI Configuration</h2>
          <span className={`text-xs px-2 py-1 rounded-full ${
            status?.current_mode === "local"
              ? "bg-recovery-green/10 text-recovery-green"
              : "bg-recovery-yellow/10 text-recovery-yellow"
          }`}>
            {status?.current_mode === "local" ? "🔒 Local AI" : "☁️ External AI"}
          </span>
        </div>

        {/* Status */}
        <div className="space-y-[var(--space-sm)] mb-[var(--space-md)]">
          <div className="flex items-center justify-between p-[var(--space-sm)] rounded-[var(--radius-sm)] bg-[var(--surface-elevated)]">
            <div className="flex items-center gap-[var(--space-sm)]">
              <span className="text-lg">🦙</span>
              <div>
                <span className="text-foreground font-medium">Local (Ollama)</span>
                <div className="text-xs text-muted">
                  {status?.local_available
                    ? `Model: ${status.local_model}`
                    : "Not available"}
                </div>
              </div>
            </div>
            <span className={`w-3 h-3 rounded-full ${
              status?.local_available ? "bg-recovery-green" : "bg-recovery-red"
            }`} />
          </div>
        </div>

        {/* Local/External Toggle */}
        <div className="space-y-[var(--space-sm)]">
          <label className="flex items-center justify-between cursor-pointer">
            <span className="text-foreground">Use local AI only (recommended)</span>
            <button
              onClick={handleToggleExternal}
              disabled={saving}
              className={`relative w-12 h-6 rounded-full transition-colors ${
                prefs?.use_local_only ? "bg-recovery-green" : "bg-recovery-yellow"
              }`}
            >
              <span className={`absolute top-1 w-4 h-4 rounded-full bg-white transition-transform ${
                prefs?.use_local_only ? "left-1" : "left-7"
              }`} />
            </button>
          </label>
          <p className="text-xs text-muted">
            {prefs?.use_local_only
              ? "Your health data never leaves your machine."
              : "Health data may be sent to external AI providers."}
          </p>
        </div>

        {/* External AI Config (when enabled) */}
        {!prefs?.use_local_only && (
          <div className="mt-[var(--space-md)] pt-[var(--space-md)] border-t border-[var(--surface-elevated)] space-y-[var(--space-sm)]">
            <div>
              <label className="block text-sm font-medium text-foreground mb-1">
                Provider
              </label>
              <select
                value={prefs?.external_provider || "anthropic"}
                onChange={(e) => updatePreferences({ external_provider: e.target.value })}
                className="w-full bg-[var(--surface-elevated)] rounded-[var(--radius-sm)] px-3 py-2 text-sm text-foreground outline-none focus:ring-1 focus:ring-training/50"
              >
                <option value="anthropic">Anthropic (Claude)</option>
                <option value="openai">OpenAI (GPT)</option>
              </select>
            </div>
            <div>
              <label className="block text-sm font-medium text-foreground mb-1">
                API Key
              </label>
              <div className="flex gap-2">
                <input
                  type="password"
                  value={apiKey}
                  onChange={(e) => setApiKey(e.target.value)}
                  placeholder={prefs?.has_external_api_key ? "••••••••••••" : "Enter API key"}
                  className="flex-1 bg-[var(--surface-elevated)] rounded-[var(--radius-sm)] px-3 py-2 text-sm text-foreground placeholder:text-muted outline-none focus:ring-1 focus:ring-training/50 font-mono"
                />
                <button
                  onClick={() => {
                    if (apiKey) {
                      updatePreferences({ external_api_key: apiKey });
                      setApiKey("");
                    }
                  }}
                  disabled={!apiKey || saving}
                  className="px-4 py-2 bg-training text-white rounded-[var(--radius-sm)] text-sm font-medium hover:opacity-90 transition-opacity disabled:opacity-50"
                >
                  Save
                </button>
              </div>
            </div>
          </div>
        )}

        {/* Test Connection */}
        <div className="mt-[var(--space-md)] pt-[var(--space-md)] border-t border-[var(--surface-elevated)]">
          <button
            onClick={testConnection}
            disabled={testing}
            className="w-full py-[var(--space-sm)] bg-[var(--surface-elevated)] text-foreground rounded-[var(--radius-sm)] font-medium hover:opacity-90 transition-opacity disabled:opacity-50"
          >
            {testing ? "Testing..." : "Test Connection"}
          </button>
          {testResult && (
            <div className="mt-[var(--space-sm)] text-xs space-y-1">
              <p className={testResult.local.available ? "text-recovery-green" : "text-recovery-red"}>
                Local: {testResult.local.available ? `✓ ${testResult.local.model}` : `✗ ${testResult.local.error}`}
              </p>
              {testResult.external.provider && (
                <p className={testResult.external.available ? "text-recovery-green" : "text-recovery-red"}>
                  External: {testResult.external.available ? `✓ ${testResult.external.provider}` : `✗ ${testResult.external.error}`}
                </p>
              )}
            </div>
          )}
        </div>
      </div>

      <ExternalAIWarning
        isOpen={showWarning}
        onClose={() => setShowWarning(false)}
        onAcknowledge={handleAcknowledge}
      />
    </>
  );
}

function SettingsContent() {
  const { data: session } = useSession();

  return (
    <div className="max-w-4xl mx-auto">
      <h1 className="text-2xl font-bold text-foreground mb-[var(--space-lg)]">Settings</h1>

      <Suspense fallback={null}>
        <StatusBanner />
      </Suspense>

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

        {/* AI Configuration */}
        <AIConfiguration />

        {/* API Credentials — must be configured before OAuth connect works */}
        <APICredentials />

        {/* Connected Wearables */}
        <WearableConnectionStatus />

        {/* Import from Apple Health / CSV — no device API required */}
        <DataImport />

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
