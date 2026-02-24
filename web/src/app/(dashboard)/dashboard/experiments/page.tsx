import { getServerSession } from "next-auth";
import { authOptions } from "@/lib/auth";
import { prisma } from "@/lib/prisma";
import { backendClient } from "@/lib/backend-client";
import Link from "next/link";
import { ExperimentsList } from "./ExperimentsList";

export default async function ExperimentsPage() {
  const session = await getServerSession(authOptions);
  const user = await prisma.user.findUnique({
    where: { id: session!.user.id },
    select: { backendUserId: true },
  });

  let experiments: any[] = [];

  if (user?.backendUserId) {
    try {
      experiments = await backendClient("/experiments", { userId: user.backendUserId });
    } catch {
      experiments = [];
    }
  }

  return (
    <div className="max-w-4xl mx-auto">
      <div className="flex items-center justify-between mb-[var(--space-lg)]">
        <h1 className="text-2xl font-bold text-foreground">Experiments</h1>
        <Link
          href="/dashboard/experiments/new"
          className="px-[var(--space-lg)] py-[var(--space-sm)] bg-training text-white rounded-[var(--radius-sm)] font-medium hover:opacity-90 transition-opacity"
        >
          New Experiment
        </Link>
      </div>
      <ExperimentsList experiments={experiments} />
    </div>
  );
}
