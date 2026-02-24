"use client";

import { useState, useRef, useEffect, useCallback } from "react";

interface Message {
  role: "user" | "assistant";
  content: string;
}

export function ChatBox() {
  const [expanded, setExpanded] = useState(false);
  const [messages, setMessages] = useState<Message[]>([]);
  const [input, setInput] = useState("");
  const [loading, setLoading] = useState(false);
  const [conversationId, setConversationId] = useState<string | null>(() => {
    if (typeof window !== "undefined") {
      return localStorage.getItem("outlive_chat_conversation_id");
    }
    return null;
  });
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (expanded && inputRef.current) {
      inputRef.current.focus();
    }
  }, [expanded]);

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages]);

  // Persist conversation ID
  useEffect(() => {
    if (conversationId) {
      localStorage.setItem("outlive_chat_conversation_id", conversationId);
    }
  }, [conversationId]);

  // Load existing conversation on expand
  useEffect(() => {
    if (expanded && conversationId && messages.length === 0) {
      loadConversation();
    }
  }, [expanded, conversationId]);

  async function loadConversation() {
    if (!conversationId) return;
    try {
      const resp = await fetch(`/api/backend/chat/conversations/${conversationId}`);
      if (resp.ok) {
        const data = await resp.json();
        if (data.messages?.length > 0) {
          setMessages(
            data.messages.map((m: any) => ({ role: m.role, content: m.content }))
          );
        }
      }
    } catch {
      // Conversation may not exist yet
    }
  }

  const sendMessage = useCallback(async () => {
    const trimmed = input.trim();
    if (!trimmed || loading) return;

    setInput("");
    setMessages((prev) => [...prev, { role: "user", content: trimmed }]);
    setLoading(true);

    try {
      const resp = await fetch("/api/backend/chat/message", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          message: trimmed,
          conversation_id: conversationId,
          include_context: messages.length === 0, // include health context on first message
        }),
      });

      if (!resp.ok) throw new Error("Chat request failed");

      const data = await resp.json();
      setMessages((prev) => [...prev, { role: "assistant", content: data.response }]);
      if (data.conversation_id) {
        setConversationId(data.conversation_id);
      }
    } catch {
      setMessages((prev) => [
        ...prev,
        { role: "assistant", content: "Sorry, I couldn't connect to the AI service. Please try again." },
      ]);
    } finally {
      setLoading(false);
    }
  }, [input, loading, conversationId, messages.length]);

  function newConversation() {
    setMessages([]);
    setConversationId(null);
    localStorage.removeItem("outlive_chat_conversation_id");
  }

  if (!expanded) {
    return (
      <button
        onClick={() => setExpanded(true)}
        className="w-full py-3 px-[var(--space-lg)] bg-card rounded-[var(--radius-md)] border border-[var(--surface-elevated)] text-sm text-muted hover:text-foreground hover:border-training/40 transition-colors text-left"
      >
        Chat with your health advisor →
      </button>
    );
  }

  return (
    <div className="bg-card rounded-[var(--radius-md)] border border-[var(--surface-elevated)] overflow-hidden">
      {/* Header */}
      <div className="flex items-center justify-between px-[var(--space-lg)] py-[var(--space-sm)] border-b border-[var(--surface-elevated)]">
        <h3 className="font-semibold text-foreground text-sm">Health Advisor</h3>
        <div className="flex items-center gap-2">
          <button
            onClick={newConversation}
            className="text-xs text-muted hover:text-foreground transition-colors"
            title="New conversation"
          >
            New
          </button>
          <button
            onClick={() => setExpanded(false)}
            className="text-muted hover:text-foreground transition-colors"
          >
            ✕
          </button>
        </div>
      </div>

      {/* Local model warning */}
      <div className="px-[var(--space-lg)] py-2 bg-recovery-yellow/10 border-b border-recovery-yellow/20">
        <p className="text-xs text-muted">
          Running on a local model — responses may be slower and less detailed than cloud AI.
        </p>
      </div>

      {/* Messages */}
      <div className="h-80 overflow-y-auto px-[var(--space-lg)] py-[var(--space-md)] space-y-[var(--space-md)]">
        {messages.length === 0 && (
          <p className="text-sm text-muted text-center mt-8">
            Ask about your protocols, health data, or longevity strategies.
          </p>
        )}
        {messages.map((msg, i) => (
          <div
            key={i}
            className={`flex ${msg.role === "user" ? "justify-end" : "justify-start"}`}
          >
            <div
              className={`max-w-[80%] rounded-[var(--radius-sm)] px-3 py-2 text-sm ${
                msg.role === "user"
                  ? "bg-training text-white"
                  : "bg-[var(--surface-elevated)] text-foreground"
              }`}
            >
              <p className="whitespace-pre-wrap">{msg.content}</p>
            </div>
          </div>
        ))}
        {loading && (
          <div className="flex justify-start">
            <div className="bg-[var(--surface-elevated)] rounded-[var(--radius-sm)] px-3 py-2 text-sm text-muted">
              Thinking...
            </div>
          </div>
        )}
        <div ref={messagesEndRef} />
      </div>

      {/* Input */}
      <div className="px-[var(--space-lg)] py-[var(--space-sm)] border-t border-[var(--surface-elevated)]">
        <div className="flex gap-2">
          <input
            ref={inputRef}
            type="text"
            value={input}
            onChange={(e) => setInput(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === "Enter" && !e.shiftKey) {
                e.preventDefault();
                sendMessage();
              }
            }}
            placeholder="Ask about your health..."
            className="flex-1 bg-[var(--surface-elevated)] rounded-[var(--radius-sm)] px-3 py-2 text-sm text-foreground placeholder:text-muted outline-none focus:ring-1 focus:ring-training/50"
            disabled={loading}
          />
          <button
            onClick={sendMessage}
            disabled={loading || !input.trim()}
            className="px-4 py-2 bg-training text-white rounded-[var(--radius-sm)] text-sm font-medium hover:opacity-90 transition-opacity disabled:opacity-50"
          >
            Send
          </button>
        </div>
      </div>
    </div>
  );
}
