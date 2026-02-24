import { getServerSession } from "next-auth";
import { NextResponse } from "next/server";
import { authOptions } from "@/lib/auth";
import { prisma } from "@/lib/prisma";
import { backendClient } from "@/lib/backend-client";
import { fetchOuraData } from "@/lib/oura-client";
import { fetchWhoopData } from "@/lib/whoop-client";

export async function POST() {
  const session = await getServerSession(authOptions);
  if (!session?.user?.id) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const user = await prisma.user.findUnique({
    where: { id: session.user.id },
    select: {
      backendUserId: true,
      ouraAccessToken: true,
      ouraRefreshToken: true,
      whoopAccessToken: true,
      whoopRefreshToken: true,
    },
  });

  if (!user?.backendUserId) {
    return NextResponse.json({ error: "Backend user not linked" }, { status: 400 });
  }

  const today = new Date().toISOString().split("T")[0];
  const entries: Array<{ date: string; source: string; metrics: Record<string, any> }> = [];
  const errors: string[] = [];

  // Fetch Oura data if connected
  if (user.ouraAccessToken && user.ouraRefreshToken) {
    try {
      const data = await fetchOuraData(session.user.id, user.ouraAccessToken, user.ouraRefreshToken, today);
      if (Object.keys(data.metrics).length > 0) {
        entries.push(data);
      }
    } catch (err) {
      errors.push(`Oura: ${err instanceof Error ? err.message : "unknown error"}`);
    }
  }

  // Fetch Whoop data if connected
  if (user.whoopAccessToken && user.whoopRefreshToken) {
    try {
      const data = await fetchWhoopData(session.user.id, user.whoopAccessToken, user.whoopRefreshToken, today);
      if (Object.keys(data.metrics).length > 0) {
        entries.push(data);
      }
    } catch (err) {
      errors.push(`Whoop: ${err instanceof Error ? err.message : "unknown error"}`);
    }
  }

  // Push to backend
  if (entries.length > 0) {
    try {
      await backendClient("/wearables/batch", {
        method: "POST",
        userId: user.backendUserId,
        body: JSON.stringify({ entries }),
      });
    } catch (err) {
      errors.push(`Backend sync: ${err instanceof Error ? err.message : "unknown error"}`);
    }
  }

  return NextResponse.json({
    synced: entries.length,
    sources: entries.map((e) => e.source),
    errors: errors.length > 0 ? errors : undefined,
  });
}
