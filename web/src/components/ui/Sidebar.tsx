"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { signOut } from "next-auth/react";
import { navItems, type NavItem } from "@/lib/nav";

function NavLink({ item }: { item: NavItem }) {
  const pathname = usePathname();
  const active =
    item.href === "/dashboard"
      ? pathname === "/dashboard"
      : pathname.startsWith(item.href);

  return (
    <Link
      href={item.href}
      className="group relative flex items-center gap-3 rounded-[var(--radius-md)] px-3 py-2 text-sm transition-colors"
      style={{
        color: active ? "var(--text-primary)" : "var(--text-secondary)",
        background: active ? "var(--gray-300)" : "transparent",
      }}
    >
      {active && (
        <span
          className="absolute left-0 top-1/2 h-4 w-[2px] -translate-y-1/2 rounded-full"
          style={{ background: "var(--accent)" }}
        />
      )}
      <span
        className="shrink-0 transition-colors"
        style={{ color: active ? "var(--accent)" : "var(--text-tertiary)" }}
      >
        {item.icon}
      </span>
      <span className="font-medium">{item.label}</span>
    </Link>
  );
}

export function BrandMark() {
  return (
    <div className="flex items-center gap-2.5">
      <div
        className="flex h-7 w-7 items-center justify-center rounded-[var(--radius-md)]"
        style={{ background: "linear-gradient(135deg, var(--accent), #7c3aed)" }}
      >
        <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="#fff" strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round">
          <path d="M3 13h4l3 7 4-16 3 9h4" />
        </svg>
      </div>
      <div className="leading-tight">
        <div className="text-[13px] font-semibold text-[var(--text-primary)]">Outlive Engine</div>
        <div className="text-[10px] uppercase tracking-wider text-[var(--text-tertiary)]">Longevity OS</div>
      </div>
    </div>
  );
}

export function NavList() {
  const workspace = navItems.filter((i) => i.group === "workspace");
  const system = navItems.filter((i) => i.group === "system");
  return (
    <>
      <div className="px-3 pb-2 text-[10px] font-semibold uppercase tracking-wider text-[var(--text-tertiary)]">
        Workspace
      </div>
      <div className="flex flex-col gap-0.5">
        {workspace.map((item) => (
          <NavLink key={item.href} item={item} />
        ))}
      </div>
      <div className="mt-5 px-3 pb-2 text-[10px] font-semibold uppercase tracking-wider text-[var(--text-tertiary)]">
        System
      </div>
      <div className="flex flex-col gap-0.5">
        {system.map((item) => (
          <NavLink key={item.href} item={item} />
        ))}
      </div>
    </>
  );
}

export function UserFooter({ email }: { email?: string | null }) {
  const initial = (email?.[0] ?? "?").toUpperCase();
  return (
    <div className="flex items-center gap-3 rounded-[var(--radius-md)] px-2 py-2">
      <div
        className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full text-xs font-semibold text-white"
        style={{ background: "var(--gray-400)" }}
      >
        {initial}
      </div>
      <div className="min-w-0 flex-1">
        <div className="truncate text-xs text-[var(--text-secondary)]">{email}</div>
      </div>
      <button
        onClick={() => signOut({ callbackUrl: "/login" })}
        title="Sign out"
        className="shrink-0 rounded-[var(--radius-sm)] p-1.5 text-[var(--text-tertiary)] hover:text-[var(--text-primary)] hover:bg-[var(--gray-300)]"
      >
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round">
          <path d="M9 21H5a2 2 0 01-2-2V5a2 2 0 012-2h4M16 17l5-5-5-5M21 12H9" />
        </svg>
      </button>
    </div>
  );
}

export function Sidebar({ email }: { email?: string | null }) {
  return (
    <aside className="hidden md:flex md:w-[248px] flex-col border-r border-[var(--border)] bg-[var(--surface-secondary)]">
      <div className="flex items-center px-5 h-16 border-b border-[var(--border)]">
        <BrandMark />
      </div>
      <nav className="flex-1 overflow-y-auto px-3 py-4">
        <NavList />
      </nav>
      <div className="border-t border-[var(--border)] p-3">
        <UserFooter email={email} />
      </div>
    </aside>
  );
}
