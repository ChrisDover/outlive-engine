import { getServerSession } from "next-auth";
import { authOptions } from "@/lib/auth";
import { prisma } from "@/lib/prisma";
import { backendClient } from "@/lib/backend-client";
import { DashboardContent } from "./DashboardContent";
import { WelcomeCard } from "@/components/ui/WelcomeCard";
import { WearableConnectCard } from "@/components/ui/WearableConnectCard";
import { ChatBox } from "@/components/ui/ChatBox";
import { MorningBrief } from "@/components/ui/MorningBrief";
import { QuickStats } from "@/components/ui/QuickStats";

async function getDashboardData(backendUserId: string) {
  try {
    const today = new Date().toISOString().split("T")[0];
    const [protocol, morningBrief, wearable, bloodwork, bodyComp, genomics, experiments, progressStats, adherence, goals] =
      await Promise.allSettled([
        backendClient(`/protocols/daily?date=${today}`, { userId: backendUserId }),
        backendClient(`/protocols/morning-brief?target_date=${today}`, {
          method: "POST",
          userId: backendUserId
        }),
        backendClient(`/wearables?date=${today}`, { userId: backendUserId }),
        backendClient("/bloodwork?limit=1", { userId: backendUserId }),
        backendClient("/body-composition?limit=1", { userId: backendUserId }),
        backendClient("/genomics/risks?limit=1", { userId: backendUserId }),
        backendClient("/experiments?limit=1", { userId: backendUserId }),
        backendClient("/progress/stats", { userId: backendUserId }),
        backendClient(`/progress/adherence/today`, { userId: backendUserId }),
        backendClient("/progress/goals?status_filter=active", { userId: backendUserId }),
      ]);

    return {
      protocol: protocol.status === "fulfilled" ? protocol.value : null,
      morningBrief: morningBrief.status === "fulfilled" ? morningBrief.value : null,
      wearable: wearable.status === "fulfilled" ? wearable.value : null,
      progressStats: progressStats.status === "fulfilled" ? progressStats.value : null,
      adherence: adherence.status === "fulfilled" ? adherence.value : [],
      goals: goals.status === "fulfilled" ? goals.value : [],
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
      morningBrief: null,
      wearable: null,
      progressStats: null,
      adherence: [],
      goals: [],
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
        morningBrief: null,
        wearable: null,
        progressStats: null,
        adherence: [],
        goals: [],
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

  // Extract wearable metrics for quick stats
  const wearableMetrics = Array.isArray(data.wearable) && data.wearable.length > 0
    ? data.wearable[0]?.metrics
    : data.wearable?.metrics;

  return (
    <div className="max-w-4xl mx-auto space-y-[var(--space-lg)]">
      {/* Header */}
      <div className="flex items-center justify-between">
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
      </div>

      {/* Always show wearable card first when not connected — this is the #1 priority */}
      {!hasWearableTokens && (
        <WearableConnectCard ouraConnected={hasOura} whoopConnected={hasWhoop} />
      )}

      {/* NEW LAYOUT: AI Chat / Morning Brief at TOP (Primary Interface) */}
      <div className="space-y-[var(--space-md)]">
        {/* Morning Brief - the main AI coach interface */}
        <MorningBrief brief={data.morningBrief} />

        {/* Quick Stats Row */}
        <QuickStats
          hrv={wearableMetrics?.hrv}
          sleepHours={wearableMetrics?.sleep_hours || wearableMetrics?.total_sleep}
          recoveryScore={wearableMetrics?.recovery_score || wearableMetrics?.readiness_score}
          streak={data.progressStats?.current_streak || 0}
          weeklyAdherence={data.progressStats?.this_week?.rate || 0}
        />

        {/* Chat Box - always visible */}
        <ChatBox />
      </div>

      {/* Welcome Card for new users */}
      {(isNewUser || !user?.onboardingComplete) && (
        <WelcomeCard
          name={user?.name ?? null}
          hasBloodwork={data.hasBloodwork}
          hasBodyComp={data.hasBodyComp}
          hasGenomics={data.hasGenomics}
          hasExperiments={data.hasExperiments}
        />
      )}

      {/* Protocol Cards Section (Collapsible) */}
      <DashboardContent
        protocol={data.protocol}
        wearable={data.wearable}
        adherence={data.adherence}
        goals={data.goals}
        progressStats={data.progressStats}
      />
    </div>
  );
}
