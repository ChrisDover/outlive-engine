import { NextRequest, NextResponse } from "next/server";
import { cookies } from "next/headers";
import { prisma } from "@/lib/prisma";

export async function GET(request: NextRequest) {
  const code = request.nextUrl.searchParams.get("code");
  const state = request.nextUrl.searchParams.get("state");
  const error = request.nextUrl.searchParams.get("error");

  if (error || !code || !state) {
    return NextResponse.redirect(new URL("/dashboard/settings?error=withings_auth_failed", request.url));
  }

  const cookieStore = await cookies();
  const codeVerifier = cookieStore.get("withings_code_verifier")?.value;
  if (!codeVerifier) {
    return NextResponse.redirect(new URL("/dashboard/settings?error=withings_pkce_missing", request.url));
  }

  const clientId = process.env.WITHINGS_CLIENT_ID!;
  const clientSecret = process.env.WITHINGS_CLIENT_SECRET!;
  const redirectUri = process.env.WITHINGS_REDIRECT_URI || `${process.env.NEXTAUTH_URL}/api/oauth/withings/callback`;

  try {
    // Withings token endpoint
    const tokenResponse = await fetch("https://wbsapi.withings.net/v2/oauth2", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        action: "requesttoken",
        grant_type: "authorization_code",
        code,
        redirect_uri: redirectUri,
        client_id: clientId,
        client_secret: clientSecret,
        code_verifier: codeVerifier,
      }),
    });

    if (!tokenResponse.ok) {
      console.error("Withings token request failed:", await tokenResponse.text());
      return NextResponse.redirect(new URL("/dashboard/settings?error=withings_token_failed", request.url));
    }

    const result = await tokenResponse.json();

    // Withings wraps tokens in a "body" object
    if (result.status !== 0 || !result.body) {
      console.error("Withings token error:", result);
      return NextResponse.redirect(new URL("/dashboard/settings?error=withings_token_error", request.url));
    }

    const tokens = result.body;

    await prisma.user.update({
      where: { id: state },
      data: {
        withingsAccessToken: tokens.access_token,
        withingsRefreshToken: tokens.refresh_token,
        withingsUserId: tokens.userid?.toString(),
      },
    });

    // Clear the PKCE cookie
    cookieStore.delete("withings_code_verifier");

    return NextResponse.redirect(new URL("/dashboard?connected=withings", request.url));
  } catch (err) {
    console.error("Withings OAuth error:", err);
    return NextResponse.redirect(new URL("/dashboard/settings?error=withings_exchange_failed", request.url));
  }
}
