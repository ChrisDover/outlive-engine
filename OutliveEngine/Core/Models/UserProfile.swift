// UserProfile.swift
// OutliveEngine
//
// Core user identity and preference model.

import Foundation
import SwiftData

@Model
final class UserProfile {

    @Attribute(.unique) var appleUserId: String
    var displayName: String?
    var birthDate: Date?
    var biologicalSex: String?
    var heightCm: Double?

    // MARK: - Stored as JSON Data

    private var goalsData: Data?
    private var allergiesData: Data?
    private var dietaryRestrictionsData: Data?

    var goals: [HealthGoal] {
        get { (try? JSONDecoder().decode([HealthGoal].self, from: goalsData ?? Data())) ?? [] }
        set { goalsData = try? JSONEncoder().encode(newValue) }
    }

    var allergies: [String] {
        get { (try? JSONDecoder().decode([String].self, from: allergiesData ?? Data())) ?? [] }
        set { allergiesData = try? JSONEncoder().encode(newValue) }
    }

    var dietaryRestrictions: [String] {
        get { (try? JSONDecoder().decode([String].self, from: dietaryRestrictionsData ?? Data())) ?? [] }
        set { dietaryRestrictionsData = try? JSONEncoder().encode(newValue) }
    }

    // MARK: - Metadata

    var createdAt: Date
    var updatedAt: Date
    var syncStatus: SyncStatus

    // MARK: - Init

    init(
        appleUserId: String,
        displayName: String? = nil,
        birthDate: Date? = nil,
        biologicalSex: String? = nil,
        heightCm: Double? = nil,
        goals: [HealthGoal] = [],
        allergies: [String] = [],
        dietaryRestrictions: [String] = [],
        createdAt: Date = .now,
        updatedAt: Date = .now,
        syncStatus: SyncStatus = .pending
    ) {
        self.appleUserId = appleUserId
        self.displayName = displayName
        self.birthDate = birthDate
        self.biologicalSex = biologicalSex
        self.heightCm = heightCm
        self.goalsData = try? JSONEncoder().encode(goals)
        self.allergiesData = try? JSONEncoder().encode(allergies)
        self.dietaryRestrictionsData = try? JSONEncoder().encode(dietaryRestrictions)
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.syncStatus = syncStatus
    }
}
