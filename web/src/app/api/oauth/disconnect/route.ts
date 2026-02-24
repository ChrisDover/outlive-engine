import { getServerSession } from "next-auth";
import { NextRequest, NextResponse } from "next/server";
import { authOptions } from "@/lib/auth";
import { prisma } from "@/lib/prisma";

export async function POST(request: NextRequest) {
  const session = await getServerSession(authOptions);
  if (!session?.user?.id) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const { provider } = await request.json();

  if (!["oura", "whoop"].includes(provider)) {
    return NextResponse.json({ error: "Invalid provider" }, { status: 400 });
  }

  const data: Record<string, null> = {};
  if (provider === "oura") {
    data.ouraAccessToken = null;
    data.ouraRefreshToken = null;
  } else if (provider === "whoop") {
    data.whoopAccessToken = null;
    data.whoopRefreshToken = null;
  }

  await prisma.user.update({
    where: { id: session.user.id },
    data,
  });

  return NextResponse.json({ disconnected: provider });
}
