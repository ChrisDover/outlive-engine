// DailyDashboardView.swift
// OutliveEngine
//
// Main dashboard screen presenting today's synthesized protocol across all
// health domains: training, nutrition, supplements, interventions, and sleep.

import SwiftUI
import SwiftData

struct DailyDashboardView: View {

    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = DashboardViewModel()

    /// The current user's Apple ID, typically provided by AppState or AuthService.
    let userId: String

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isGenerating {
                    loadingView
                } else if viewModel.dailyProtocol != nil {
                    protocolContent
                } else {
                    emptyState
                }
            }
            .background(Color.surfaceBackground)
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    adherenceToolbarItem
                }
            }
            .onAppear {
                viewModel.loadOrGenerate(modelContext: modelContext, userId: userId)
            }
        }
    }

    // MARK: - Protocol Content

    private var protocolContent: some View {
        ScrollView {
            VStack(spacing: OutliveSpacing.md) {
                recoveryBanner
                adherenceHeader
                trainingCard
                nutritionCard
                supplementsCard
                interventionsCard
                sleepCard
                gutHealthCard
            }
            .padding(.horizontal, OutliveSpacing.md)
            .padding(.bottom, OutliveSpacing.xxl)
        }
        .refreshable {
            viewModel.regenerate(modelContext: modelContext, userId: userId)
        }
    }

    // MARK: - Recovery Banner

    private var recoveryBanner: some View {
        RecoveryBanner(
            recoveryZone: viewModel.dailyProtocol?.recoveryZone ?? .yellow,
            hrvMs: viewModel.wearableData?.hrvMs,
            restingHR: viewModel.wearableData?.restingHR,
            sleepHours: viewModel.wearableData?.sleepHours
        )
    }

    // MARK: - Adherence Header

    private var adherenceHeader: some View {
        NavigationLink {
            ProgressDetailView(viewModel: viewModel)
        } label: {
            HStack(spacing: OutliveSpacing.md) {
                MetricRing(
                    value: viewModel.calculateAdherence(),
                    label: "Today",
                    color: adherenceColor
                )
                .frame(width: 70, height: 90)

                VStack(alignment: .leading, spacing: OutliveSpacing.xxs) {
                    Text("Daily Adherence")
                        .font(.outliveHeadline)
                        .foregroundStyle(Color.textPrimary)

                    Text("\(Int(viewModel.calculateAdherence() * 100))% complete")
                        .font(.outliveSubheadline)
                        .foregroundStyle(Color.textSecondary)

                    Text("Tap to see breakdown")
                        .font(.outliveCaption)
                        .foregroundStyle(Color.textTertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.outliveFootnote)
                    .foregroundStyle(Color.textTertiary)
            }
            .padding(OutliveSpacing.md)
            .background(Color.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.medium, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Domain Cards

    private var trainingCard: some View {
        Group {
            if let training = viewModel.dailyProtocol?.training {
                ProtocolCard(
                    icon: "dumbbell.fill",
                    title: trainingTitle(for: training),
                    accentColor: .domainTraining,
                    summary: trainingSummary(for: training)
                ) {
                    TrainingCardView(
                        training: training,
                        completedExercises: viewModel.completedExercises,
                        onToggle: viewModel.toggleExercise
                    )
                }
            }
        }
    }

    private var nutritionCard: some View {
        Group {
            if let nutrition = viewModel.dailyProtocol?.nutrition {
                ProtocolCard(
                    icon: "fork.knife",
                    title: "Nutrition",
                    accentColor: .domainNutrition,
                    summary: "\(nutrition.tdee) kcal target — P\(nutrition.protein)g C\(nutrition.carbs)g F\(nutrition.fat)g"
                ) {
                    NutritionCardView(
                        nutrition: nutrition,
                        completedMeals: viewModel.completedMeals,
                        onToggleMeal: viewModel.toggleMeal
                    )
                }
            }
        }
    }

    private var supplementsCard: some View {
        Group {
            let supplements = viewModel.dailyProtocol?.supplements ?? []
            if !supplements.isEmpty {
                ProtocolCard(
                    icon: "pill.fill",
                    title: "Supplements",
                    accentColor: .domainSupplements,
                    summary: supplementSummary(for: supplements)
                ) {
                    SupplementCardView(
                        supplements: supplements,
                        onToggle: viewModel.markSupplementTaken
                    )
                }
            }
        }
    }

    private var interventionsCard: some View {
        Group {
            let interventions = viewModel.dailyProtocol?.interventions ?? []
            if !interventions.isEmpty {
                ProtocolCard(
                    icon: "snowflake",
                    title: "Interventions",
                    accentColor: .domainInterventions,
                    summary: interventionSummary(for: interventions)
                ) {
                    InterventionsCardView(
                        interventions: interventions,
                        completedInterventions: viewModel.completedInterventions,
                        onToggle: viewModel.toggleIntervention
                    )
                }
            }
        }
    }

    private var sleepCard: some View {
        Group {
            if let sleep = viewModel.dailyProtocol?.sleep {
                ProtocolCard(
                    icon: "moon.fill",
                    title: "Sleep Protocol",
                    accentColor: .domainSleep,
                    summary: "Bed \(sleep.targetBedtime) — Wake \(sleep.targetWakeTime)"
                ) {
                    SleepCardView(
                        sleep: sleep,
                        completedItems: viewModel.completedChecklistItems,
                        onToggle: viewModel.toggleChecklistItem
                    )
                }
            }
        }
    }

    private var gutHealthCard: some View {
        Group {
            if let nutrition = viewModel.dailyProtocol?.nutrition {
                let supplements = viewModel.dailyProtocol?.supplements ?? []
                ProtocolCard(
                    icon: "leaf.fill",
                    title: "Gut Health",
                    accentColor: .recoveryGreen,
                    summary: "Fiber, probiotics, and fermented foods"
                ) {
                    GutHealthCardView(nutrition: nutrition, supplements: supplements)
                }
            }
        }
    }

    // MARK: - Toolbar

    private var adherenceToolbarItem: some View {
        MetricRing(
            value: viewModel.calculateAdherence(),
            label: "",
            color: adherenceColor,
            lineWidth: 4
        )
        .frame(width: 32, height: 32)
    }

    // MARK: - Loading & Empty States

    private var loadingView: some View {
        VStack(spacing: OutliveSpacing.md) {
            ProgressView()
                .controlSize(.large)
                .tint(.domainTraining)

            Text("Synthesizing your protocol...")
                .font(.outliveBody)
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        EmptyStateView(
            icon: "wand.and.stars",
            title: "No Protocol Generated",
            message: "Complete your profile and connect a wearable to generate your first personalized daily protocol.",
            actionTitle: "Generate Protocol"
        ) {
            viewModel.loadOrGenerate(modelContext: modelContext, userId: userId)
        }
    }

    // MARK: - Helpers

    private var adherenceColor: Color {
        let value = viewModel.calculateAdherence()
        if value >= 0.75 { return .recoveryGreen }
        if value >= 0.4 { return .recoveryYellow }
        return .recoveryRed
    }

    private func trainingTitle(for training: TrainingBlock) -> String {
        "\(training.type.rawValue.capitalized) Training"
    }

    private func trainingSummary(for training: TrainingBlock) -> String {
        "\(training.duration) min — RPE \(String(format: "%.1f", training.rpeTarget)) — \(training.exercises.count) exercises"
    }

    private func supplementSummary(for supplements: [SupplementDose]) -> String {
        let taken = supplements.filter(\.taken).count
        return "\(taken)/\(supplements.count) taken"
    }

    private func interventionSummary(for interventions: [InterventionBlock]) -> String {
        let names = interventions.prefix(3).map { $0.type.rawValue.capitalized }
        let suffix = interventions.count > 3 ? " +\(interventions.count - 3) more" : ""
        return names.joined(separator: ", ") + suffix
    }
}

// MARK: - Preview

#Preview {
    DailyDashboardView(userId: "preview-user")
        .modelContainer(for: [
            DailyProtocol.self,
            DailyWearableData.self,
            UserProfile.self,
            GenomicProfile.self,
            BloodworkPanel.self,
            BodyComposition.self,
        ], inMemory: true)
}
