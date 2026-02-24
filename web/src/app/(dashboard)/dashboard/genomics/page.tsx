import { getServerSession } from "next-auth";
import { authOptions } from "@/lib/auth";
import { prisma } from "@/lib/prisma";
import { backendClient } from "@/lib/backend-client";
import { GenomicsList } from "./GenomicsList";

export default async function GenomicsPage() {
  const session = await getServerSession(authOptions);
  const user = await prisma.user.findUnique({
    where: { id: session!.user.id },
    select: { backendUserId: true },
  });

  let risks: any[] = [];

  if (user?.backendUserId) {
    try {
      risks = await backendClient("/genomics/risks", { userId: user.backendUserId });
    } catch {
      risks = [];
    }
  }

  return (
    <div className="max-w-4xl mx-auto">
      <div className="flex items-center justify-between mb-[var(--space-lg)]">
        <h1 className="text-2xl font-bold text-foreground">Genomics</h1>
      </div>
      <GenomicsList risks={risks} />
    </div>
  );
}
