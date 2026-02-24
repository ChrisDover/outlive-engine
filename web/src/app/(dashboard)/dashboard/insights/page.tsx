import { InsightsContent } from "./InsightsContent";

export default function InsightsPage() {
  return (
    <div className="max-w-4xl mx-auto">
      <h1 className="text-2xl font-bold text-foreground mb-[var(--space-lg)]">AI Insights</h1>
      <InsightsContent />
    </div>
  );
}
