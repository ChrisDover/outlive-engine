// BodyComposition.swift
// OutliveEngine
//
// Body composition measurements over time.

import Foundation
import SwiftData

@Model
final class BodyComposition {

    var userId: String
    var date: Date
    var weightKg: Double
    var bodyFatPercent: Double?
    var muscleMassKg: Double?
    var visceralFat: Double?
    var source: WearableSource

    // MARK: - Metadata

    var syncStatus: SyncStatus

    // MARK: - Init

    init(
        userId: String,
        date: Date,
        weightKg: Double,
        bodyFatPercent: Double? = nil,
        muscleMassKg: Double? = nil,
        visceralFat: Double? = nil,
        source: WearableSource = .manual,
        syncStatus: SyncStatus = .pending
    ) {
        self.userId = userId
        self.date = date
        self.weightKg = weightKg
        self.bodyFatPercent = bodyFatPercent
        self.muscleMassKg = muscleMassKg
        self.visceralFat = visceralFat
        self.source = source
        self.syncStatus = syncStatus
    }
}
