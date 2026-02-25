'use client';

import { useState } from 'react';

interface AdherenceItem {
  id?: string;
  item_type: string;
  item_name: string;
  completed: boolean;
}

interface AdherenceLoggerProps {
  items: AdherenceItem[];
  onToggle: (itemType: string, itemName: string, completed: boolean) => Promise<void>;
  onQuickLog?: (message: string) => Promise<void>;
}

export function AdherenceLogger({ items, onToggle, onQuickLog }: AdherenceLoggerProps) {
  const [quickLogText, setQuickLogText] = useState('');
  const [isLogging, setIsLogging] = useState(false);
  const [loadingItem, setLoadingItem] = useState<string | null>(null);

  const handleToggle = async (item: AdherenceItem) => {
    const key = `${item.item_type}-${item.item_name}`;
    setLoadingItem(key);
    try {
      await onToggle(item.item_type, item.item_name, !item.completed);
    } finally {
      setLoadingItem(null);
    }
  };

  const handleQuickLog = async () => {
    if (!quickLogText.trim() || !onQuickLog) return;

    setIsLogging(true);
    try {
      await onQuickLog(quickLogText);
      setQuickLogText('');
    } finally {
      setIsLogging(false);
    }
  };

  const groupedItems = items.reduce((acc, item) => {
    if (!acc[item.item_type]) {
      acc[item.item_type] = [];
    }
    acc[item.item_type].push(item);
    return acc;
  }, {} as Record<string, AdherenceItem[]>);

  const typeColors: Record<string, string> = {
    supplement: 'text-supplements',
    training: 'text-training',
    intervention: 'text-interventions',
    nutrition: 'text-nutrition',
  };

  const completedCount = items.filter((i) => i.completed).length;
  const totalCount = items.length;

  return (
    <div className="bg-card border border-[var(--surface-elevated)]">
      {/* Header */}
      <div className="flex items-center justify-between p-[var(--space-md)] border-b border-[var(--surface-elevated)]">
        <div className="flex items-center gap-[var(--space-sm)]">
          <span className="text-training">{'>'}</span>
          <span className="text-foreground font-semibold">TODAY&apos;S CHECKLIST</span>
        </div>
        <span className="text-muted">
          {completedCount}/{totalCount} done
        </span>
      </div>

      {/* Quick Log Input */}
      {onQuickLog && (
        <div className="p-[var(--space-md)] border-b border-[var(--surface-elevated)]">
          <div className="flex gap-[var(--space-sm)]">
            <input
              type="text"
              value={quickLogText}
              onChange={(e) => setQuickLogText(e.target.value)}
              onKeyDown={(e) => e.key === 'Enter' && handleQuickLog()}
              placeholder="Quick log: cold plunge, took supplements, 45min workout..."
              className="flex-1 bg-[var(--surface-secondary)] border border-[var(--surface-elevated)] px-[var(--space-sm)] py-[var(--space-xs)] text-foreground placeholder:text-muted focus:outline-none focus:border-training"
              disabled={isLogging}
            />
            <button
              onClick={handleQuickLog}
              disabled={isLogging || !quickLogText.trim()}
              className="px-[var(--space-md)] py-[var(--space-xs)] bg-training text-black font-semibold disabled:opacity-50 disabled:cursor-not-allowed hover:opacity-90 transition-opacity"
            >
              {isLogging ? 'LOGGING...' : 'LOG'}
            </button>
          </div>
        </div>
      )}

      {/* Items by Type */}
      {Object.keys(groupedItems).length > 0 ? (
        <div className="divide-y divide-[var(--surface-elevated)]">
          {Object.entries(groupedItems).map(([type, typeItems]) => (
            <div key={type} className="p-[var(--space-md)]">
              <h4 className={`text-sm mb-[var(--space-sm)] ${typeColors[type] || 'text-muted'}`}>
                {type.toUpperCase()}
              </h4>
              <div className="space-y-[var(--space-xs)]">
                {typeItems.map((item) => {
                  const key = `${item.item_type}-${item.item_name}`;
                  const isLoading = loadingItem === key;

                  return (
                    <label
                      key={key}
                      className={`flex items-center gap-[var(--space-sm)] cursor-pointer group ${
                        isLoading ? 'opacity-50' : ''
                      }`}
                    >
                      <input
                        type="checkbox"
                        checked={item.completed}
                        onChange={() => handleToggle(item)}
                        disabled={isLoading}
                        className="w-4 h-4 accent-[var(--recovery-green)] cursor-pointer"
                      />
                      <span
                        className={`${
                          item.completed
                            ? 'text-muted line-through'
                            : 'text-foreground group-hover:text-[var(--recovery-green)]'
                        } transition-colors`}
                      >
                        {item.item_name}
                      </span>
                      {isLoading && (
                        <span className="text-xs text-muted animate-pulse">saving...</span>
                      )}
                    </label>
                  );
                })}
              </div>
            </div>
          ))}
        </div>
      ) : (
        <div className="p-[var(--space-lg)] text-center text-muted">
          No items to track today. Generate a daily plan or use quick log above.
        </div>
      )}
    </div>
  );
}
