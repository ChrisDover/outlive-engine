"use client";

import { useEffect, useState } from "react";

interface Directive {
  id: string;
  text: string;
  category?: string | null;
  source?: string;
  created_at?: string;
}

const CATEGORIES = ["nutrition", "supplement", "training", "sleep", "lifestyle", "goal", "other"];

function catColor(cat?: string | null) {
  switch (cat) {
    case "nutrition": return "var(--nutrition)";
    case "supplement": return "var(--supplements)";
    case "training": return "var(--training)";
    case "sleep": return "var(--sleep)";
    case "goal": return "var(--green)";
    default: return "var(--text-tertiary)";
  }
}

export function ContextContent() {
  const [goals, setGoals] = useState("");
  const [directives, setDirectives] = useState<Directive[]>([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [savedAt, setSavedAt] = useState<string | null>(null);
  const [newText, setNewText] = useState("");
  const [newCat, setNewCat] = useState("nutrition");

  useEffect(() => {
    (async () => {
      try {
        const res = await fetch("/api/backend/context");
        if (res.ok) {
          const d = await res.json();
          setGoals(d.goals_md || "");
          setDirectives(Array.isArray(d.directives) ? d.directives : []);
        }
      } finally {
        setLoading(false);
      }
    })();
  }, []);

  async function saveGoals() {
    setSaving(true);
    try {
      const res = await fetch("/api/backend/context", {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ goals_md: goals }),
      });
      if (res.ok) setSavedAt(new Date().toLocaleTimeString());
    } finally {
      setSaving(false);
    }
  }

  async function addDirective() {
    const text = newText.trim();
    if (!text) return;
    const res = await fetch("/api/backend/context/directives", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ text, category: newCat }),
    });
    if (res.ok) {
      const d = await res.json();
      setDirectives(d.directives || []);
      setNewText("");
    }
  }

  async function removeDirective(id: string) {
    const res = await fetch(`/api/backend/context/directives/${id}`, { method: "DELETE" });
    if (res.ok) {
      const d = await res.json();
      setDirectives(d.directives || []);
    }
  }

  return (
    <div className="mx-auto max-w-3xl space-y-6">
      <div>
        <h1>Goals &amp; Context</h1>
        <p className="mt-0.5 text-sm text-muted">
          Write your goals and standing rules. The engine reasons against this for your daily plan and AI
          chat — and adds new directives automatically when you tell it things in chat.
        </p>
      </div>

      {/* Goals editor */}
      <div className="rounded-[var(--radius-lg)] border border-[var(--border)] bg-[var(--surface-card)] p-5">
        <div className="mb-2 flex items-center justify-between">
          <h2 className="text-sm font-semibold text-[var(--text-primary)]">Goals &amp; focus</h2>
          <div className="flex items-center gap-3">
            {savedAt && <span className="text-xs text-[var(--text-tertiary)]">Saved {savedAt}</span>}
            <button
              onClick={saveGoals}
              disabled={saving || loading}
              className="rounded-[var(--radius-md)] px-3 py-1.5 text-xs font-medium text-white transition-opacity disabled:opacity-50"
              style={{ background: "var(--accent)" }}
            >
              {saving ? "Saving…" : "Save"}
            </button>
          </div>
        </div>
        <textarea
          value={goals}
          onChange={(e) => setGoals(e.target.value)}
          disabled={loading}
          placeholder={"# My goals\n- Get ApoB under 80\n- Build lean mass while staying under 16% body fat\n- Train for a half marathon in October\n\n## Focus this month\n- Prioritize sleep consistency\n- Zone 2 cardio 3x/week"}
          rows={12}
          className="w-full resize-y rounded-[var(--radius-md)] bg-[var(--surface-secondary)] p-3 font-mono text-sm leading-relaxed text-[var(--text-primary)]"
        />
        <p className="mt-2 text-xs text-[var(--text-tertiary)]">Markdown supported. This is sent to the AI verbatim.</p>
      </div>

      {/* Directives */}
      <div className="rounded-[var(--radius-lg)] border border-[var(--border)] bg-[var(--surface-card)] p-5">
        <h2 className="mb-1 text-sm font-semibold text-[var(--text-primary)]">Directives</h2>
        <p className="mb-4 text-xs text-muted">
          Standing rules the engine must respect (meal timing, supplements, exclusions…). Items tagged{" "}
          <span style={{ color: "var(--accent)" }}>chat</span> were captured from your conversations.
        </p>

        <div className="space-y-2">
          {directives.length === 0 && !loading && (
            <p className="text-sm text-[var(--text-tertiary)]">No directives yet. Add one below, or just tell the chat.</p>
          )}
          {directives.map((d) => (
            <div
              key={d.id}
              className="flex items-center gap-3 rounded-[var(--radius-md)] border border-[var(--border)] bg-[var(--surface-secondary)] px-3 py-2"
            >
              <span
                className="rounded-full px-2 py-0.5 text-[10px] font-medium uppercase tracking-wide"
                style={{ color: catColor(d.category), border: `1px solid ${catColor(d.category)}33` }}
              >
                {d.category || "other"}
              </span>
              <span className="flex-1 text-sm text-[var(--text-primary)]">{d.text}</span>
              {d.source === "chat" && (
                <span className="text-[10px] font-medium" style={{ color: "var(--accent)" }}>chat</span>
              )}
              <button
                onClick={() => removeDirective(d.id)}
                className="shrink-0 rounded p-1 text-[var(--text-tertiary)] hover:text-[var(--recovery-red)]"
                aria-label="Remove directive"
              >
                <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round"><path d="M18 6 6 18M6 6l12 12" /></svg>
              </button>
            </div>
          ))}
        </div>

        {/* Add directive */}
        <div className="mt-4 flex flex-col gap-2 sm:flex-row">
          <select
            value={newCat}
            onChange={(e) => setNewCat(e.target.value)}
            className="rounded-[var(--radius-md)] bg-[var(--surface-secondary)] px-2 py-2 text-sm text-[var(--text-secondary)] sm:w-36"
          >
            {CATEGORIES.map((c) => (
              <option key={c} value={c}>{c}</option>
            ))}
          </select>
          <input
            value={newText}
            onChange={(e) => setNewText(e.target.value)}
            onKeyDown={(e) => e.key === "Enter" && addDirective()}
            placeholder="e.g. No food after 7pm"
            className="flex-1 rounded-[var(--radius-md)] bg-[var(--surface-secondary)] px-3 py-2 text-sm text-[var(--text-primary)]"
          />
          <button
            onClick={addDirective}
            disabled={!newText.trim()}
            className="rounded-[var(--radius-md)] border border-[var(--border-strong)] px-3.5 py-2 text-sm font-medium text-[var(--text-primary)] hover:bg-[var(--gray-300)] disabled:opacity-50"
          >
            Add
          </button>
        </div>
      </div>
    </div>
  );
}
