// GoalsSelectionView.swift
// OutliveEngine
//
// Multi-select grid of HealthGoal cases. Each goal is presented as a
// toggleable chip with an SF Symbol icon. At least one selection is
// required before the user can proceed.

import SwiftUI

struct GoalsSelectionView: View {
    @Bindable var viewModel: OnboardingViewModel

    private let columns = [
        GridItem(.flexible(), spacing: OutliveSpacing.sm),
        GridItem(.flexible(), spacing: OutliveSpacing.sm),
    ]

    var body: some View {
        VStack(spacing: 0) {
            OnboardingStepHeader(step: .goals, progress: viewModel.progress)

            Text("What are you optimizing for?")
                .font(.outliveCallout)
                .foregroundStyle(Color.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, OutliveSpacing.md)
                .padding(.top, OutliveSpacing.xs)

            ScrollView {
                LazyVGrid(columns: columns, spacing: OutliveSpacing.sm) {
                    ForEach(HealthGoal.allCases, id: \.self) { goal in
                        GoalChip(
                            goal: goal,
                            isSelected: viewModel.selectedGoals.contains(goal)
                        ) {
                            toggleGoal(goal)
                        }
                    }
                }
                .padding(.horizontal, OutliveSpacing.md)
                .padding(.top, OutliveSpacing.lg)
                .padding(.bottom, OutliveSpacing.xl)
            }

            Spacer()

            selectionHint

            OutliveButton(title: "Continue", style: .primary) {
                viewModel.next()
            }
            .disabled(!viewModel.canProceed)
            .opacity(viewModel.canProceed ? 1.0 : 0.5)
            .padding(.horizontal, OutliveSpacing.md)
            .padding(.bottom, OutliveSpacing.lg)
        }
        .background(Color.surfaceBackground)
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { viewModel.previous() } label: {
                    Image(systemName: "chevron.left")
                        .font(.outliveHeadline)
                }
            }
        }
        .onAppear { viewModel.currentStep = .goals }
    }

    // MARK: - Selection Hint

    private var selectionHint: some View {
        Text(viewModel.selectedGoals.isEmpty
             ? "Select at least one goal"
             : "\(viewModel.selectedGoals.count) goal\(viewModel.selectedGoals.count == 1 ? "" : "s") selected")
            .font(.outliveFootnote)
            .foregroundStyle(viewModel.selectedGoals.isEmpty ? Color.textTertiary : Color.domainTraining)
            .padding(.bottom, OutliveSpacing.xs)
    }

    // MARK: - Toggle

    private func toggleGoal(_ goal: HealthGoal) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if viewModel.selectedGoals.contains(goal) {
                viewModel.selectedGoals.remove(goal)
            } else {
                viewModel.selectedGoals.insert(goal)
            }
        }
    }
}

// MARK: - Goal Chip

private struct GoalChip: View {
    let goal: HealthGoal
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: OutliveSpacing.xs) {
                Image(systemName: goal.icon)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(isSelected ? Color.white : Color.domainTraining)

                Text(goal.displayName)
                    .font(.outliveSubheadline)
                    .foregroundStyle(isSelected ? Color.white : Color.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .background(
                RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.medium, style: .continuous)
                    .fill(isSelected ? Color.domainTraining : Color.surfaceCard)
            )
            .overlay {
                RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.medium, style: .continuous)
                    .strokeBorder(isSelected ? Color.clear : Color.textTertiary.opacity(0.3), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}

// MARK: - HealthGoal Display Helpers

extension HealthGoal {

    var icon: String {
        switch self {
        case .longevity:        "heart.fill"
        case .muscleGain:       "figure.strengthtraining.traditional"
        case .fatLoss:          "flame.fill"
        case .cardiovascular:   "waveform.path.ecg"
        case .cognitive:        "brain.head.profile"
        case .metabolic:        "bolt.fill"
        case .hormonal:         "cross.vial.fill"
        case .sleep:            "moon.fill"
        case .gutHealth:        "leaf.fill"
        case .stressResilience: "wind"
        }
    }

    var displayName: String {
        switch self {
        case .longevity:        "Longevity"
        case .muscleGain:       "Muscle Gain"
        case .fatLoss:          "Fat Loss"
        case .cardiovascular:   "Cardiovascular"
        case .cognitive:        "Cognitive"
        case .metabolic:        "Metabolic"
        case .hormonal:         "Hormonal"
        case .sleep:            "Sleep"
        case .gutHealth:        "Gut Health"
        case .stressResilience: "Stress Resilience"
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        GoalsSelectionView(viewModel: OnboardingViewModel())
            .environment(AppState())
    }
}
