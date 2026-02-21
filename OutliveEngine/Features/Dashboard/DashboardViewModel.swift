// DashboardViewModel.swift
// OutliveEngine
//
// Observable view model that manages daily protocol state, coordinates with
// ProtocolSynthesizer for generation, and tracks adherence across all domains.

import Foundation
import SwiftData

@Observable
final class DashboardViewModel: @unchecked Sendable {

    // MARK: - Published State

    var dailyProtocol: DailyProtocol?
    var wearableData: DailyWearableData?
    var isGenerating = false
    var todayDate = Calendar.current.startOfDay(for: .now)
    var errorMessage: String?

    // MARK: - Exercise Completion Tracking

    /// Tracks completed exercise indices for the current training block.
    var completedExercises: Set<Int> = []

    /// Tracks completed meal indices for the current nutrition plan.
    var completedMeals: Set<Int> = []

    /// Tracks completed evening checklist indices for sleep protocol.
    var completedChecklistItems: Set<Int> = []

    /// Tracks completed intervention indices.
    var completedInterventions: Set<Int> = []

    // MARK: - Load or Generate

    /// Queries SwiftData for today's protocol. If none exists, synthesizes one
    /// from the user's profile, genomics, bloodwork, wearable, and body-composition data.
    func loadOrGenerate(modelContext: ModelContext, userId: String) {
        isGenerating = true
        errorMessage = nil

        let startOfDay = todayDate
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay

        // Query today's protocol
        let protocolDescriptor = FetchDescriptor<DailyProtocol>(
            predicate: #Predicate<DailyProtocol> { protocol_ in
                protocol_.userId == userId &&
                protocol_.date >= startOfDay &&
                protocol_.date < endOfDay
            }
        )

        if let existing = try? modelContext.fetch(protocolDescriptor).first {
            dailyProtocol = existing
            loadWearableData(modelContext: modelContext, userId: userId)
            isGenerating = false
            return
        }

