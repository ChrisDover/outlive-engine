"use client";

import { useEffect, useState } from "react";
import { BrandMark, NavList, UserFooter } from "@/components/ui/Sidebar";
import { CommandPalette, OPEN_COMMAND_PALETTE } from "@/components/ui/CommandPalette";

function MobileDrawer({
  open,
  onClose,
  email,
}: {
  open: boolean;
  onClose: () => void;
  email?: string | null;
}) {
  useEffect(() => {
    if (open) document.body.style.overflow = "hidden";
    else document.body.style.overflow = "";
    return () => {
      document.body.style.overflow = "";
    };
  }, [open]);

  return (
    <div
      className={`fixed inset-0 z-40 md:hidden ${open ? "" : "pointer-events-none"}`}
      aria-hidden={!open}
    >
      <div
        className="absolute inset-0 bg-black/60 backdrop-blur-sm transition-opacity duration-200"
        style={{ opacity: open ? 1 : 0 }}
        onClick={onClose}
      />
      <aside
        className="absolute left-0 top-0 flex h-full w-[270px] flex-col border-r border-[var(--border)] bg-[var(--surface-secondary)] transition-transform duration-200"
        style={{ transform: open ? "translateX(0)" : "translateX(-100%)" }}
      >
        <div className="flex h-16 items-center justify-between border-b border-[var(--border)] px-5">
          <BrandMark />
          <button
            onClick={onClose}
            className="rounded-[var(--radius-sm)] p-1.5 text-[var(--text-tertiary)] hover:text-[var(--text-primary)] hover:bg-[var(--gray-300)]"
            aria-label="Close menu"
          >
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
              <path d="M18 6L6 18M6 6l12 12" />
            </svg>
          </button>
        </div>
        <nav className="flex-1 overflow-y-auto px-3 py-4" onClick={onClose}>
          <NavList />
        </nav>
        <div className="border-t border-[var(--border)] p-3">
          <UserFooter email={email} />
        </div>
      </aside>
    </div>
  );
}

export function TopBar({ email }: { email?: string | null }) {
  const [menuOpen, setMenuOpen] = useState(false);

  // Server/client timezones can differ — suppress the hydration warning on the
  // date chip rather than syncing it through an effect.
  const date = new Date().toLocaleDateString("en-US", {
    weekday: "short",
    month: "short",
    day: "numeric",
  });

  return (
    <>
      <header className="sticky top-0 z-30 flex h-16 items-center justify-between gap-4 border-b border-[var(--border)] bg-[color-mix(in_srgb,var(--black)_80%,transparent)] px-4 backdrop-blur-md md:px-8">
        <div className="flex items-center gap-3">
          <button
            onClick={() => setMenuOpen(true)}
            className="rounded-[var(--radius-sm)] p-1.5 text-[var(--text-secondary)] hover:text-[var(--text-primary)] hover:bg-[var(--gray-300)] md:hidden"
            aria-label="Open menu"
          >
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
              <path d="M3 6h18M3 12h18M3 18h18" />
            </svg>
          </button>
          <div className="hidden items-center gap-2 text-xs text-[var(--text-tertiary)] md:flex">
            <span className="inline-flex h-1.5 w-1.5 rounded-full" style={{ background: "var(--green)" }} />
            <span>All systems operational</span>
          </div>
          <div className="text-sm font-medium text-[var(--text-primary)] md:hidden">Outlive Engine</div>
        </div>

        <div className="flex items-center gap-3">
          <button
            onClick={() => window.dispatchEvent(new Event(OPEN_COMMAND_PALETTE))}
            className="flex items-center gap-2 rounded-[var(--radius-md)] border border-[var(--border)] px-2.5 py-1.5 text-xs text-[var(--text-tertiary)] hover:border-[var(--border-strong)] hover:text-[var(--text-secondary)]"
            aria-label="Open command palette"
          >
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round">
              <circle cx="11" cy="11" r="7" />
              <path d="M21 21l-4.3-4.3" />
            </svg>
            <span className="hidden sm:inline">Search…</span>
            <kbd className="hidden rounded border border-[var(--border)] px-1.5 py-0.5 text-[10px] sm:inline">⌘K</kbd>
          </button>
          <span className="hidden rounded-full border border-[var(--border)] px-2.5 py-1 text-xs text-[var(--text-secondary)] sm:inline-block" suppressHydrationWarning>
            {date}
          </span>
        </div>
      </header>

      <MobileDrawer open={menuOpen} onClose={() => setMenuOpen(false)} email={email} />
      <CommandPalette />
    </>
  );
}
