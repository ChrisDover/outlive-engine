import { getServerSession } from "next-auth";
import { authOptions } from "@/lib/auth";
import { prisma } from "@/lib/prisma";
import { backendClient } from "@/lib/backend-client";
import { BodyCompContent } from "./BodyCompContent";

export default async function BodyCompositionPage() {
  const session = await getServerSession(authOptions);
  const user = await prisma.user.findUnique({
    where: { id: session!.user.id },
    select: { backendUserId: true },
  });

  let entries: any[] = [];

  if (user?.backendUserId) {
    try {
      entries = await backendClient("/body-composition", { userId: user.backendUserId });
    } catch {
      entries = [];
    }
  }

  return (
    <div className="max-w-4xl mx-auto">
      <h1 className="text-2xl font-bold text-foreground mb-[var(--space-lg)]">Body Composition</h1>
      <BodyCompContent entries={entries} />
    </div>
  );
}
