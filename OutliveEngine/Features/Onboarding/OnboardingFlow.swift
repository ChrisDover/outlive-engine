// OnboardingFlow.swift
// OutliveEngine
//
// NavigationStack-based onboarding coordinator. Guides the user through
// goal selection, wearable connections, genome upload, bloodwork entry,
// allergy/diet preferences, and protocol source configuration.

import SwiftUI
import SwiftData

// MARK: - Onboarding Step

enum OnboardingStep: Int, CaseIterable, Hashable, Sendable {
    case welcome
    case goals
    case wearables
    case genome
    case bloodwork
    case allergies
    case protocolSelection

    var title: String {
        switch self {
        case .welcome:           "Welcome"
        case .goals:             "Your Goals"
        case .wearables:         "Wearables"
        case .genome:            "Genome"
        case .bloodwork:         "Bloodwork"
        case .allergies:         "Diet & Allergies"
        case .protocolSelection: "Protocols"
        }
    }

    /// Steps that can be skipped without blocking progression.
    var isSkippable: Bool {
        switch self {
        case .welcome, .goals, .protocolSelection: false
        case .wearables, .genome, .bloodwork, .allergies: true
        }
    }
}

// MARK: - Onboarding View Model

@Observable
final class OnboardingViewModel: @unchecked Sendable {

    // MARK: Navigation

    var path: [OnboardingStep] = []
    var currentStep: OnboardingStep = .welcome

    // MARK: Goals

    var selectedGoals: Set<HealthGoal> = []

    // MARK: Wearables

    var connectedWearables: Set<WearableSource> = []

    // MARK: Genome

    var genomeUploaded: Bool = false

    // MARK: Allergies & Diet

    var selectedAllergies: Set<String> = []
    var dietaryRestrictions: Set<String> = []

    // MARK: Protocols

    var protocolSources: [OnboardingProtocolEntry] = OnboardingProtocolEntry.defaults

    // MARK: Progress

    var completedSteps: Set<OnboardingStep> = []

    // MARK: Bloodwork

    var bloodworkValues: [String: String] = [:]

    // MARK: Computed

    var canProceed: Bool {
        switch currentStep {
        case .welcome:
            return true
        case .goals:
            return !selectedGoals.isEmpty
        case .wearables, .genome, .bloodwork, .allergies:
            return true
        case .protocolSelection:
            return protocolSources.contains(where: { $0.isEnabled })
        }
    }

    var progress: Double {
        let allSteps = OnboardingStep.allCases
        guard let index = allSteps.firstIndex(of: currentStep) else { return 0 }
        return Double(index) / Double(allSteps.count - 1)
    }

    // MARK: Navigation Actions

    func next() {
        completedSteps.insert(currentStep)

        let allSteps = OnboardingStep.allCases
        guard let currentIndex = allSteps.firstIndex(of: currentStep),
              currentIndex + 1 < allSteps.count else { return }

        let nextStep = allSteps[currentIndex + 1]
        currentStep = nextStep
        path.append(nextStep)
    }

    func previous() {
        guard !path.isEmpty else { return }
        path.removeLast()

        let allSteps = OnboardingStep.allCases
        if let currentIndex = allSteps.firstIndex(of: currentStep), currentIndex > 0 {
            currentStep = allSteps[currentIndex - 1]
        }
    }

    func skipStep() {
        guard currentStep.isSkippable else { return }
        next()
    }
}

// MARK: - Protocol Entry (Onboarding-local model)

struct OnboardingProtocolEntry: Identifiable, Sendable {
    let id = UUID()
    var name: String
    var author: String
    var isEnabled: Bool

    static let defaults: [OnboardingProtocolEntry] = [
        .init(name: "Longevity", author: "Peter Attia", isEnabled: true),
        .init(name: "Training", author: "Andy Galpin", isEnabled: true),
        .init(name: "Neuroscience", author: "Andrew Huberman", isEnabled: true),
        .init(name: "Nutrition", author: "Rhonda Patrick", isEnabled: true),
        .init(name: "Blueprint", author: "Bryan Johnson", isEnabled: false),
    ]
}

// MARK: - Onboarding Flow View

struct OnboardingFlow: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = OnboardingViewModel()

    var body: some View {
        NavigationStack(path: $viewModel.path) {
            WelcomeView(viewModel: viewModel)
                .navigationDestination(for: OnboardingStep.self) { step in
                    destinationView(for: step)
                }
        }
        .tint(.domainTraining)
        .interactiveDismissDisabled()
    }

    // MARK: - Destination Router

    @ViewBuilder
    private func destinationView(for step: OnboardingStep) -> some View {
        switch step {
        case .welcome:
            WelcomeView(viewModel: viewModel)
        case .goals:
            GoalsSelectionView(viewModel: viewModel)
        case .wearables:
            WearableConnectionView(viewModel: viewModel)
        case .genome:
            GenomeUploadView(viewModel: viewModel)
        case .bloodwork:
            BloodworkInputView(viewModel: viewModel)
        case .allergies:
            AllergiesView(viewModel: viewModel)
        case .protocolSelection:
            ProtocolSelectionView(viewModel: viewModel) {
                completeOnboarding()
            }
        }
    }

    // MARK: - Completion

    private func completeOnboarding() {
        persistProtocolSources()
        appState.hasCompletedOnboarding = true
    }

    private func persistProtocolSources() {
        guard let userId = appState.currentUserId else { return }

        for (index, entry) in viewModel.protocolSources.enumerated() where entry.isEnabled {
            let source = ProtocolSource(
                userId: userId,
                name: "\(entry.author) - \(entry.name)",
                author: entry.author,
                category: entry.name,
                priority: index
            )
            modelContext.insert(source)
        }

        try? modelContext.save()
    }
}

// MARK: - Onboarding Step Header

/// Shared progress header used across onboarding screens.
struct OnboardingStepHeader: View {
    let step: OnboardingStep
    let progress: Double

    var body: some View {
        VStack(alignment: .leading, spacing: OutliveSpacing.xs) {
            ProgressView(value: progress)
                .tint(.domainTraining)

            Text(step.title)
                .font(.outliveLargeTitle)
                .foregroundStyle(Color.textPrimary)
        }
        .padding(.horizontal, OutliveSpacing.md)
        .padding(.top, OutliveSpacing.sm)
    }
}

// MARK: - Preview

#Preview {
    OnboardingFlow()
        .environment(AppState())
        .modelContainer(try! DataStore.previewContainer())
}
