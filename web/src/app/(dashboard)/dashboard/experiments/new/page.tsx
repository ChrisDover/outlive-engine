import { NewExperimentForm } from "../NewExperimentForm";

export default function NewExperimentPage() {
  return (
    <div className="max-w-4xl mx-auto">
      <h1 className="text-2xl font-bold text-foreground mb-[var(--space-lg)]">
        New Experiment
      </h1>
      <NewExperimentForm />
    </div>
  );
}
