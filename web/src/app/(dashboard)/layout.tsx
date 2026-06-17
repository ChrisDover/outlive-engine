import { redirect } from "next/navigation";
import { getServerSession } from "next-auth";
import { authOptions } from "@/lib/auth";
import { Sidebar } from "@/components/ui/Sidebar";
import { TopBar } from "@/components/ui/TopBar";

export default async function DashboardLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const session = await getServerSession(authOptions);
  if (!session) redirect("/login");

  return (
    <div className="flex h-screen bg-background">
      <Sidebar email={session.user?.email} />

      <main className="flex-1 overflow-y-auto">
        <TopBar email={session.user?.email} />
        <div className="mx-auto w-full max-w-6xl px-5 py-6 md:px-8 md:py-8">
          {children}
        </div>
      </main>
    </div>
  );
}