        // No protocol for today — generate one
        generateProtocol(modelContext: modelContext, userId: userId)
    }

    /// Forces regeneration of today's protocol, replacing any existing one.
    func regenerate(modelContext: ModelContext, userId: String) {
        // Delete existing protocol for today
        if let existing = dailyProtocol {
            modelContext.delete(existing)
        }

        resetCompletionTracking()
        generateProtocol(modelContext: modelContext, userId: userId)
    }

    // MARK: - Supplement Actions

    /// Toggles the taken status of a supplement at the given index.
    func markSupplementTaken(at index: Int) {
        guard var protocol_ = dailyProtocol else { return }
        var supplements = protocol_.supplements
        guard supplements.indices.contains(index) else { return }

        supplements[index] = SupplementDose(
            name: supplements[index].name,
            dose: supplements[index].dose,
            timing: supplements[index].timing,
            rationale: supplements[index].rationale,
            taken: !supplements[index].taken
        )
        protocol_.supplements = supplements
    }

    // MARK: - Exercise Actions

    /// Toggles completion status for an exercise at the given index.
    func toggleExercise(at index: Int) {
        if completedExercises.contains(index) {
            completedExercises.remove(index)
        } else {
            completedExercises.insert(index)
        }
    }

    /// Toggles completion status for a meal at the given index.
    func toggleMeal(at index: Int) {
        if completedMeals.contains(index) {
            completedMeals.remove(index)
        } else {
            completedMeals.insert(index)
        }
    }

    /// Toggles completion status for a checklist item at the given index.
    func toggleChecklistItem(at index: Int) {
        if completedChecklistItems.contains(index) {
            completedChecklistItems.remove(index)
        } else {
            completedChecklistItems.insert(index)
        }
    }

    /// Toggles completion status for an intervention at the given index.
    func toggleIntervention(at index: Int) {
        if completedInterventions.contains(index) {
            completedInterventions.remove(index)
        } else {
            completedInterventions.insert(index)
        }
    }

    // MARK: - Adherence Calculation

    /// Returns overall adherence as a 0.0–1.0 percentage across all protocol domains.
    func calculateAdherence() -> Double {
        guard let protocol_ = dailyProtocol else { return 0 }

        var totalItems = 0
        var completedItems = 0

        // Training adherence
        if let training = protocol_.training {
            totalItems += training.exercises.count
            completedItems += completedExercises.count
        }

        // Supplement adherence
        let supplements = protocol_.supplements
        totalItems += supplements.count
        completedItems += supplements.filter(\.taken).count

        // Nutrition adherence
        if let nutrition = protocol_.nutrition {
            totalItems += nutrition.meals.count
            completedItems += completedMeals.count
        }

        // Intervention adherence
        let interventions = protocol_.interventions
        totalItems += interventions.count
        completedItems += completedInterventions.count

        // Sleep checklist adherence
        if let sleep = protocol_.sleep {
            totalItems += sleep.eveningChecklist.count
            completedItems += completedChecklistItems.count
        }

        guard totalItems > 0 else { return 0 }
        return Double(completedItems) / Double(totalItems)
    }

    /// Returns adherence for a specific domain as a 0.0–1.0 percentage.
    func domainAdherence(for domain: ProtocolDomain) -> Double {
        guard let protocol_ = dailyProtocol else { return 0 }

        switch domain {
        case .training:
            guard let training = protocol_.training else { return 0 }
            let total = training.exercises.count
            guard total > 0 else { return 0 }
            return Double(completedExercises.count) / Double(total)

        case .nutrition:
            guard let nutrition = protocol_.nutrition else { return 0 }
            let total = nutrition.meals.count
            guard total > 0 else { return 0 }
            return Double(completedMeals.count) / Double(total)

        case .supplements:
            let supplements = protocol_.supplements
            guard !supplements.isEmpty else { return 0 }
            return Double(supplements.filter(\.taken).count) / Double(supplements.count)

        case .interventions:
            let interventions = protocol_.interventions
            guard !interventions.isEmpty else { return 0 }
            return Double(completedInterventions.count) / Double(interventions.count)

        case .sleep:
            guard let sleep = protocol_.sleep else { return 0 }
            let total = sleep.eveningChecklist.count
            guard total > 0 else { return 0 }
            return Double(completedChecklistItems.count) / Double(total)
        }
    }

    // MARK: - Private Helpers

    private func generateProtocol(modelContext: ModelContext, userId: String) {
        isGenerating = true

        let profileInput = fetchUserProfileInput(modelContext: modelContext, userId: userId)
        let genomicsInput = fetchGenomicsInput(modelContext: modelContext, userId: userId)
        let bloodworkInput = fetchBloodworkInput(modelContext: modelContext, userId: userId)
        let wearableInput = fetchWearableInput(modelContext: modelContext, userId: userId)
        let bodyCompInput = fetchBodyCompInput(modelContext: modelContext, userId: userId)

        let synthesizer = ProtocolSynthesizer()
        let result = synthesizer.synthesize(
            profile: profileInput,
            genomics: genomicsInput,
            bloodwork: bloodworkInput,
            wearable: wearableInput,
            bodyComp: bodyCompInput,
            date: todayDate
        )

        // Store generated protocol to SwiftData
        let newProtocol = DailyProtocol(
            userId: userId,
            date: todayDate,
            recoveryZone: result.recoveryZone,
            training: result.training,
            nutrition: result.nutrition,
            supplements: result.supplements,
            interventions: result.interventions,
            sleep: result.sleep,
            notes: result.insights.joined(separator: "\n"),
            syncStatus: .pending,
            generatedAt: .now
        )

        modelContext.insert(newProtocol)
        try? modelContext.save()

        dailyProtocol = newProtocol
        loadWearableData(modelContext: modelContext, userId: userId)
        isGenerating = false
    }

    private func loadWearableData(modelContext: ModelContext, userId: String) {
        let startOfDay = todayDate
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay

        let descriptor = FetchDescriptor<DailyWearableData>(
            predicate: #Predicate<DailyWearableData> { data in
                data.userId == userId &&
                data.date >= startOfDay &&
                data.date < endOfDay
            }
        )

        wearableData = try? modelContext.fetch(descriptor).first
    }

    private func resetCompletionTracking() {
        completedExercises = []
        completedMeals = []
        completedChecklistItems = []
        completedInterventions = []
    }

    // MARK: - SwiftData → Input Converters

    private func fetchUserProfileInput(modelContext: ModelContext, userId: String) -> UserProfileInput {
        let descriptor = FetchDescriptor<UserProfile>(
            predicate: #Predicate<UserProfile> { $0.appleUserId == userId }
        )

        guard let profile = try? modelContext.fetch(descriptor).first else {
            return UserProfileInput(
                goals: [.longevity],
                allergies: [],
                dietaryRestrictions: [],
                biologicalSex: nil,
                birthDate: nil,
                heightCm: nil
            )
        }

        return UserProfileInput(
            goals: profile.goals,
            allergies: profile.allergies,
            dietaryRestrictions: profile.dietaryRestrictions,
            biologicalSex: profile.biologicalSex,
            birthDate: profile.birthDate,
            heightCm: profile.heightCm
        )
    }

    private func fetchGenomicsInput(modelContext: ModelContext, userId: String) -> GenomicsInput? {
        let descriptor = FetchDescriptor<GenomicProfile>(
            predicate: #Predicate<GenomicProfile> { $0.userId == userId }
        )

        guard let profile = try? modelContext.fetch(descriptor).first else { return nil }
        let risks = profile.risks
        guard !risks.isEmpty else { return nil }
        return GenomicsInput(risks: risks)
    }

    private func fetchBloodworkInput(modelContext: ModelContext, userId: String) -> BloodworkInput? {
        let descriptor = FetchDescriptor<BloodworkPanel>(
            predicate: #Predicate<BloodworkPanel> { $0.userId == userId },
            sortBy: [SortDescriptor(\.labDate, order: .reverse)]
        )

        guard let panels = try? modelContext.fetch(descriptor),
              let latest = panels.first else { return nil }

        let previousMarkers = panels.count > 1 ? panels[1].markers : nil

        return BloodworkInput(
            markers: latest.markers,
            labDate: latest.labDate,
            previousMarkers: previousMarkers
        )
    }

    private func fetchWearableInput(modelContext: ModelContext, userId: String) -> WearableInput? {
        let startOfDay = todayDate
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay

        let descriptor = FetchDescriptor<DailyWearableData>(
            predicate: #Predicate<DailyWearableData> { data in
                data.userId == userId &&
                data.date >= startOfDay &&
                data.date < endOfDay
            }
        )

        guard let data = try? modelContext.fetch(descriptor).first else { return nil }

        return WearableInput(
            hrvMs: data.hrvMs,
            restingHR: data.restingHR,
            sleepHours: data.sleepHours,
            deepSleepMinutes: data.deepSleepMinutes,
            remSleepMinutes: data.remSleepMinutes,
            recoveryScore: data.recoveryScore,
            strain: data.strain
        )
    }

    private func fetchBodyCompInput(modelContext: ModelContext, userId: String) -> BodyCompInput? {
        let descriptor = FetchDescriptor<BodyComposition>(
            predicate: #Predicate<BodyComposition> { $0.userId == userId },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )

        guard let comp = try? modelContext.fetch(descriptor).first else { return nil }

        return BodyCompInput(
            weightKg: comp.weightKg,
            bodyFatPercent: comp.bodyFatPercent,
            muscleMassKg: comp.muscleMassKg
        )
    }
}

// MARK: - Protocol Domain

enum ProtocolDomain: String, CaseIterable, Sendable {
    case training
    case nutrition
    case supplements
    case interventions
    case sleep

    var displayName: String {
        rawValue.capitalized
    }

    var icon: String {
        switch self {
        case .training:      return "dumbbell.fill"
        case .nutrition:     return "fork.knife"
        case .supplements:   return "pill.fill"
        case .interventions: return "snowflake"
        case .sleep:         return "moon.fill"
        }
    }

    var color: Color {
        switch self {
        case .training:      return .domainTraining
        case .nutrition:     return .domainNutrition
        case .supplements:   return .domainSupplements
        case .interventions: return .domainInterventions
        case .sleep:         return .domainSleep
        }
    }
}

import SwiftUI
