import { NextRequest, NextResponse } from "next/server";
import { getServerSession } from "next-auth";
import { authOptions } from "@/lib/auth";
import { prisma } from "@/lib/prisma";

const BACKEND_URL = process.env.OUTLIVE_BACKEND_URL || "http://localhost:8000";
const SERVICE_KEY = process.env.OUTLIVE_SERVICE_KEY || "";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/**
 * Streaming proxy for AI insights. Unlike the generic [...path] proxy (which
 * buffers JSON), this forwards the upstream Server-Sent Events body straight
 * through to the client so tokens render as they arrive.
 */
export async function POST(request: NextRequest) {
  const session = await getServerSession(authOptions);
  if (!session?.user?.id) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const user = await prisma.user.findUnique({
    where: { id: session.user.id },
    select: { backendUserId: true },
  });
  if (!user?.backendUserId) {
    return NextResponse.json({ error: "Backend user not linked" }, { status: 400 });
  }

  const body = await request.text();

  let upstream: Response;
  try {
    upstream = await fetch(`${BACKEND_URL}/api/v1/ai/insights/stream`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${SERVICE_KEY}`,
        "X-Outlive-User-Id": user.backendUserId,
      },
      body,
    });
  } catch {
    return NextResponse.json({ error: "Service unavailable" }, { status: 502 });
  }

  if (!upstream.ok || !upstream.body) {
    return NextResponse.json(
      { error: "Service unavailable" },
      { status: upstream.status || 502 }
    );
  }

  return new Response(upstream.body, {
    headers: {
      "Content-Type": "text/event-stream; charset=utf-8",
      "Cache-Control": "no-cache, no-transform",
      Connection: "keep-alive",
    },
  });
}
