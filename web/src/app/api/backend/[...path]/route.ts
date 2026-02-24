import { NextRequest, NextResponse } from "next/server";
import { getServerSession } from "next-auth";
import { authOptions } from "@/lib/auth";
import { prisma } from "@/lib/prisma";

const BACKEND_URL = process.env.OUTLIVE_BACKEND_URL || "http://localhost:8000";
const SERVICE_KEY = process.env.OUTLIVE_SERVICE_KEY || "";

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
  const url = `${BACKEND_URL}/api/v1${fullPath}`;

  const contentType = request.headers.get("content-type") || "";

  try {
    let fetchOptions: RequestInit;

    if (contentType.includes("multipart/form-data")) {
      // Handle file uploads - pass through FormData
      const formData = await request.formData();
      fetchOptions = {
        method: request.method,
        headers: {
          Authorization: `Bearer ${SERVICE_KEY}`,
          "X-Outlive-User-Id": user.backendUserId,
        },
        body: formData,
      };
    } else {
      // Handle JSON and other requests
      let body: string | undefined;
      if (request.method !== "GET" && request.method !== "HEAD") {
        body = await request.text();
      }
      fetchOptions = {
        method: request.method,
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${SERVICE_KEY}`,
          "X-Outlive-User-Id": user.backendUserId,
        },
        body,
      };
    }

    const response = await fetch(url, fetchOptions);

    if (!response.ok) {
      throw new Error(`Backend ${response.status}: request failed`);
    }

    const responseContentType = response.headers.get("content-type");
    if (responseContentType?.includes("application/json")) {
      const data = await response.json();
      return NextResponse.json(data);
    }
    const text = await response.text();
    return new NextResponse(text);
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
