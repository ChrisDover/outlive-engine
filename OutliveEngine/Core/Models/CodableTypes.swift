// CodableTypes.swift
// OutliveEngine
//
// Codable value types used for structured data storage within SwiftData models.

import Foundation

// MARK: - Bloodwork

struct BloodworkMarker: Codable, Sendable, Hashable {
    let name: String
    let value: Double
    let unit: String
    let optimalLow: Double
    let optimalHigh: Double
    let normalLow: Double
    let normalHigh: Double

    var status: MarkerStatus {
        if value >= optimalLow && value <= optimalHigh {
            return .optimal
        } else if value >= normalLow && value <= normalHigh {
            return .normal
        } else if value < normalLow * 0.8 || value > normalHigh * 1.2 {
            return .critical
        } else {
            return .suboptimal
        }
    }
}

// MARK: - Training

struct TrainingBlock: Codable, Sendable, Hashable {
    let type: TrainingType
    var exercises: [Exercise]
    let duration: Int // minutes
    let rpeTarget: Double
    var notes: String?
}

struct Exercise: Codable, Sendable, Hashable {
    let name: String
    let sets: Int
    let reps: String
    var weight: String?
    var notes: String?
}

// MARK: - Nutrition

struct NutritionPlan: Codable, Sendable, Hashable {
    let tdee: Int
    let protein: Int // grams
    let carbs: Int   // grams
    let fat: Int     // grams
    var meals: [MealPlan]
    var notes: String?
}

struct MealPlan: Codable, Sendable, Hashable {
    let timing: MealTiming
    let description: String
    let calories: Int
    let protein: Int
    let carbs: Int
    let fat: Int
}

// MARK: - Supplements

struct SupplementDose: Codable, Sendable, Hashable {
    let name: String
    let dose: String
    let timing: SupplementTiming
    let rationale: String
    var taken: Bool = false
}

// MARK: - Interventions

struct InterventionBlock: Codable, Sendable, Hashable {
    let type: InterventionType
    let duration: Int // minutes
    var temperature: String?
    var notes: String?
}

// MARK: - Sleep

struct SleepProtocol: Codable, Sendable, Hashable {
    var targetBedtime: String = "22:00"
    var targetWakeTime: String
    var eveningChecklist: [String]
    var notes: String?
}

// MARK: - Genomics

struct GeneticRisk: Codable, Sendable, Hashable {
    let category: RiskCategory
    let snpId: String
    let genotype: String
    /// Risk level normalized to 0.0–1.0.
    let riskLevel: Double
    let implications: [String]
}

// MARK: - Experiments

struct ExperimentSnapshot: Codable, Sendable, Hashable {
    let date: Date
    let metrics: [String: Double]
}
