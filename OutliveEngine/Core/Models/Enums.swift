// Enums.swift
// OutliveEngine
//
// Shared enums for the Outlive Engine data model layer.

import SwiftUI

// MARK: - Health & Goals

enum HealthGoal: String, Codable, CaseIterable, Sendable {
    case longevity
    case muscleGain
    case fatLoss
    case cardiovascular
    case cognitive
    case metabolic
    case hormonal
    case sleep
    case gutHealth
    case stressResilience
}

// MARK: - Recovery

enum RecoveryZone: String, Codable, CaseIterable, Sendable {
    case green
    case yellow
    case red

    var color: Color {
        switch self {
        case .green:  return .recoveryGreen
        case .yellow: return .recoveryYellow
        case .red:    return .recoveryRed
        }
    }
}

// MARK: - Sync

enum SyncStatus: String, Codable, CaseIterable, Sendable {
    case pending
    case synced
    case conflict
    case failed
}

// MARK: - Training

enum TrainingType: String, Codable, CaseIterable, Sendable {
    case strength
    case hypertrophy
    case endurance
    case mobility
    case deload
    case rest
}

// MARK: - Nutrition

enum MealTiming: String, Codable, CaseIterable, Sendable {
    case breakfast
    case amSnack
    case lunch
    case pmSnack
    case dinner
    case preBed
}

// MARK: - Supplements

enum SupplementTiming: String, Codable, CaseIterable, Sendable {
    case waking
    case withBreakfast
    case midMorning
    case withLunch
    case afternoon
    case withDinner
    case preBed
}

// MARK: - Interventions

enum InterventionType: String, Codable, CaseIterable, Sendable {
    case sauna
    case coldPlunge
    case breathwork
    case redLight
    case grounding
    case meditation
}

// MARK: - Lab Sources

enum BloodworkSource: String, Codable, CaseIterable, Sendable {
    case labCorp
    case quest
    case manual
    case ocr
}

// MARK: - Wearables

enum WearableSource: String, Codable, CaseIterable, Sendable {
    case appleWatch
    case whoop
    case oura
    case garmin
    case manual
}

// MARK: - Evidence

enum EvidenceLevel: String, Codable, CaseIterable, Sendable {
    case metaAnalysis
    case rct
    case observational
    case mechanistic
    case anecdotal
}

// MARK: - Experiments

enum ExperimentStatus: String, Codable, CaseIterable, Sendable {
    case designing
    case baseline
    case testing
    case analyzing
    case completed
}

// MARK: - Genomics

enum RiskCategory: String, Codable, CaseIterable, Sendable {
    case apoe
    case mthfr
    case cyp1a2
    case actn3
    case fto
    case vdr
    case comt
    case gstm1
    case bcmo1
    case slc23a1
}

// MARK: - Bloodwork Marker Status

enum MarkerStatus: String, Codable, Sendable {
    case optimal
    case normal
    case suboptimal
    case critical
}
