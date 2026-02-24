import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";

export async function GET(request: NextRequest) {
  const code = request.nextUrl.searchParams.get("code");
  const state = request.nextUrl.searchParams.get("state"); // user ID
  const error = request.nextUrl.searchParams.get("error");

  if (error || !code || !state) {
    return NextResponse.redirect(new URL("/dashboard/settings?error=oura_auth_failed", request.url));
  }

  const clientId = process.env.OURA_CLIENT_ID!;
  const clientSecret = process.env.OURA_CLIENT_SECRET!;
  const redirectUri = process.env.OURA_REDIRECT_URI || `${process.env.NEXTAUTH_URL}/api/oauth/oura/callback`;

  try {
    const tokenResponse = await fetch("https://api.ouraring.com/oauth/token", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        grant_type: "authorization_code",
        code,
        redirect_uri: redirectUri,
        client_id: clientId,
        client_secret: clientSecret,
      }),
    });

    if (!tokenResponse.ok) {
      return NextResponse.redirect(new URL("/dashboard/settings?error=oura_token_failed", request.url));
    }

    const tokens = await tokenResponse.json();

    await prisma.user.update({
      where: { id: state },
      data: {
        ouraAccessToken: tokens.access_token,
        ouraRefreshToken: tokens.refresh_token,
      },
    });

    return NextResponse.redirect(new URL("/dashboard?connected=oura", request.url));
  } catch {
    return NextResponse.redirect(new URL("/dashboard/settings?error=oura_exchange_failed", request.url));
  }
}
