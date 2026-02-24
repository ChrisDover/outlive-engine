const BACKEND_URL = process.env.OUTLIVE_BACKEND_URL || "http://localhost:8000";
const SERVICE_KEY = process.env.OUTLIVE_SERVICE_KEY || "";

export async function backendClient(
  path: string,
  options: RequestInit & { userId?: string } = {}
): Promise<any> {
  const { userId, ...fetchOptions } = options;
  const url = `${BACKEND_URL}/api/v1${path}`;

  const headers: Record<string, string> = {
    "Content-Type": "application/json",
    Authorization: `Bearer ${SERVICE_KEY}`,
    ...(userId ? { "X-Outlive-User-Id": userId } : {}),
    ...(fetchOptions.headers as Record<string, string> || {}),
  };

  const response = await fetch(url, {
    ...fetchOptions,
    headers,
  });

  if (!response.ok) {
    // Include status code for proxy routing but not the raw backend body
    throw new Error(`Backend ${response.status}: request failed`);
  }

  const contentType = response.headers.get("content-type");
  if (contentType?.includes("application/json")) {
    return response.json();
  }
  return response.text();
}
