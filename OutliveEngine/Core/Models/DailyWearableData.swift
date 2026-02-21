// DailyWearableData.swift
// OutliveEngine
//
// Aggregated daily metrics from wearable devices.

import Foundation
import SwiftData

@Model
final class DailyWearableData: Sendable {

    var userId: String
    var date: Date
    var source: WearableSource

    // MARK: - HRV & Heart Rate

    var hrvMs: Double?
    var restingHR: Int?

    // MARK: - Sleep

    var sleepHours: Double?
    var deepSleepMinutes: Int?
    var remSleepMinutes: Int?

    // MARK: - Recovery & Activity

    /// Recovery score normalized to 0–100.
    var recoveryScore: Double?
    var strain: Double?
    var steps: Int?
    var activeCalories: Int?

    // MARK: - Metadata

    var syncStatus: SyncStatus

    // MARK: - Init

    init(
        userId: String,
        date: Date,
        source: WearableSource,
        hrvMs: Double? = nil,
        restingHR: Int? = nil,
        sleepHours: Double? = nil,
        deepSleepMinutes: Int? = nil,
        remSleepMinutes: Int? = nil,
        recoveryScore: Double? = nil,
        strain: Double? = nil,
        steps: Int? = nil,
        activeCalories: Int? = nil,
        syncStatus: SyncStatus = .pending
    ) {
        self.userId = userId
        self.date = date
        self.source = source
        self.hrvMs = hrvMs
        self.restingHR = restingHR
        self.sleepHours = sleepHours
        self.deepSleepMinutes = deepSleepMinutes
        self.remSleepMinutes = remSleepMinutes
        self.recoveryScore = recoveryScore
        self.strain = strain
        self.steps = steps
        self.activeCalories = activeCalories
        self.syncStatus = syncStatus
    }
}
