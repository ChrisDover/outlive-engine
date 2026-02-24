export default function DashboardLoading() {
  return (
    <div className="max-w-4xl mx-auto space-y-[var(--space-lg)] animate-pulse">
      {/* Heading skeleton */}
      <div className="h-8 w-48 bg-[var(--surface-elevated)] rounded-[var(--radius-sm)]" />
      <div className="h-4 w-32 bg-[var(--surface-elevated)] rounded-[var(--radius-sm)]" />

      {/* Card skeletons */}
      {[1, 2, 3].map((i) => (
        <div
          key={i}
          className="bg-card rounded-[var(--radius-md)] border border-[var(--surface-elevated)] p-[var(--space-md)] space-y-[var(--space-sm)]"
        >
          <div className="h-5 w-40 bg-[var(--surface-elevated)] rounded-[var(--radius-sm)]" />
          <div className="h-4 w-full bg-[var(--surface-elevated)] rounded-[var(--radius-sm)]" />
          <div className="h-4 w-3/4 bg-[var(--surface-elevated)] rounded-[var(--radius-sm)]" />
        </div>
      ))}
    </div>
  );
}
