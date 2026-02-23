import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";
import { getToken } from "next-auth/jwt";

const publicRoutes = ["/", "/login", "/signup", "/api/auth", "/api/cron"];

export async function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl;

  if (publicRoutes.some((route) => pathname.startsWith(route))) {
    return NextResponse.next();
  }

  // Only protect dashboard and API routes
  const isProtected =
    pathname.startsWith("/dashboard") || pathname.startsWith("/api/");

  if (!isProtected) {
    return NextResponse.next();
  }

  try {
    const token = await getToken({
      req: request,
      secret: process.env.NEXTAUTH_SECRET,
    });

    if (!token) {
      if (pathname.startsWith("/api/")) {
        return NextResponse.json(
          { error: "Session expired", code: "SESSION_EXPIRED" },
          { status: 401 }
        );
      }
      const loginUrl = new URL("/login", request.url);
      loginUrl.searchParams.set("callbackUrl", pathname);
      return NextResponse.redirect(loginUrl);
    }

    return NextResponse.next();
  } catch (error) {
    console.error("Session validation error:", error);

    if (pathname.startsWith("/api/")) {
      const response = NextResponse.json(
        { error: "Invalid session", code: "INVALID_SESSION" },
        { status: 401 }
      );
      response.cookies.set("next-auth.session-token", "", { maxAge: 0 });
      response.cookies.set("__Secure-next-auth.session-token", "", {
        maxAge: 0,
      });
      return response;
    }

    const loginUrl = new URL("/login", request.url);
    loginUrl.searchParams.set("error", "SessionExpired");
    const response = NextResponse.redirect(loginUrl);
    response.cookies.set("next-auth.session-token", "", { maxAge: 0 });
    response.cookies.set("__Secure-next-auth.session-token", "", {
      maxAge: 0,
    });
    return response;
  }
}

export const config = {
  matcher: [
    "/((?!_next/static|_next/image|favicon.ico|.*\\.png$|.*\\.jpg$|.*\\.svg$).*)",
  ],
};
