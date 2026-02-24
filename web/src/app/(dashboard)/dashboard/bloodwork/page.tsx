import { getServerSession } from "next-auth";
import { authOptions } from "@/lib/auth";
import { prisma } from "@/lib/prisma";
import { backendClient } from "@/lib/backend-client";
import Link from "next/link";
import { BloodworkList } from "./BloodworkList";

export default async function BloodworkPage() {
  const session = await getServerSession(authOptions);
  const user = await prisma.user.findUnique({
    where: { id: session!.user.id },
    select: { backendUserId: true },
  });

  let panels: any[] = [];

  if (user?.backendUserId) {
    try {
      panels = await backendClient("/bloodwork", { userId: user.backendUserId });
    } catch {
      panels = [];
    }
  }

  return (
    <div className="max-w-4xl mx-auto">
      <div className="flex items-center justify-between mb-[var(--space-lg)]">
        <h1 className="text-2xl font-bold text-foreground">Bloodwork</h1>
        <Link
          href="/dashboard/bloodwork/new"
          className="px-[var(--space-lg)] py-[var(--space-sm)] bg-bloodwork text-white rounded-[var(--radius-sm)] font-medium hover:opacity-90 transition-opacity"
        >
          Add Panel
        </Link>
      </div>
      <BloodworkList panels={panels} />
    </div>
  );
}
