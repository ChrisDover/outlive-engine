// BloodworkPanel.swift
// OutliveEngine
//
// Lab results and biomarker tracking.

import Foundation
import SwiftData

@Model
final class BloodworkPanel: Sendable {

    var userId: String
    var labDate: Date
    var source: BloodworkSource

    // MARK: - Stored as JSON Data

    private var markersData: Data?

    var markers: [BloodworkMarker] {
        get { (try? JSONDecoder().decode([BloodworkMarker].self, from: markersData ?? Data())) ?? [] }
        set { markersData = try? JSONEncoder().encode(newValue) }
    }

    var notes: String?

    // MARK: - Metadata

    var syncStatus: SyncStatus
    var createdAt: Date

    // MARK: - Init

    init(
        userId: String,
        labDate: Date,
        source: BloodworkSource,
        markers: [BloodworkMarker] = [],
        notes: String? = nil,
        syncStatus: SyncStatus = .pending,
        createdAt: Date = .now
    ) {
        self.userId = userId
        self.labDate = labDate
        self.source = source
        self.markersData = try? JSONEncoder().encode(markers)
        self.notes = notes
        self.syncStatus = syncStatus
        self.createdAt = createdAt
    }
}
