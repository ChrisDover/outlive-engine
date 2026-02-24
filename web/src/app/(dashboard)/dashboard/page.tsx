import { getServerSession } from "next-auth";
import { authOptions } from "@/lib/auth";
import { prisma } from "@/lib/prisma";
import { backendClient } from "@/lib/backend-client";
import { RecoveryBanner } from "@/components/ui/RecoveryBanner";
import { DashboardContent } from "./DashboardContent";
import { WelcomeCard } from "@/components/ui/WelcomeCard";

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

export default async function DashboardPage() {
  const session = await getServerSession(authOptions);
  const user = await prisma.user.findUnique({
    where: { id: session!.user.id },
    select: { backendUserId: true, onboardingComplete: true, name: true },
  });

  if (!user?.onboardingComplete) {
    // Show welcome card (handled below in render)
  }

  const data = user?.backendUserId
    ? await getDashboardData(user.backendUserId)
    : {
        protocol: null,
        wearable: null,
        hasBloodwork: false,
        hasBodyComp: false,
        hasGenomics: false,
        hasExperiments: false,
      };

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
    </div>
  );
}
