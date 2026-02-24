import { getServerSession } from "next-auth";
import { NextResponse } from "next/server";
import { authOptions } from "@/lib/auth";

export async function POST() {
  const session = await getServerSession(authOptions);
  if (!session?.user?.id) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
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
