import { EmptyState } from "@/components/ui/EmptyState";

export default function BloodworkPage() {
  return (
    <div className="max-w-4xl mx-auto">
      <h1 className="text-2xl font-bold text-foreground mb-[var(--space-lg)]">Bloodwork</h1>
      <EmptyState
        title="No bloodwork panels yet"
        description="Upload lab results or manually enter biomarkers to track trends over time."
      />
    </div>
  );
}
