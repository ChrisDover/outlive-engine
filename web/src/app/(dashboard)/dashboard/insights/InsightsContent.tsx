"use client";

import { useEffect, useRef, useState } from "react";
import { Markdown } from "@/components/ui/Markdown";

interface Message {
  role: "user" | "assistant" | "memory";
  content: string;
  model?: string | null;
  error?: boolean;
  streaming?: boolean;
}

// Cheap gate so we only run the (LLM-backed) extraction on directive-like
// messages, not every question.
const DIRECTIVE_CUE = /\b(from now on|remember|let'?s|i'?m going to|switch to|stop|no more|cut ?off|after \d|before \d|every ?day|daily|going forward|add\b|i want to|i'?ll|prefer|avoid|no longer|going to)\b/i;

const SUGGESTIONS = [
  "What should I prioritize to improve my recovery?",
  "Summarize my latest bloodwork in plain English.",
  "Any red flags across my recent metrics?",
  "What's one experiment I should run next?",
];

const TOGGLES = [
  { key: "bloodwork", label: "Bloodwork" },
  { key: "wearables", label: "Wearables" },
  { key: "genomics", label: "Genomics" },
] as const;

type ToggleKey = (typeof TOGGLES)[number]["key"];

function ThinkingDots() {
  return (
    <span className="inline-flex items-center gap-1">
      {[0, 1, 2].map((i) => (
        <span
          key={i}
          className="h-1.5 w-1.5 rounded-full bg-[var(--text-tertiary)] animate-pulse"
          style={{ animationDelay: `${i * 160}ms` }}
        />
      ))}
    </span>
  );
}

function Avatar({ role }: { role: "user" | "assistant" }) {
  if (role === "assistant") {
    return (
      <div
        className="flex h-7 w-7 shrink-0 items-center justify-center rounded-[var(--radius-md)]"
        style={{ background: "linear-gradient(135deg, var(--accent), #7c3aed)" }}
      >
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="#fff" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round">
          <path d="M3 13h4l3 7 4-16 3 9h4" />
        </svg>
      </div>
    );
  }
  return (
    <div className="flex h-7 w-7 shrink-0 items-center justify-center rounded-[var(--radius-md)] text-xs font-semibold text-white" style={{ background: "var(--gray-500)" }}>
      You
    </div>
  );
}

export function InsightsContent() {
  const [messages, setMessages] = useState<Message[]>([]);
  const [input, setInput] = useState("");
  const [loading, setLoading] = useState(false);
  const [context, setContext] = useState<Record<ToggleKey, boolean>>({
    bloodwork: true,
    wearables: true,
    genomics: true,
  });

  const scrollRef = useRef<HTMLDivElement>(null);
  const taRef = useRef<HTMLTextAreaElement>(null);

  useEffect(() => {
    scrollRef.current?.scrollTo({ top: scrollRef.current.scrollHeight, behavior: "smooth" });
  }, [messages, loading]);

  async function send(text: string) {
    const question = text.trim();
    if (!question || loading) return;

    setMessages((m) => [...m, { role: "user", content: question }]);
    setInput("");
    setLoading(true);

    const ctx = {
      include_bloodwork: context.bloodwork,
      include_wearables: context.wearables,
      include_genomics: context.genomics,
    };

    const streamed = await tryStream(question, ctx);
    if (!streamed) await fallback(question, ctx);
    setLoading(false);

    // Self-update memory from the conversation (non-blocking).
    void maybeRemember(question);
  }

  // Extract any durable directives the user stated and persist them to memory.
  async function maybeRemember(text: string) {
    if (!DIRECTIVE_CUE.test(text)) return;
    try {
      const res = await fetch("/api/backend/context/extract", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ message: text }),
      });
      if (!res.ok) return;
      const data = await res.json();
      const added: { text: string }[] = data.added || [];
      if (added.length) {
        setMessages((m) => [
          ...m,
          { role: "memory", content: added.map((d) => d.text).join(" · ") },
        ]);
      }
    } catch {
      /* memory capture is best-effort */
    }
  }

  // Token streaming via SSE; returns true if it produced any content.
  async function tryStream(question: string, ctx: Record<string, boolean>): Promise<boolean> {
    let res: Response;
    try {
      res = await fetch("/api/backend/ai/stream", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ context: ctx, question }),
      });
    } catch {
      return false;
    }
    if (!res.ok || !res.body) return false;

    const reader = res.body.getReader();
    const decoder = new TextDecoder();
    let buffer = "";
    let started = false;
    let got = false;

    const append = (delta: string) => {
      if (!started) {
        started = true;
        setMessages((m) => [...m, { role: "assistant", content: delta, streaming: true }]);
      } else {
        setMessages((m) => {
          const c = [...m];
          const last = c[c.length - 1];
          c[c.length - 1] = { ...last, content: last.content + delta };
          return c;
        });
      }
      got = true;
    };

    try {
      for (;;) {
        const { done, value } = await reader.read();
        if (done) break;
        buffer += decoder.decode(value, { stream: true });
        const lines = buffer.split("\n");
        buffer = lines.pop() ?? "";
        for (const line of lines) {
          const t = line.trim();
          if (!t.startsWith("data:")) continue;
          const data = t.slice(5).trim();
          if (data === "[DONE]") continue;
          try {
            const obj = JSON.parse(data);
            if (obj.delta) append(obj.delta);
          } catch {
            /* ignore malformed SSE line */
          }
        }
      }
    } catch {
      if (!got) return false;
    }

    if (started) {
      setMessages((m) => {
        const c = [...m];
        const last = c[c.length - 1];
        if (last?.streaming) c[c.length - 1] = { ...last, streaming: false };
        return c;
      });
    }
    return got;
  }

  // Non-streaming fallback (also covers backends without the stream endpoint).
  async function fallback(question: string, ctx: Record<string, boolean>) {
    try {
      const res = await fetch("/api/backend/ai/insights", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ context: ctx, question }),
      });
      if (!res.ok) throw new Error();
      const data = await res.json();
      const insights: string[] = data.insights || [];
      const content = insights.length
        ? insights.join("\n\n")
        : "I couldn't generate insights from the available data. Try adding more health data or enabling additional sources above.";
      setMessages((m) => [...m, { role: "assistant", content, model: data.model }]);
    } catch {
      setMessages((m) => [
        ...m,
        {
          role: "assistant",
          error: true,
          content: "The insights service didn't respond. This is usually temporary — try again in a moment.",
        },
      ]);
    }
  }

  function onKeyDown(e: React.KeyboardEvent<HTMLTextAreaElement>) {
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault();
      send(input);
    }
  }

  const empty = messages.length === 0;

  return (
    <div className="flex flex-col" style={{ height: "calc(100vh - 9rem)" }}>
      {/* Header */}
      <div className="flex flex-wrap items-center justify-between gap-3 pb-4">
        <div>
          <h1>AI Insights</h1>
          <p className="text-sm text-muted mt-0.5">Ask questions about your health data.</p>
        </div>
        <div className="flex items-center gap-1.5">
          {TOGGLES.map((t) => {
            const on = context[t.key];
            return (
              <button
                key={t.key}
                onClick={() => setContext((c) => ({ ...c, [t.key]: !c[t.key] }))}
                className="rounded-full border px-2.5 py-1 text-xs font-medium transition-colors"
                style={{
                  borderColor: on ? "var(--accent)" : "var(--border)",
                  background: on ? "var(--accent-soft)" : "transparent",
                  color: on ? "var(--text-primary)" : "var(--text-tertiary)",
                }}
                title={`Toggle ${t.label} context`}
              >
                {t.label}
              </button>
            );
          })}
        </div>
      </div>

      {/* Messages */}
      <div
        ref={scrollRef}
        className="flex-1 overflow-y-auto rounded-[var(--radius-lg)] border border-[var(--border)] bg-[var(--surface-secondary)] p-4 md:p-6"
      >
        {empty ? (
          <div className="flex h-full flex-col items-center justify-center text-center">
            <div
              className="mb-4 flex h-12 w-12 items-center justify-center rounded-[var(--radius-lg)]"
              style={{ background: "linear-gradient(135deg, var(--accent), #7c3aed)" }}
            >
              <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#fff" strokeWidth="2.1" strokeLinecap="round" strokeLinejoin="round">
                <path d="M12 3a6 6 0 00-4 10.5c.7.6 1 1.3 1 2v.5h6V15.5c0-.7.3-1.4 1-2A6 6 0 0012 3zM9.5 21h5" />
              </svg>
            </div>
            <h2 className="mb-1">Ask your health advisor</h2>
            <p className="mb-6 max-w-md text-sm text-muted">
              I analyze your bloodwork, wearables, and genomics to answer questions and surface what matters.
            </p>
            <div className="grid w-full max-w-lg grid-cols-1 gap-2 sm:grid-cols-2">
              {SUGGESTIONS.map((s) => (
                <button
                  key={s}
                  onClick={() => send(s)}
                  className="rounded-[var(--radius-md)] border border-[var(--border)] bg-[var(--gray-100)] px-3.5 py-3 text-left text-sm text-[var(--text-secondary)] transition-colors hover:border-[var(--border-strong)] hover:text-[var(--text-primary)]"
                >
                  {s}
                </button>
              ))}
            </div>
          </div>
        ) : (
          <div className="mx-auto flex max-w-2xl flex-col gap-5">
            {messages.map((m, i) =>
              m.role === "memory" ? (
                <div key={i} className="flex items-center gap-2 self-center rounded-full border border-[var(--border)] bg-[var(--surface-secondary)] px-3 py-1.5 text-xs">
                  <span style={{ color: "var(--accent)" }}>📌 Remembered</span>
                  <span className="text-[var(--text-secondary)]">{m.content}</span>
                </div>
              ) : (
              <div key={i} className="flex gap-3">
                <Avatar role={m.role} />
                <div className="min-w-0 flex-1 pt-0.5">
                  {m.role === "user" ? (
                    <p className="text-sm leading-relaxed text-[var(--text-primary)]">{m.content}</p>
                  ) : m.error ? (
                    <p className="text-sm leading-relaxed text-[var(--recovery-red)]">{m.content}</p>
                  ) : (
                    <>
                      <div className="relative">
                        <Markdown content={m.content} />
                        {m.streaming && (
                          <span className="ml-0.5 inline-block h-3.5 w-1.5 translate-y-0.5 animate-pulse rounded-[1px] bg-[var(--accent)] align-middle" />
                        )}
                      </div>
                      {m.model && !m.streaming && (
                        <p className="mt-2 text-[11px] text-[var(--text-tertiary)]">Generated by {m.model}</p>
                      )}
                    </>
                  )}
                </div>
              </div>
            ))}
            {loading && messages[messages.length - 1]?.role === "user" && (
              <div className="flex gap-3">
                <Avatar role="assistant" />
                <div className="pt-2">
                  <ThinkingDots />
                </div>
              </div>
            )}
          </div>
        )}
      </div>

      {/* Composer */}
      <div className="pt-4">
        <div className="flex items-end gap-2 rounded-[var(--radius-lg)] border border-[var(--border)] bg-[var(--gray-100)] p-2 focus-within:border-[var(--accent)]">
          <textarea
            ref={taRef}
            value={input}
            onChange={(e) => setInput(e.target.value)}
            onKeyDown={onKeyDown}
            placeholder="Ask about your health data…  (Enter to send, Shift+Enter for newline)"
            rows={1}
            className="max-h-40 min-h-[40px] flex-1 resize-none border-0 bg-transparent px-2 py-2 text-sm text-[var(--text-primary)] outline-none focus:ring-0"
            style={{ boxShadow: "none" }}
          />
          <button
            onClick={() => send(input)}
            disabled={loading || !input.trim()}
            className="flex h-9 w-9 shrink-0 items-center justify-center rounded-[var(--radius-md)] text-white transition-opacity disabled:opacity-40"
            style={{ background: "var(--accent)" }}
            aria-label="Send"
          >
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
              <path d="M22 2L11 13M22 2l-7 20-4-9-9-4 20-7z" />
            </svg>
          </button>
        </div>
      </div>
    </div>
  );
}
