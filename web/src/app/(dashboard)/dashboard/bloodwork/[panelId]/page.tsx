import { getServerSession } from "next-auth";
import { authOptions } from "@/lib/auth";
import { prisma } from "@/lib/prisma";
import { backendClient } from "@/lib/backend-client";
import { redirect } from "next/navigation";
import { PanelDetail } from "./PanelDetail";

interface Props {
  params: Promise<{ panelId: string }>;
}

export default async function PanelDetailPage({ params }: Props) {
  const { panelId } = await params;
  const session = await getServerSession(authOptions);
  const user = await prisma.user.findUnique({
    where: { id: session!.user.id },
    select: { backendUserId: true },
  });

  if (!user?.backendUserId) {
    redirect("/dashboard/bloodwork");
  }

  let panel;
  try {
    panel = await backendClient(`/bloodwork/${panelId}`, {
      userId: user.backendUserId,
    });
  } catch {
    redirect("/dashboard/bloodwork");
  }

  if (!panel) {
    redirect("/dashboard/bloodwork");
  }

  return (
    <div className="max-w-4xl mx-auto">
      <PanelDetail panel={panel} />
    </div>
  );
}
