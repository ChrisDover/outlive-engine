import type { ReactNode } from "react";

export interface NavItem {
  href: string;
  label: string;
  icon: ReactNode;
  group: "workspace" | "system";
  keywords?: string;
}

function Icon({ d }: { d: string }) {
  return (
    <svg
      width="18"
      height="18"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.7"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden
    >
      <path d={d} />
    </svg>
  );
}

export const navItems: NavItem[] = [
  { href: "/dashboard", label: "Overview", group: "workspace", keywords: "home dashboard today", icon: <Icon d="M3 12l9-9 9 9M5 10v10h14V10" /> },
  { href: "/dashboard/bloodwork", label: "Bloodwork", group: "workspace", keywords: "labs blood panel biomarkers", icon: <Icon d="M12 2.5C8 7 6 10 6 13a6 6 0 0012 0c0-3-2-6-6-10.5z" /> },
  { href: "/dashboard/genomics", label: "Genomics", group: "workspace", keywords: "dna snp genes apoe mthfr", icon: <Icon d="M8 4c8 4 0 12 8 16M16 4c-8 4 0 12-8 16M9 7h6M9 12h6M9 17h6" /> },
  { href: "/dashboard/experiments", label: "Experiments", group: "workspace", keywords: "n=1 trials test supplement", icon: <Icon d="M9 3v6l-5 9a2 2 0 002 3h12a2 2 0 002-3l-5-9V3M9 3h6M7 15h10" /> },
  { href: "/dashboard/trends", label: "Trends", group: "workspace", keywords: "charts graphs history time series biomarkers", icon: <Icon d="M3 17l5-5 4 4 8-8M21 8h-5M21 8v5" /> },
  { href: "/dashboard/body-composition", label: "Body Comp", group: "workspace", keywords: "weight body fat lean mass dexa", icon: <Icon d="M4 19V5M9 19v-7M14 19v-4M19 19V9" /> },
  { href: "/dashboard/insights", label: "AI Insights", group: "workspace", keywords: "chat ai ask advisor", icon: <Icon d="M12 3a6 6 0 00-4 10.5c.7.6 1 1.3 1 2v.5h6V15.5c0-.7.3-1.4 1-2A6 6 0 0012 3zM9.5 21h5" /> },
  { href: "/dashboard/context", label: "Goals & Context", group: "workspace", keywords: "goals memory directives focus plan preferences", icon: <Icon d="M12 22a10 10 0 100-20 10 10 0 000 20zM12 18a6 6 0 100-12 6 6 0 000 12zM12 14a2 2 0 100-4 2 2 0 000 4z" /> },
  { href: "/dashboard/settings", label: "Settings", group: "system", keywords: "account wearables connect integrations env", icon: <Icon d="M12 15a3 3 0 100-6 3 3 0 000 6zM19.4 15a1.7 1.7 0 00.3 1.9l.1.1a2 2 0 11-2.8 2.8l-.1-.1a1.7 1.7 0 00-2.9 1.2V21a2 2 0 11-4 0v-.1A1.7 1.7 0 004 19.4l-.1.1a2 2 0 11-2.8-2.8l.1-.1A1.7 1.7 0 002.4 14H2a2 2 0 110-4h.1A1.7 1.7 0 004.6 8L4.5 8a2 2 0 112.8-2.8l.1.1A1.7 1.7 0 0010 4.6V4a2 2 0 114 0v.1a1.7 1.7 0 002.9 1.2l.1-.1a2 2 0 112.8 2.8l-.1.1a1.7 1.7 0 001.2 2.9H22a2 2 0 110 4h-.1a1.7 1.7 0 00-1.5 1z" /> },
];
