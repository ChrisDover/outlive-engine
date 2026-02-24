import { NextRequest, NextResponse } from "next/server";
import { cookies } from "next/headers";
import { prisma } from "@/lib/prisma";

export async function GET(request: NextRequest) {
  const code = request.nextUrl.searchParams.get("code");
  const state = request.nextUrl.searchParams.get("state");
  const error = request.nextUrl.searchParams.get("error");

  if (error || !code || !state) {
    return NextResponse.redirect(new URL("/dashboard/settings?error=whoop_auth_failed", request.url));
  }

  const cookieStore = await cookies();
  const codeVerifier = cookieStore.get("whoop_code_verifier")?.value;
  if (!codeVerifier) {
    return NextResponse.redirect(new URL("/dashboard/settings?error=whoop_pkce_missing", request.url));
  }

  const clientId = process.env.WHOOP_CLIENT_ID!;
  const clientSecret = process.env.WHOOP_CLIENT_SECRET!;
  const redirectUri = process.env.WHOOP_REDIRECT_URI || `${process.env.NEXTAUTH_URL}/api/oauth/whoop/callback`;

  try {
    const tokenResponse = await fetch("https://api.prod.whoop.com/oauth/oauth2/token", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        grant_type: "authorization_code",
        code,
        redirect_uri: redirectUri,
        client_id: clientId,
        client_secret: clientSecret,
        code_verifier: codeVerifier,
      }),
    });

    if (!tokenResponse.ok) {
      return NextResponse.redirect(new URL("/dashboard/settings?error=whoop_token_failed", request.url));
    }

    const tokens = await tokenResponse.json();

    await prisma.user.update({
      where: { id: state },
      data: {
        whoopAccessToken: tokens.access_token,
        whoopRefreshToken: tokens.refresh_token,
      },
    });

    // Clear the PKCE cookie
    cookieStore.delete("whoop_code_verifier");

    return NextResponse.redirect(new URL("/dashboard?connected=whoop", request.url));
  } catch {
    return NextResponse.redirect(new URL("/dashboard/settings?error=whoop_exchange_failed", request.url));
  }
}
