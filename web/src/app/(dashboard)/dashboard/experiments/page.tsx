import { EmptyState } from "@/components/ui/EmptyState";

export default function ExperimentsPage() {
  return (
    <div className="max-w-4xl mx-auto">
      <h1 className="text-2xl font-bold text-foreground mb-[var(--space-lg)]">Experiments</h1>
      <EmptyState
        title="No experiments yet"
        description="Design N=1 experiments to test supplements, protocols, and lifestyle changes with tracked outcomes."
      />
    </div>
  );
}
