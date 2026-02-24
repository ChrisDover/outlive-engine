import { getServerSession } from "next-auth";
import { authOptions } from "@/lib/auth";
import { prisma } from "@/lib/prisma";
import { backendClient } from "@/lib/backend-client";
import { redirect } from "next/navigation";
import { ExperimentDetail } from "./ExperimentDetail";

export default async function ExperimentDetailPage({
  params,
}: {
  params: Promise<{ experimentId: string }>;
}) {
  const { experimentId } = await params;
  const session = await getServerSession(authOptions);
  const user = await prisma.user.findUnique({
    where: { id: session!.user.id },
    select: { backendUserId: true },
  });

  if (!user?.backendUserId) {
    redirect("/dashboard/experiments");
  }

  let experiment;
  try {
    experiment = await backendClient(`/experiments/${experimentId}`, {
      userId: user.backendUserId,
    });
  } catch {
    redirect("/dashboard/experiments");
  }

  return (
    <div className="max-w-4xl mx-auto">
      <ExperimentDetail experiment={experiment} />
    </div>
  );
}
