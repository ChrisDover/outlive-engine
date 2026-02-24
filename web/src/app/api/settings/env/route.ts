import { getServerSession } from "next-auth";
import { NextRequest, NextResponse } from "next/server";
import { authOptions } from "@/lib/auth";
import { readFile, writeFile } from "fs/promises";
import { join } from "path";

const ENV_PATH = join(process.cwd(), ".env");

// Only these keys can be read/written through the UI
const ALLOWED_KEYS = new Set([
  "OURA_CLIENT_ID",
  "OURA_CLIENT_SECRET",
  "WHOOP_CLIENT_ID",
  "WHOOP_CLIENT_SECRET",
]);

function parseEnv(content: string): Map<string, string> {
  const map = new Map<string, string>();
  for (const line of content.split("\n")) {
    const match = line.match(/^([A-Z_]+)=(.*)$/);
    if (match) {
      map.set(match[1], match[2]);
    }
  }
  return map;
}

function serializeEnv(original: string, updates: Map<string, string>): string {
  const lines = original.split("\n");
  const result: string[] = [];
  const seen = new Set<string>();

  for (const line of lines) {
    const match = line.match(/^([A-Z_]+)=/);
    if (match && updates.has(match[1])) {
      result.push(`${match[1]}=${updates.get(match[1])}`);
      seen.add(match[1]);
    } else {
      result.push(line);
    }
  }

  // Append any new keys not already in the file
  for (const [key, value] of updates) {
    if (!seen.has(key)) {
      result.push(`${key}=${value}`);
    }
  }

  return result.join("\n");
}

/** GET: return current values (secrets masked) */
export async function GET() {
  const session = await getServerSession(authOptions);
  if (!session?.user?.id) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  try {
    const content = await readFile(ENV_PATH, "utf-8");
    const env = parseEnv(content);
    const result: Record<string, string> = {};

    for (const key of ALLOWED_KEYS) {
      const value = env.get(key) || "";
      // Mask secrets — show first 4 chars + asterisks if set
      if (key.includes("SECRET") && value.length > 4) {
        result[key] = value.slice(0, 4) + "••••••••";
      } else {
        result[key] = value;
      }
    }

    return NextResponse.json(result);
  } catch {
    return NextResponse.json({ error: "Could not read .env file" }, { status: 500 });
  }
}

/** POST: update allowed env vars and write to .env */
export async function POST(request: NextRequest) {
  const session = await getServerSession(authOptions);
  if (!session?.user?.id) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  try {
    const body = await request.json();
    const updates = new Map<string, string>();

    for (const [key, value] of Object.entries(body)) {
      if (ALLOWED_KEYS.has(key) && typeof value === "string") {
        // Skip masked values (user didn't change the secret)
        if (value.includes("••••")) continue;
        updates.set(key, value.trim());
      }
    }

    if (updates.size === 0) {
      return NextResponse.json({ error: "No valid keys to update" }, { status: 400 });
    }

    const original = await readFile(ENV_PATH, "utf-8");
    const updated = serializeEnv(original, updates);
    await writeFile(ENV_PATH, updated, "utf-8");

    // Update process.env so the current process picks up changes immediately
    for (const [key, value] of updates) {
      process.env[key] = value;
    }

    return NextResponse.json({ saved: Array.from(updates.keys()) });
  } catch {
    return NextResponse.json({ error: "Could not write .env file" }, { status: 500 });
  }
}
