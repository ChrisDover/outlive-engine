import { getServerSession } from "next-auth";
import { authOptions } from "@/lib/auth";
import { prisma } from "@/lib/prisma";
import { backendClient } from "@/lib/backend-client";
import { RecoveryBanner } from "@/components/ui/RecoveryBanner";
import { DashboardContent } from "./DashboardContent";
import { WelcomeCard } from "@/components/ui/WelcomeCard";
import { WearableConnectCard } from "@/components/ui/WearableConnectCard";
import { ChatBox } from "@/components/ui/ChatBox";

async function getDashboardData(backendUserId: string) {
  try {
    const today = new Date().toISOString().split("T")[0];
    const [protocol, wearable, bloodwork, bodyComp, genomics, experiments] =
      await Promise.allSettled([
        backendClient(`/protocols/daily?date=${today}`, { userId: backendUserId }),
        backendClient(`/wearables?date=${today}`, { userId: backendUserId }),
        backendClient("/bloodwork?limit=1", { userId: backendUserId }),
        backendClient("/body-composition?limit=1", { userId: backendUserId }),
        backendClient("/genomics/risks?limit=1", { userId: backendUserId }),
        backendClient("/experiments?limit=1", { userId: backendUserId }),
      ]);

    return {
      protocol: protocol.status === "fulfilled" ? protocol.value : null,
      wearable: wearable.status === "fulfilled" ? wearable.value : null,
      hasBloodwork:
        bloodwork.status === "fulfilled" &&
        Array.isArray(bloodwork.value) &&
        bloodwork.value.length > 0,
      hasBodyComp:
        bodyComp.status === "fulfilled" &&
        Array.isArray(bodyComp.value) &&
        bodyComp.value.length > 0,
      hasGenomics:
        genomics.status === "fulfilled" &&
        Array.isArray(genomics.value) &&
        genomics.value.length > 0,
      hasExperiments:
        experiments.status === "fulfilled" &&
        Array.isArray(experiments.value) &&
        experiments.value.length > 0,
    };
  } catch {
    return {
      protocol: null,
      wearable: null,
      hasBloodwork: false,
      hasBodyComp: false,
      hasGenomics: false,
      hasExperiments: false,
    };
  }
}

async function triggerWearableSync(backendUserId: string) {
  try {
    // Sync wearable data via internal API
    const baseUrl = process.env.NEXTAUTH_URL || "http://localhost:3000";
    await fetch(`${baseUrl}/api/wearables/sync`, { method: "POST" });
  } catch {
    // Non-blocking — sync errors don't prevent dashboard load
  }
}

async function triggerDailyPlanGeneration(backendUserId: string) {
  try {
    const today = new Date().toISOString().split("T")[0];
    const result = await backendClient(`/protocols/daily/generate?target_date=${today}`, {
      method: "POST",
      userId: backendUserId,
    });
    return result;
  } catch {
    return null;
  }
}

export default async function DashboardPage() {
  const session = await getServerSession(authOptions);
  const user = await prisma.user.findUnique({
    where: { id: session!.user.id },
    select: {
      backendUserId: true,
      onboardingComplete: true,
      name: true,
      ouraAccessToken: true,
      whoopAccessToken: true,
    },
  });

  const hasOura = !!user?.ouraAccessToken;
  const hasWhoop = !!user?.whoopAccessToken;
  const hasWearableTokens = hasOura || hasWhoop;

  // Trigger wearable sync if tokens exist (non-blocking)
  if (user?.backendUserId && hasWearableTokens) {
    triggerWearableSync(user.backendUserId);
  }

  let data = user?.backendUserId
    ? await getDashboardData(user.backendUserId)
    : {
        protocol: null,
        wearable: null,
        hasBloodwork: false,
        hasBodyComp: false,
        hasGenomics: false,
        hasExperiments: false,
      };

  // Auto-generate daily plan if none exists and user has backend account
  if (!data.protocol && user?.backendUserId) {
    const generated = await triggerDailyPlanGeneration(user.backendUserId);
    if (generated) {
      data = { ...data, protocol: generated };
    }
  }

  const isNewUser =
    !data.hasBloodwork && !data.hasBodyComp && !data.hasGenomics && !data.hasExperiments;

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

      {/* Always show wearable card first when not connected — this is the #1 priority */}
      {!hasWearableTokens && (
        <WearableConnectCard ouraConnected={hasOura} whoopConnected={hasWhoop} />
      )}

      {(isNewUser || !user?.onboardingComplete) && (
        <WelcomeCard
          name={user?.name ?? null}
          hasBloodwork={data.hasBloodwork}
          hasBodyComp={data.hasBodyComp}
          hasGenomics={data.hasGenomics}
          hasExperiments={data.hasExperiments}
        />
      )}

      <DashboardContent protocol={data.protocol} wearable={data.wearable} />

      <ChatBox />
    </div>
  );
}
