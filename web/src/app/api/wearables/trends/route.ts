import { NextRequest, NextResponse } from "next/server";
import { getServerSession } from "next-auth";
import { authOptions } from "@/lib/auth";
import { prisma } from "@/lib/prisma";
import { backendClient } from "@/lib/backend-client";

interface WearableRow {
  date?: string;
  metrics?: Record<string, number | undefined>;
}

/**
 * Normalizes the backend's wearable records into day-keyed trend points the
 * dashboard/Trends charts consume. Returns { trends: [] } gracefully on any
 * failure so the UI can show its empty/error state instead of a 500.
 */
export async function GET(req: NextRequest) {
  const session = await getServerSession(authOptions);
  if (!session?.user?.id) {
    return NextResponse.json({ trends: [] }, { status: 401 });
  }

  const user = await prisma.user.findUnique({
    where: { id: session.user.id },
    select: { backendUserId: true },
  });
  if (!user?.backendUserId) {
    return NextResponse.json({ trends: [] });
  }

  const days = Math.max(1, Math.min(365, Number(req.nextUrl.searchParams.get("days") || "30")));
  const cutoff = new Date();
  cutoff.setDate(cutoff.getDate() - days);

  try {
    // Backend caps limit at 200.
    const rows = (await backendClient(`/wearables?limit=200`, {
      userId: user.backendUserId,
    })) as WearableRow[];

    const trends = (Array.isArray(rows) ? rows : [])
      .filter((r) => r.date && new Date(r.date) >= cutoff)
      .map((r) => {
        const m = r.metrics ?? {};
        return {
          date: r.date as string,
          hrv: m.hrv,
          rhr: m.resting_hr ?? m.rhr,
          sleep_score: m.sleep_score,
          recovery_score: m.recovery_score ?? m.readiness_score,
          sleep_hours: m.sleep_hours ?? m.total_sleep,
          weight_kg: m.weight ?? m.weight_kg,
          body_fat_percent: m.body_fat_pct ?? m.body_fat_percent,
        };
      })
      .sort((a, b) => a.date.localeCompare(b.date));

    return NextResponse.json({ trends });
  } catch {
    return NextResponse.json({ trends: [] });
  }
}
