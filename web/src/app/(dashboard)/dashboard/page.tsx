import { getServerSession } from "next-auth";
import { authOptions } from "@/lib/auth";
import { prisma } from "@/lib/prisma";
import { backendClient } from "@/lib/backend-client";
import { RecoveryBanner } from "@/components/ui/RecoveryBanner";
import { DashboardContent } from "./DashboardContent";

async function getDashboardData(backendUserId: string) {
  try {
    const today = new Date().toISOString().split("T")[0];
    const [protocol, wearable] = await Promise.allSettled([
      backendClient(`/protocols/daily?date=${today}`, { userId: backendUserId }),
      backendClient(`/wearables?date=${today}`, { userId: backendUserId }),
    ]);

    return {
      protocol: protocol.status === "fulfilled" ? protocol.value : null,
      wearable: wearable.status === "fulfilled" ? wearable.value : null,
    };
  } catch {
    return { protocol: null, wearable: null };
  }
}

export default async function DashboardPage() {
  const session = await getServerSession(authOptions);
  const user = await prisma.user.findUnique({
    where: { id: session!.user.id },
    select: { backendUserId: true, onboardingComplete: true, name: true },
  });

  if (!user?.onboardingComplete) {
    // For now, just show dashboard regardless
  }

  const data = user?.backendUserId
    ? await getDashboardData(user.backendUserId)
    : { protocol: null, wearable: null };

  return (
    <div className="max-w-4xl mx-auto space-y-[var(--space-lg)]">
      <div>
        <h1 className="text-2xl font-bold text-foreground">
          {user?.name ? `Good morning, ${user.name}` : "Dashboard"}
        </h1>
        <p className="text-muted mt-1">
          {new Date().toLocaleDateString("en-US", {
            weekday: "long",
            month: "long",
            day: "numeric",
          })}
        </p>
      </div>

      <DashboardContent protocol={data.protocol} wearable={data.wearable} />
    </div>
  );
}
