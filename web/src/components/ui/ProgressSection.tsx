'use client';

import { useState } from 'react';

interface Goal {
  id: string;
  category: string;
  target_metric: string;
  target_value?: number;
  target_unit?: string;
  deadline?: string;
  status: string;
}

interface ProgressStats {
  this_week: {
    total: number;
    completed: number;
    rate: number;
  };
  this_month: {
    total: number;
    completed: number;
    rate: number;
  };
  current_streak: number;
  active_goals: number;
}

interface ProgressSectionProps {
  goals: Goal[];
  stats?: ProgressStats;
  onAddGoal?: () => void;
  onUpdateGoalStatus?: (goalId: string, status: string) => Promise<void>;
}

export function ProgressSection({
  goals,
  stats,
  onAddGoal,
  onUpdateGoalStatus,
}: ProgressSectionProps) {
  const [expandedSection, setExpandedSection] = useState<'goals' | 'stats' | null>('stats');

  const activeGoals = goals.filter((g) => g.status === 'active');

  const categoryColors: Record<string, string> = {
    biomarker: 'text-bloodwork',
    fitness: 'text-training',
    habit: 'text-supplements',
  };

  return (
    <div className="bg-card border border-[var(--surface-elevated)]">
      {/* Header */}
      <div className="flex items-center justify-between p-[var(--space-md)] border-b border-[var(--surface-elevated)]">
        <div className="flex items-center gap-[var(--space-sm)]">
          <span className="text-training">{'>'}</span>
          <span className="text-foreground font-semibold">PROGRESS</span>
        </div>
        <div className="flex gap-[var(--space-md)]">
          <button
            onClick={() => setExpandedSection(expandedSection === 'stats' ? null : 'stats')}
            className={`text-sm ${expandedSection === 'stats' ? 'text-training' : 'text-muted'} hover:text-training transition-colors`}
          >
            STATS
          </button>
          <button
            onClick={() => setExpandedSection(expandedSection === 'goals' ? null : 'goals')}
            className={`text-sm ${expandedSection === 'goals' ? 'text-training' : 'text-muted'} hover:text-training transition-colors`}
          >
            GOALS ({activeGoals.length})
          </button>
        </div>
      </div>

      {/* Stats Section */}
      {expandedSection === 'stats' && stats && (
        <div className="p-[var(--space-md)] space-y-[var(--space-md)]">
          {/* Streak */}
          <div className="flex items-center justify-between">
            <span className="text-muted">Current Streak</span>
            <span className="text-[var(--recovery-green)] font-semibold text-lg">
              {stats.current_streak} days
            </span>
          </div>

          {/* Weekly Progress Bar */}
          <div>
            <div className="flex items-center justify-between mb-[var(--space-xs)]">
              <span className="text-muted text-sm">This Week</span>
              <span className="text-foreground text-sm">
                {stats.this_week.completed}/{stats.this_week.total} ({stats.this_week.rate}%)
              </span>
            </div>
            <div className="h-2 bg-[var(--surface-secondary)] overflow-hidden">
              <div
                className="h-full bg-[var(--recovery-green)] transition-all duration-500"
                style={{ width: `${stats.this_week.rate}%` }}
              />
            </div>
          </div>

          {/* Monthly Progress Bar */}
          <div>
            <div className="flex items-center justify-between mb-[var(--space-xs)]">
              <span className="text-muted text-sm">This Month</span>
              <span className="text-foreground text-sm">
                {stats.this_month.completed}/{stats.this_month.total} ({stats.this_month.rate}%)
              </span>
            </div>
            <div className="h-2 bg-[var(--surface-secondary)] overflow-hidden">
              <div
                className="h-full bg-training transition-all duration-500"
                style={{ width: `${stats.this_month.rate}%` }}
              />
            </div>
          </div>
        </div>
      )}

      {/* Goals Section */}
      {expandedSection === 'goals' && (
        <div className="divide-y divide-[var(--surface-elevated)]">
          {activeGoals.length > 0 ? (
            activeGoals.map((goal) => (
              <div key={goal.id} className="p-[var(--space-md)] flex items-center justify-between">
                <div>
                  <div className="flex items-center gap-[var(--space-sm)]">
                    <span className={`text-xs ${categoryColors[goal.category] || 'text-muted'}`}>
                      {goal.category.toUpperCase()}
                    </span>
                    <span className="text-foreground">{goal.target_metric}</span>
                  </div>
                  {goal.target_value && (
                    <span className="text-muted text-sm">
                      Target: {goal.target_value}
                      {goal.target_unit && ` ${goal.target_unit}`}
                      {goal.deadline && ` by ${new Date(goal.deadline).toLocaleDateString()}`}
                    </span>
                  )}
                </div>
                {onUpdateGoalStatus && (
                  <div className="flex gap-[var(--space-sm)]">
                    <button
                      onClick={() => onUpdateGoalStatus(goal.id, 'achieved')}
                      className="text-xs text-[var(--recovery-green)] hover:underline"
                    >
                      ACHIEVED
                    </button>
                    <button
                      onClick={() => onUpdateGoalStatus(goal.id, 'abandoned')}
                      className="text-xs text-[var(--recovery-red)] hover:underline"
                    >
                      ABANDON
                    </button>
                  </div>
                )}
              </div>
            ))
          ) : (
            <div className="p-[var(--space-lg)] text-center">
              <p className="text-muted mb-[var(--space-md)]">No active goals</p>
              {onAddGoal && (
                <button
                  onClick={onAddGoal}
                  className="text-training hover:underline"
                >
                  + Add a goal
                </button>
              )}
            </div>
          )}

          {activeGoals.length > 0 && onAddGoal && (
            <div className="p-[var(--space-sm)] text-center">
              <button onClick={onAddGoal} className="text-sm text-muted hover:text-training transition-colors">
                + Add Goal
              </button>
            </div>
          )}
        </div>
      )}
    </div>
  );
}
