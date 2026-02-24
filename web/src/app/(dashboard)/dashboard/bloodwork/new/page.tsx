import { NewPanelForm } from "../NewPanelForm";

export default function NewPanelPage() {
  return (
    <div className="max-w-4xl mx-auto">
      <h1 className="text-2xl font-bold text-foreground mb-[var(--space-lg)]">
        Add Bloodwork Panel
      </h1>
      <NewPanelForm />
    </div>
  );
}
