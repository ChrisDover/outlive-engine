import { getServerSession } from "next-auth";
import { NextResponse } from "next/server";
import { authOptions } from "@/lib/auth";

// Restarting the server process is a local self-host convenience only — never
// expose it in a hosted/multi-user deployment (it is a trivial DoS vector).
const isLocalDev =
  process.env.NODE_ENV === "development" &&
  (process.env.NEXTAUTH_URL?.includes("localhost") ?? false);

export async function POST() {
  const session = await getServerSession(authOptions);
  if (!session?.user?.id) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }
  if (!isLocalDev) {
    return NextResponse.json({ error: "Not available in this environment" }, { status: 403 });
  }

  // Send SIGUSR2 to trigger a restart in Next.js dev mode
  // Falls back to exiting the process (nodemon/dev watcher will restart it)
  setTimeout(() => {
    try {
      process.kill(process.pid, "SIGUSR2");
    } catch {
      process.exit(0);
    }
  }, 500);

  return NextResponse.json({ restarting: true });
}
