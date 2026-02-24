"use client";

export default function DashboardError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  return (
    <div className="flex flex-col items-center justify-center py-[var(--space-xxl)] text-center">
      <p className="text-lg font-medium text-foreground">Something went wrong</p>
      <p className="text-sm text-muted mt-[var(--space-xs)] max-w-md">
        An unexpected error occurred. Please try again.
      </p>
      <button
        onClick={reset}
        className="mt-[var(--space-lg)] px-[var(--space-lg)] py-[var(--space-sm)] bg-training text-white rounded-[var(--radius-sm)] font-medium hover:opacity-90 transition-opacity"
      >
        Try Again
      </button>
    </div>
  );
}
