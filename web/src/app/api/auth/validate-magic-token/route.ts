import { redirect } from "next/navigation";
import { NextRequest } from "next/server";

export async function GET(request: NextRequest) {
  const token = request.nextUrl.searchParams.get("token");

  if (!token) {
    redirect("/login?error=InvalidToken");
  }

  // Redirect to login page with the token for client-side signIn
  redirect(`/login?magic-token=${token}`);
}
