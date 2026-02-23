import { EmptyState } from "@/components/ui/EmptyState";

export default function GenomicsPage() {
  return (
    <div className="max-w-4xl mx-auto">
      <h1 className="text-2xl font-bold text-foreground mb-[var(--space-lg)]">Genomics</h1>
      <EmptyState
        title="No genomic data yet"
        description="Upload your genetic data to see risk categories and personalized recommendations."
      />
    </div>
  );
}
