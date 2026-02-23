"use client";

import { signIn } from "next-auth/react";
import { useRouter, useSearchParams } from "next/navigation";
import { useState, useEffect, Suspense } from "react";
import Link from "next/link";

function LoginForm() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [magicEmail, setMagicEmail] = useState("");
  const [error, setError] = useState("");
  const [magicSent, setMagicSent] = useState(false);
  const [loading, setLoading] = useState(false);
  const [mode, setMode] = useState<"password" | "magic">("password");

  useEffect(() => {
    const magicToken = searchParams.get("magic-token");
    if (magicToken) {
      signIn("magic-link", { token: magicToken, redirect: false }).then(
        (result) => {
          if (result?.ok) {
            router.push("/dashboard");
          } else {
            setError("Invalid or expired magic link");
          }
        }
      );
    }
  }, [searchParams, router]);

  const handlePasswordLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError("");

    const result = await signIn("credentials", {
      email,
      password,
      redirect: false,
    });

    if (result?.error) {
      setError("Invalid email or password");
      setLoading(false);
    } else {
      router.push("/dashboard");
    }
  };

  const handleMagicLink = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError("");

    const res = await fetch("/api/auth/request-magic-link", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email: magicEmail }),
    });

    if (res.ok) {
      setMagicSent(true);
    } else {
      setError("Failed to send magic link");
    }
    setLoading(false);
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-background p-[var(--space-md)]">
      <div className="w-full max-w-md bg-card rounded-[var(--radius-lg)] p-[var(--space-xl)] shadow-lg">
        <h1 className="text-2xl font-bold text-foreground mb-[var(--space-lg)]">
          Sign in to Outlive Engine
        </h1>

        {error && (
          <div className="mb-[var(--space-md)] p-[var(--space-sm)] bg-recovery-red/10 border border-recovery-red/30 rounded-[var(--radius-sm)] text-recovery-red text-sm">
            {error}
          </div>
        )}

        {/* Mode toggle */}
        <div className="flex gap-[var(--space-xs)] mb-[var(--space-lg)]">
          <button
            onClick={() => setMode("password")}
            className={`flex-1 py-[var(--space-xs)] rounded-[var(--radius-sm)] text-sm font-medium transition-colors ${
              mode === "password"
                ? "bg-training text-white"
                : "bg-elevated text-muted"
            }`}
          >
            Password
          </button>
          <button
            onClick={() => setMode("magic")}
            className={`flex-1 py-[var(--space-xs)] rounded-[var(--radius-sm)] text-sm font-medium transition-colors ${
              mode === "magic"
                ? "bg-training text-white"
                : "bg-elevated text-muted"
            }`}
          >
            Magic Link
          </button>
        </div>

        {mode === "password" ? (
          <form onSubmit={handlePasswordLogin} className="space-y-[var(--space-md)]">
            <div>
              <label className="block text-sm text-muted mb-1">Email</label>
              <input
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                className="w-full px-[var(--space-md)] py-[var(--space-sm)] bg-elevated border border-[var(--surface-elevated)] rounded-[var(--radius-sm)] text-foreground focus:outline-none focus:ring-2 focus:ring-training"
                required
              />
            </div>
            <div>
              <label className="block text-sm text-muted mb-1">Password</label>
              <input
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                className="w-full px-[var(--space-md)] py-[var(--space-sm)] bg-elevated border border-[var(--surface-elevated)] rounded-[var(--radius-sm)] text-foreground focus:outline-none focus:ring-2 focus:ring-training"
                required
              />
            </div>
            <button
              type="submit"
              disabled={loading}
              className="w-full py-[var(--space-sm)] bg-training text-white rounded-[var(--radius-sm)] font-medium hover:opacity-90 disabled:opacity-50 transition-opacity"
            >
              {loading ? "Signing in..." : "Sign In"}
            </button>
          </form>
        ) : magicSent ? (
          <div className="text-center py-[var(--space-lg)]">
            <p className="text-foreground font-medium">Check your email</p>
            <p className="text-muted text-sm mt-[var(--space-xs)]">
              We sent a login link to {magicEmail}
            </p>
          </div>
        ) : (
          <form onSubmit={handleMagicLink} className="space-y-[var(--space-md)]">
            <div>
              <label className="block text-sm text-muted mb-1">Email</label>
              <input
                type="email"
                value={magicEmail}
                onChange={(e) => setMagicEmail(e.target.value)}
                className="w-full px-[var(--space-md)] py-[var(--space-sm)] bg-elevated border border-[var(--surface-elevated)] rounded-[var(--radius-sm)] text-foreground focus:outline-none focus:ring-2 focus:ring-training"
                required
              />
            </div>
            <button
              type="submit"
              disabled={loading}
              className="w-full py-[var(--space-sm)] bg-training text-white rounded-[var(--radius-sm)] font-medium hover:opacity-90 disabled:opacity-50 transition-opacity"
            >
              {loading ? "Sending..." : "Send Magic Link"}
            </button>
          </form>
        )}

        <p className="mt-[var(--space-lg)] text-center text-sm text-muted">
          Don&apos;t have an account?{" "}
          <Link href="/signup" className="text-training hover:underline">
            Sign up
          </Link>
        </p>
      </div>
    </div>
  );
}

export default function LoginPage() {
  return (
    <Suspense>
      <LoginForm />
    </Suspense>
  );
}
