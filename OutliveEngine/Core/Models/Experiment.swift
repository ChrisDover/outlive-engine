// Experiment.swift
// OutliveEngine
//
// N-of-1 experiment tracking with baseline and test snapshots.

import Foundation
import SwiftData

@Model
final class Experiment {

    var userId: String
    var title: String
    var hypothesis: String

    // MARK: - Stored as JSON Data

    private var trackedMetricsData: Data?
    private var baselineSnapshotsData: Data?
    private var testSnapshotsData: Data?

    var trackedMetrics: [String] {
        get { (try? JSONDecoder().decode([String].self, from: trackedMetricsData ?? Data())) ?? [] }
        set { trackedMetricsData = try? JSONEncoder().encode(newValue) }
    }

    var baselineSnapshots: [ExperimentSnapshot] {
        get { (try? JSONDecoder().decode([ExperimentSnapshot].self, from: baselineSnapshotsData ?? Data())) ?? [] }
        set { baselineSnapshotsData = try? JSONEncoder().encode(newValue) }
    }

    var testSnapshots: [ExperimentSnapshot] {
        get { (try? JSONDecoder().decode([ExperimentSnapshot].self, from: testSnapshotsData ?? Data())) ?? [] }
        set { testSnapshotsData = try? JSONEncoder().encode(newValue) }
    }

    // MARK: - Timeline

    var startDate: Date
    var endDate: Date?
    var status: ExperimentStatus

    // MARK: - Results

    var result: String?

    // MARK: - Metadata

    var syncStatus: SyncStatus

    // MARK: - Init

    init(
        userId: String,
        title: String,
        hypothesis: String,
        trackedMetrics: [String] = [],
        baselineSnapshots: [ExperimentSnapshot] = [],
        testSnapshots: [ExperimentSnapshot] = [],
        startDate: Date = .now,
        endDate: Date? = nil,
        status: ExperimentStatus = .designing,
        result: String? = nil,
        syncStatus: SyncStatus = .pending
    ) {
        self.userId = userId
        self.title = title
        self.hypothesis = hypothesis
        self.trackedMetricsData = try? JSONEncoder().encode(trackedMetrics)
        self.baselineSnapshotsData = try? JSONEncoder().encode(baselineSnapshots)
        self.testSnapshotsData = try? JSONEncoder().encode(testSnapshots)
        self.startDate = startDate
        self.endDate = endDate
        self.status = status
        self.result = result
        self.syncStatus = syncStatus
    }
}
