import { NextRequest, NextResponse } from "next/server";
import { getServerSession } from "next-auth";
import { authOptions } from "@/lib/auth";
import { prisma } from "@/lib/prisma";
import { backendClient } from "@/lib/backend-client";

async function proxyRequest(
  request: NextRequest,
  { params }: { params: Promise<{ path: string[] }> }
) {
  const session = await getServerSession(authOptions);
  if (!session?.user?.id) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const user = await prisma.user.findUnique({
    where: { id: session.user.id },
    select: { backendUserId: true },
  });

  if (!user?.backendUserId) {
    return NextResponse.json(
      { error: "Backend user not linked" },
      { status: 400 }
    );
  }

  const { path } = await params;
  const backendPath = `/${path.join("/")}`;
  const searchParams = request.nextUrl.searchParams.toString();
  const fullPath = searchParams ? `${backendPath}?${searchParams}` : backendPath;

  try {
    let body: string | undefined;
    if (request.method !== "GET" && request.method !== "HEAD") {
      body = await request.text();
    }

    const data = await backendClient(fullPath, {
      method: request.method,
      userId: user.backendUserId,
      body,
    });

    return NextResponse.json(data);
  } catch (error) {
    const message = error instanceof Error ? error.message : "Proxy error";
    const statusMatch = message.match(/Backend (\d+):/);
    const statusCode = statusMatch ? parseInt(statusMatch[1]) : 502;

    // Log full error server-side, return generic message to client
    console.error("Backend proxy error:", message);

    const safeMessages: Record<number, string> = {
      400: "Bad request",
      401: "Unauthorized",
      403: "Forbidden",
      404: "Not found",
      422: "Validation error",
      429: "Too many requests",
    };

    return NextResponse.json(
      { error: safeMessages[statusCode] || "Service unavailable" },
      { status: statusCode }
    );
  }
}

export const GET = proxyRequest;
export const POST = proxyRequest;
export const PUT = proxyRequest;
export const DELETE = proxyRequest;
export const PATCH = proxyRequest;
