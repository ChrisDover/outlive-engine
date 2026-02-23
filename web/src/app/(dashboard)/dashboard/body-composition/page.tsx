import { EmptyState } from "@/components/ui/EmptyState";

export default function BodyCompositionPage() {
  return (
    <div className="max-w-4xl mx-auto">
      <h1 className="text-2xl font-bold text-foreground mb-[var(--space-lg)]">Body Composition</h1>
      <EmptyState
        title="No body composition data yet"
        description="Log weight, body fat, lean mass, and other measurements to track trends."
      />
    </div>
  );
}
