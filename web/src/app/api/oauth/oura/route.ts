import { getServerSession } from "next-auth";
import { NextResponse } from "next/server";
import { authOptions } from "@/lib/auth";

export async function GET() {
  const session = await getServerSession(authOptions);
  if (!session?.user?.id) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const clientId = process.env.OURA_CLIENT_ID;
  const redirectUri = process.env.OURA_REDIRECT_URI || `${process.env.NEXTAUTH_URL}/api/oauth/oura/callback`;

  if (!clientId) {
    return NextResponse.json({ error: "Oura OAuth not configured" }, { status: 500 });
  }

  const params = new URLSearchParams({
    response_type: "code",
    client_id: clientId,
    redirect_uri: redirectUri,
    scope: "daily sleep heartrate personal",
    state: session.user.id,
  });

  return NextResponse.redirect(`https://cloud.ouraring.com/oauth/authorize?${params.toString()}`);
}
