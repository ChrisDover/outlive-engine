// ExperimentDashboardView.swift
// OutliveEngine
//
// Overview of all N-of-1 experiments grouped by status.

import SwiftUI
import SwiftData

struct ExperimentDashboardView: View {

    @Query(sort: \Experiment.startDate, order: .reverse)
    private var experiments: [Experiment]

    @State private var showingNewExperiment = false

    private var activeExperiments: [Experiment] {
        experiments.filter { $0.status == .baseline || $0.status == .testing }
    }

    private var designingExperiments: [Experiment] {
        experiments.filter { $0.status == .designing }
    }

    private var analyzingExperiments: [Experiment] {
        experiments.filter { $0.status == .analyzing }
    }

    private var completedExperiments: [Experiment] {
        experiments.filter { $0.status == .completed }
    }

    var body: some View {
        NavigationStack {
            Group {
                if experiments.isEmpty {
                    EmptyStateView(
                        icon: "flask",
                        title: "No Experiments",
                        message: "Run N-of-1 experiments to test what works best for your body. Track metrics, compare baselines, and discover your optimal protocols.",
                        actionTitle: "New Experiment"
                    ) {
                        showingNewExperiment = true
                    }
                } else {
                    experimentList
                }
            }
            .navigationTitle("Experiments")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingNewExperiment = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.outliveHeadline)
                    }
                }
            }
            .sheet(isPresented: $showingNewExperiment) {
                NewExperimentView()
            }
            .background(Color.surfaceBackground)
        }
    }

    // MARK: - Experiment List

    private var experimentList: some View {
        ScrollView {
            VStack(spacing: OutliveSpacing.lg) {
                if !activeExperiments.isEmpty {
                    experimentSection(title: "Active", experiments: activeExperiments, icon: "bolt.fill", color: .recoveryGreen)
                }

                if !designingExperiments.isEmpty {
                    experimentSection(title: "Designing", experiments: designingExperiments, icon: "pencil.and.outline", color: .domainTraining)
                }

                if !analyzingExperiments.isEmpty {
                    experimentSection(title: "Analyzing", experiments: analyzingExperiments, icon: "chart.bar.xaxis", color: .domainNutrition)
                }

                if !completedExperiments.isEmpty {
                    experimentSection(title: "Completed", experiments: completedExperiments, icon: "checkmark.circle.fill", color: .textSecondary)
                }
            }
            .padding(.horizontal, OutliveSpacing.md)
            .padding(.bottom, OutliveSpacing.xl)
        }
    }

    private func experimentSection(title: String, experiments: [Experiment], icon: String, color: Color) -> some View {
        VStack(spacing: OutliveSpacing.sm) {
            SectionHeader(title: title)

            ForEach(experiments) { experiment in
                NavigationLink {
                    if experiment.status == .completed {
                        ExperimentResultView(experiment: experiment)
                    } else {
                        ActiveExperimentView(experiment: experiment)
                    }
                } label: {
                    ExperimentCard(experiment: experiment, accentColor: color)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Experiment Card

private struct ExperimentCard: View {

    let experiment: Experiment
    let accentColor: Color

    var body: some View {
        HStack(spacing: OutliveSpacing.sm) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(accentColor)
                .frame(width: 4, height: 56)

            VStack(alignment: .leading, spacing: OutliveSpacing.xxs) {
                Text(experiment.title)
                    .font(.outliveHeadline)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)

                Text(experiment.hypothesis)
                    .font(.outliveSubheadline)
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(2)

                HStack(spacing: OutliveSpacing.xs) {
                    statusBadge

                    Text("\(experiment.trackedMetrics.count) metrics")
                        .font(.outliveCaption)
                        .foregroundStyle(Color.textTertiary)

                    if let days = daysInfo {
                        Text(days)
                            .font(.outliveCaption)
                            .foregroundStyle(Color.textTertiary)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.outliveCaption)
                .foregroundStyle(Color.textTertiary)
        }
        .padding(OutliveSpacing.md)
        .background(Color.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.medium, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
    }

    private var statusBadge: some View {
        Text(experiment.status.rawValue.capitalized)
            .font(.outliveCaption)
            .foregroundStyle(accentColor)
            .padding(.horizontal, OutliveSpacing.xs)
            .padding(.vertical, 2)
            .background(accentColor.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.small, style: .continuous))
    }

    private var daysInfo: String? {
        let elapsed = Calendar.current.dateComponents([.day], from: experiment.startDate, to: Date()).day ?? 0
        if let endDate = experiment.endDate {
            let total = Calendar.current.dateComponents([.day], from: experiment.startDate, to: endDate).day ?? 0
            return "Day \(elapsed)/\(total)"
        }
        return "Day \(elapsed)"
    }
}

// MARK: - Preview

#Preview {
    ExperimentDashboardView()
        .modelContainer(for: Experiment.self, inMemory: true)
}
