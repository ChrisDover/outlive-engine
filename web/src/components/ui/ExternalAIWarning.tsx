'use client';

import { useState } from 'react';

interface ExternalAIWarningProps {
  isOpen: boolean;
  onClose: () => void;
  onAcknowledge: () => Promise<void>;
}

export function ExternalAIWarning({ isOpen, onClose, onAcknowledge }: ExternalAIWarningProps) {
  const [acknowledged, setAcknowledged] = useState(false);
  const [loading, setLoading] = useState(false);

  if (!isOpen) return null;

  async function handleAcknowledge() {
    if (!acknowledged) return;

    setLoading(true);
    try {
      await onAcknowledge();
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center">
      {/* Backdrop */}
      <div
        className="absolute inset-0 bg-black/50 backdrop-blur-sm"
        onClick={onClose}
      />

      {/* Modal */}
      <div className="relative bg-card border border-[var(--surface-elevated)] rounded-[var(--radius-md)] max-w-lg w-full mx-4 shadow-xl">
        {/* Header */}
        <div className="flex items-center justify-between p-[var(--space-md)] border-b border-[var(--surface-elevated)]">
          <div className="flex items-center gap-[var(--space-sm)]">
            <span className="text-2xl">⚠️</span>
            <h2 className="text-lg font-semibold text-foreground">External AI Warning</h2>
          </div>
          <button
            onClick={onClose}
            className="text-muted hover:text-foreground transition-colors"
          >
            ✕
          </button>
        </div>

        {/* Content */}
        <div className="p-[var(--space-lg)] space-y-[var(--space-md)]">
          <p className="text-foreground">
            Enabling external AI will send your health data to third-party servers. This includes:
          </p>

          <ul className="space-y-[var(--space-xs)] text-muted">
            <li className="flex items-start gap-[var(--space-sm)]">
              <span className="text-recovery-yellow">•</span>
              <span><strong>Genomic summaries</strong> — Your SNP analysis and genetic risk factors</span>
            </li>
            <li className="flex items-start gap-[var(--space-sm)]">
              <span className="text-recovery-yellow">•</span>
              <span><strong>Bloodwork markers</strong> — Lab results and biomarker values</span>
            </li>
            <li className="flex items-start gap-[var(--space-sm)]">
              <span className="text-recovery-yellow">•</span>
              <span><strong>Wearable data</strong> — Sleep, HRV, recovery, and activity metrics</span>
            </li>
            <li className="flex items-start gap-[var(--space-sm)]">
              <span className="text-recovery-yellow">•</span>
              <span><strong>Protocol history</strong> — Your daily plans and adherence data</span>
            </li>
          </ul>

          <div className="bg-recovery-red/10 border border-recovery-red/30 rounded-[var(--radius-sm)] p-[var(--space-md)]">
            <p className="text-sm text-foreground">
              <strong>Privacy Notice:</strong> External AI providers (Anthropic, OpenAI) may retain your data according to their privacy policies. This data cannot be recalled once sent.
            </p>
          </div>

          <div className="bg-[var(--surface-secondary)] rounded-[var(--radius-sm)] p-[var(--space-md)]">
            <p className="text-sm text-muted">
              <strong>Recommendation:</strong> For maximum privacy, keep local AI enabled. Local processing never sends your health data off your machine.
            </p>
          </div>

          {/* Acknowledgment checkbox */}
          <label className="flex items-start gap-[var(--space-sm)] cursor-pointer">
            <input
              type="checkbox"
              checked={acknowledged}
              onChange={(e) => setAcknowledged(e.target.checked)}
              className="mt-1 w-4 h-4 rounded border-[var(--surface-elevated)] bg-[var(--surface-secondary)] text-training focus:ring-training"
            />
            <span className="text-sm text-foreground">
              I understand that my health data will be sent to external servers and I accept this risk.
            </span>
          </label>
        </div>

        {/* Footer */}
        <div className="flex gap-[var(--space-sm)] p-[var(--space-md)] border-t border-[var(--surface-elevated)]">
          <button
            onClick={onClose}
            className="flex-1 py-[var(--space-sm)] bg-[var(--surface-elevated)] text-foreground rounded-[var(--radius-sm)] font-medium hover:opacity-90 transition-opacity"
          >
            Keep Local Only
          </button>
          <button
            onClick={handleAcknowledge}
            disabled={!acknowledged || loading}
            className="flex-1 py-[var(--space-sm)] bg-recovery-yellow text-black rounded-[var(--radius-sm)] font-medium hover:opacity-90 transition-opacity disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {loading ? 'Enabling...' : 'Enable External AI'}
          </button>
        </div>
      </div>
    </div>
  );
}
