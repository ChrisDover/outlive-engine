"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import Link from "next/link";
import { signIn } from "next-auth/react";

export default function SignupPage() {
  const router = useRouter();
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError("");

    const res = await fetch("/api/auth/signup", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email, password, name }),
    });

    if (!res.ok) {
      const data = await res.json();
      setError(data.error || "Signup failed");
      setLoading(false);
      return;
    }

    // Auto-login after signup
    const result = await signIn("credentials", {
      email,
      password,
      redirect: false,
    });

    if (result?.ok) {
      router.push("/dashboard");
    } else {
      setError("Account created but login failed. Please sign in.");
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-background p-[var(--space-md)]">
      <div className="w-full max-w-md bg-card rounded-[var(--radius-lg)] p-[var(--space-xl)] shadow-lg">
        <h1 className="text-2xl font-bold text-foreground mb-[var(--space-lg)]">
          Create your account
        </h1>

        {error && (
          <div className="mb-[var(--space-md)] p-[var(--space-sm)] bg-recovery-red/10 border border-recovery-red/30 rounded-[var(--radius-sm)] text-recovery-red text-sm">
            {error}
          </div>
        )}

        <form onSubmit={handleSubmit} className="space-y-[var(--space-md)]">
          <div>
            <label className="block text-sm text-muted mb-1">Name</label>
            <input
              type="text"
              value={name}
              onChange={(e) => setName(e.target.value)}
              className="w-full px-[var(--space-md)] py-[var(--space-sm)] bg-elevated border border-[var(--surface-elevated)] rounded-[var(--radius-sm)] text-foreground focus:outline-none focus:ring-2 focus:ring-training"
            />
          </div>
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
              minLength={8}
            />
          </div>
          <button
            type="submit"
            disabled={loading}
            className="w-full py-[var(--space-sm)] bg-training text-white rounded-[var(--radius-sm)] font-medium hover:opacity-90 disabled:opacity-50 transition-opacity"
          >
            {loading ? "Creating account..." : "Sign Up"}
          </button>
        </form>

        <p className="mt-[var(--space-lg)] text-center text-sm text-muted">
          Already have an account?{" "}
          <Link href="/login" className="text-training hover:underline">
            Sign in
          </Link>
        </p>
      </div>
    </div>
  );
}
