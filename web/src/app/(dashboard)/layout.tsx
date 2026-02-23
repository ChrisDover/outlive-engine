import { redirect } from "next/navigation";
import { getServerSession } from "next-auth";
import { authOptions } from "@/lib/auth";
import Link from "next/link";

const navItems = [
  { href: "/dashboard", label: "Dashboard", icon: "⬡" },
  { href: "/dashboard/bloodwork", label: "Bloodwork", icon: "🩸" },
  { href: "/dashboard/genomics", label: "Genomics", icon: "🧬" },
  { href: "/dashboard/experiments", label: "Experiments", icon: "🧪" },
  { href: "/dashboard/body-composition", label: "Body Comp", icon: "📊" },
  { href: "/dashboard/insights", label: "AI Insights", icon: "💡" },
  { href: "/dashboard/settings", label: "Settings", icon: "⚙️" },
];

export default async function DashboardLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const session = await getServerSession(authOptions);
  if (!session) redirect("/login");

  return (
    <div className="flex h-screen bg-background">
      {/* Sidebar */}
      <aside className="hidden md:flex md:w-64 flex-col border-r border-[var(--surface-elevated)] bg-secondary">
        <div className="p-[var(--space-lg)]">
          <h1 className="text-xl font-bold text-foreground">Outlive Engine</h1>
        </div>
        <nav className="flex-1 px-[var(--space-sm)]">
          {navItems.map((item) => (
            <Link
              key={item.href}
              href={item.href}
              className="flex items-center gap-[var(--space-sm)] px-[var(--space-md)] py-[var(--space-sm)] rounded-[var(--radius-sm)] text-muted hover:text-foreground hover:bg-elevated transition-colors"
            >
              <span>{item.icon}</span>
              <span>{item.label}</span>
            </Link>
          ))}
        </nav>
        <div className="p-[var(--space-md)] border-t border-[var(--surface-elevated)]">
          <p className="text-sm text-subtle truncate">{session.user?.email}</p>
        </div>
      </aside>

      {/* Main content */}
      <main className="flex-1 overflow-y-auto">
        {/* Mobile topbar */}
        <header className="md:hidden flex items-center justify-between p-[var(--space-md)] border-b border-[var(--surface-elevated)]">
          <h1 className="text-lg font-bold">Outlive Engine</h1>
        </header>
        <div className="p-[var(--space-lg)]">
          {children}
        </div>
      </main>
    </div>
  );
}
