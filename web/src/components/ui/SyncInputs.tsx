"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";

type Provider = "whoop" | "oura" | "withings";
const PROVIDERS: { key: Provider; label: string }[] = [
  { key: "whoop", label: "Whoop" },
  { key: "oura", label: "Oura" },
  { key: "withings", label: "Withings" },
];

interface SyncResult {
  synced: number;
  sources?: string[];
  errors?: string[];
}

export function SyncInputs() {
  const router = useRouter();
  const [status, setStatus] = useState<Record<Provider, boolean> | null>(null);
  const [syncing, setSyncing] = useState(false);
  const [result, setResult] = useState<SyncResult | null>(null);
  const [failed, setFailed] = useState(false);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        const res = await fetch("/api/oauth/status");
        const json = res.ok ? await res.json() : {};
        if (!cancelled) {
          setStatus({
            whoop: !!json.whoop,
            oura: !!json.oura,
            withings: !!json.withings,
          });
        }
      } catch {
        if (!cancelled) setStatus({ whoop: false, oura: false, withings: false });
      }
    })();
    return () => {
      cancelled = true;
    };
  }, []);

  const connected = PROVIDERS.filter((p) => status?.[p.key]);
  const anyConnected = connected.length > 0;

  async function syncNow() {
    setSyncing(true);
    setResult(null);
    setFailed(false);
    try {
      const res = await fetch("/api/wearables/sync", { method: "POST" });
      if (!res.ok) throw new Error();
      const json: SyncResult = await res.json();
      setResult(json);
      // Pull fresh server data into the charts/score.
      router.refresh();
    } catch {
      setFailed(true);
    } finally {
      setSyncing(false);
    }
  }

  return (
    <div className="rounded-[var(--radius-lg)] border border-[var(--border)] bg-[var(--surface-card)] p-4 md:px-5">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="flex items-center gap-3">
          <div
            className="flex h-9 w-9 shrink-0 items-center justify-center rounded-[var(--radius-md)]"
            style={{ background: "var(--gray-300)" }}
          >
            <svg
              width="18"
              height="18"
              viewBox="0 0 24 24"
              fill="none"
              stroke="var(--accent)"
              strokeWidth="1.8"
              strokeLinecap="round"
              strokeLinejoin="round"
              className={syncing ? "animate-spin" : ""}
            >
              <path d="M21 12a9 9 0 0 1-9 9 9 9 0 0 1-6.7-3M3 12a9 9 0 0 1 9-9 9 9 0 0 1 6.7 3" />
              <path d="M21 3v5h-5M3 21v-5h5" />
            </svg>
          </div>
          <div>
            <div className="text-sm font-semibold text-[var(--text-primary)]">
              {anyConnected ? "Sync your data" : "Connect a device"}
            </div>
            <div className="mt-1 flex flex-wrap items-center gap-x-3 gap-y-1">
              {status === null ? (
                <span className="text-xs text-[var(--text-tertiary)]">Checking connections…</span>
              ) : anyConnected ? (
                PROVIDERS.map((p) => {
                  const on = status[p.key];
                  return (
                    <span
                      key={p.key}
                      className="inline-flex items-center gap-1.5 text-xs"
                      style={{ color: on ? "var(--text-secondary)" : "var(--text-tertiary)" }}
                    >
                      <span
                        className="h-1.5 w-1.5 rounded-full"
                        style={{ background: on ? "var(--green)" : "var(--gray-500)" }}
                      />
                      {p.label}
                      {!on && (
                        <Link href="/dashboard/settings" className="ml-0.5 text-[var(--accent)]">
                          connect
                        </Link>
                      )}
                    </span>
                  );
                })
              ) : (
                <span className="text-xs text-[var(--text-tertiary)]">
                  Connect Whoop, Oura, or Withings in{" "}
                  <Link href="/dashboard/settings" className="text-[var(--accent)]">
                    Settings
                  </Link>{" "}
                  to sync your metrics.
                </span>
              )}
            </div>
          </div>
        </div>

        <div className="flex shrink-0 items-center gap-3">
          <Link
            href="/dashboard/settings"
            className="text-xs font-medium text-[var(--text-tertiary)] hover:text-[var(--text-secondary)]"
          >
            Import file →
          </Link>
          {anyConnected && (
            <button
              onClick={syncNow}
              disabled={syncing}
              className="rounded-[var(--radius-md)] px-3.5 py-2 text-sm font-medium text-white transition-opacity disabled:opacity-50"
              style={{ background: "var(--accent)" }}
            >
              {syncing ? "Syncing…" : "Sync now"}
            </button>
          )}
        </div>
      </div>

      {/* Result / errors */}
      {(result || failed) && (
        <div className="mt-3 border-t border-[var(--border)] pt-3 text-xs">
          {failed ? (
            <p className="text-[var(--recovery-red)]">Sync request failed. Please try again.</p>
          ) : result ? (
            <div className="space-y-1">
              {result.synced > 0 ? (
                <p className="text-[var(--green)]">
                  ✓ Synced {result.synced} source{result.synced !== 1 ? "s" : ""}
                  {result.sources?.length ? ` — ${result.sources.join(", ")}` : ""}
                </p>
              ) : !result.errors?.length ? (
                <p className="text-[var(--text-tertiary)]">No new data available to sync right now.</p>
              ) : null}
              {result.errors?.map((e, i) => (
                <p key={i} className="text-[var(--amber)]">
                  {e}
                </p>
              ))}
            </div>
          ) : null}
        </div>
      )}
    </div>
  );
}
