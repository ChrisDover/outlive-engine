// SyncManager.swift
// OutliveEngine
//
// Bidirectional sync between on-device SwiftData and the backend API.
// Push sends locally-modified records upstream; pull fetches remote changes
// since the last sync timestamp. Conflict resolution defaults to server-wins.

import Foundation
import SwiftData
import Observation
import Network
import BackgroundTasks

// MARK: - Sync State

enum SyncState: String, Sendable {
    case idle
    case syncing
    case error
}

// MARK: - Sync Payload Types

/// Envelope sent to the server on push.
private struct SyncPushPayload: Encodable, Sendable {
    let bloodwork: [BloodworkSyncDTO]
    let wearables: [WearableSyncDTO]
    let bodyComposition: [BodyCompositionSyncDTO]
    let experiments: [ExperimentSyncDTO]
}

/// Envelope received from the server on pull.
private struct SyncPullResponse: Decodable, Sendable {
    let bloodwork: [BloodworkSyncDTO]?
    let wearables: [WearableSyncDTO]?
    let bodyComposition: [BodyCompositionSyncDTO]?
    let experiments: [ExperimentSyncDTO]?
    let serverTimestamp: Date
}

// MARK: - Sync DTOs

struct BloodworkSyncDTO: Codable, Sendable {
    let id: String
    let userId: String
    let labDate: Date
    let source: BloodworkSource
    let markers: [BloodworkMarker]
    let notes: String?
    let updatedAt: Date
}

struct WearableSyncDTO: Codable, Sendable {
    let id: String
    let userId: String
    let date: Date
    let source: WearableSource
    let hrvMs: Double?
    let restingHR: Int?
    let sleepHours: Double?
    let deepSleepMinutes: Int?
    let remSleepMinutes: Int?
    let recoveryScore: Double?
    let strain: Double?
    let steps: Int?
    let activeCalories: Int?
    let updatedAt: Date
}

struct BodyCompositionSyncDTO: Codable, Sendable {
    let id: String
    let userId: String
    let date: Date
    let weightKg: Double
    let bodyFatPercent: Double?
    let muscleMassKg: Double?
    let visceralFat: Double?
    let source: WearableSource
    let updatedAt: Date
}

struct ExperimentSyncDTO: Codable, Sendable {
    let id: String
    let userId: String
    let title: String
    let hypothesis: String
    let trackedMetrics: [String]
    let status: ExperimentStatus
    let startDate: Date
    let endDate: Date?
    let result: String?
    let updatedAt: Date
}

// MARK: - Sync Pull Request

private struct SyncPullRequest: Encodable, Sendable {
    let since: Date
}

// MARK: - Sync Push Response

private struct SyncPushResponse: Decodable, Sendable {
    let accepted: Int
    let conflicts: Int
    let serverTimestamp: Date
}

// MARK: - Sync Manager

@Observable
final class SyncManager: @unchecked Sendable {

    // MARK: - Public State

    private(set) var state: SyncState = .idle
    private(set) var lastSyncDate: Date?
    private(set) var lastError: String?

    // MARK: - Dependencies

    private let apiClient: APIClient
    private let auditLogger: AuditLogger

    // MARK: - Network Monitoring

    private let pathMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.outlive-engine.sync-monitor")
    private var isConnected: Bool = true

    // MARK: - Constants

    private enum Defaults {
        static let lastSyncKey = "com.outlive-engine.lastSyncTimestamp"
        static let bgTaskIdentifier = "com.outlive-engine.sync"
    }

    // MARK: - Initialization

    init(apiClient: APIClient, auditLogger: AuditLogger = AuditLogger()) {
        self.apiClient = apiClient
        self.auditLogger = auditLogger
        self.lastSyncDate = UserDefaults.standard.object(forKey: Defaults.lastSyncKey) as? Date

        startNetworkMonitor()
    }

    // MARK: - Network Monitor

    private func startNetworkMonitor() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            self?.isConnected = path.status == .satisfied
        }
        pathMonitor.start(queue: monitorQueue)
    }

    // MARK: - Background Task Registration

    /// Registers the background sync task with the system scheduler.
    /// Call this once during app launch (e.g., in `application(_:didFinishLaunchingWithOptions:)`).
    func registerBackgroundSync() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Defaults.bgTaskIdentifier,
            using: nil
        ) { [weak self] task in
            guard let bgTask = task as? BGAppRefreshTask else { return }
            self?.handleBackgroundSync(bgTask: bgTask)
        }
    }

    /// Schedules the next background sync. Call after each foreground sync completes.
    func scheduleBackgroundSync() {
        let request = BGAppRefreshTaskRequest(identifier: Defaults.bgTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes
        try? BGTaskScheduler.shared.submit(request)
    }

    private func handleBackgroundSync(bgTask: BGAppRefreshTask) {
        scheduleBackgroundSync()

        let syncTask = Task {
            // Background sync requires a ModelContext from the container.
            // The caller must have set up the container; this is a best-effort attempt.
            // In practice, the App struct would pass the modelContext through.
        }

        bgTask.expirationHandler = {
            syncTask.cancel()
        }
    }

    // MARK: - Full Sync

    /// Performs a full bidirectional sync: push local changes, then pull remote changes.
    @MainActor
    func syncAll(modelContext: ModelContext) async {
        guard isConnected else {
            lastError = "No network connection."
            state = .error
            return
        }

        state = .syncing
        await auditLogger.log(.syncStarted)

        do {
            try await pushChanges(modelContext: modelContext)
            try await pullChanges(modelContext: modelContext)

            let now = Date.now
            lastSyncDate = now
            UserDefaults.standard.set(now, forKey: Defaults.lastSyncKey)

            state = .idle
            lastError = nil
            await auditLogger.log(.syncCompleted)
            scheduleBackgroundSync()
        } catch {
            state = .error
            lastError = error.localizedDescription
            await auditLogger.log(.syncFailed, metadata: ["error": error.localizedDescription])
        }
    }

    // MARK: - Push

    /// Finds all local records with `syncStatus == .pending` and pushes them to the server.
    @MainActor
    func pushChanges(modelContext: ModelContext) async throws {
        let pendingStatus = SyncStatus.pending

        // Fetch pending bloodwork.
        let bloodworkDescriptor = FetchDescriptor<BloodworkPanel>(
            predicate: #Predicate { $0.syncStatus == pendingStatus }
        )
        let pendingBloodwork = (try? modelContext.fetch(bloodworkDescriptor)) ?? []

        // Fetch pending wearable data.
        let wearableDescriptor = FetchDescriptor<DailyWearableData>(
            predicate: #Predicate { $0.syncStatus == pendingStatus }
        )
        let pendingWearables = (try? modelContext.fetch(wearableDescriptor)) ?? []

        // Fetch pending body composition.
        let bodyCompDescriptor = FetchDescriptor<BodyComposition>(
            predicate: #Predicate { $0.syncStatus == pendingStatus }
        )
        let pendingBodyComp = (try? modelContext.fetch(bodyCompDescriptor)) ?? []

        // Fetch pending experiments.
        let experimentDescriptor = FetchDescriptor<Experiment>(
            predicate: #Predicate { $0.syncStatus == pendingStatus }
        )
        let pendingExperiments = (try? modelContext.fetch(experimentDescriptor)) ?? []

        // If nothing to push, return early.
        guard !pendingBloodwork.isEmpty || !pendingWearables.isEmpty
                || !pendingBodyComp.isEmpty || !pendingExperiments.isEmpty else {
            return
        }

        let payload = SyncPushPayload(
            bloodwork: pendingBloodwork.map { panel in
                BloodworkSyncDTO(
                    id: panel.persistentModelID.hashValue.description,
                    userId: panel.userId,
                    labDate: panel.labDate,
                    source: panel.source,
                    markers: panel.markers,
                    notes: panel.notes,
                    updatedAt: panel.createdAt
                )
            },
            wearables: pendingWearables.map { data in
                WearableSyncDTO(
                    id: data.persistentModelID.hashValue.description,
                    userId: data.userId,
                    date: data.date,
                    source: data.source,
                    hrvMs: data.hrvMs,
                    restingHR: data.restingHR,
                    sleepHours: data.sleepHours,
                    deepSleepMinutes: data.deepSleepMinutes,
                    remSleepMinutes: data.remSleepMinutes,
                    recoveryScore: data.recoveryScore,
                    strain: data.strain,
                    steps: data.steps,
                    activeCalories: data.activeCalories,
                    updatedAt: data.date
                )
            },
            bodyComposition: pendingBodyComp.map { bc in
                BodyCompositionSyncDTO(
                    id: bc.persistentModelID.hashValue.description,
                    userId: bc.userId,
                    date: bc.date,
                    weightKg: bc.weightKg,
                    bodyFatPercent: bc.bodyFatPercent,
                    muscleMassKg: bc.muscleMassKg,
                    visceralFat: bc.visceralFat,
                    source: bc.source,
                    updatedAt: bc.date
                )
            },
            experiments: pendingExperiments.map { exp in
                ExperimentSyncDTO(
                    id: exp.persistentModelID.hashValue.description,
                    userId: exp.userId,
                    title: exp.title,
                    hypothesis: exp.hypothesis,
                    trackedMetrics: exp.trackedMetrics,
                    status: exp.status,
                    startDate: exp.startDate,
                    endDate: exp.endDate,
                    result: exp.result,
                    updatedAt: exp.startDate
                )
            }
        )

        let _: SyncPushResponse = try await apiClient.post(.syncPush, body: payload)

        // Mark all pushed records as synced.
        for panel in pendingBloodwork   { panel.syncStatus = .synced }
        for data  in pendingWearables   { data.syncStatus = .synced }
        for bc    in pendingBodyComp     { bc.syncStatus = .synced }
        for exp   in pendingExperiments  { exp.syncStatus = .synced }

        try modelContext.save()
    }

    // MARK: - Pull

    /// Fetches remote changes since the last sync and merges them into SwiftData.
    /// Conflict resolution: server wins. Conflicts are logged via AuditLogger.
    @MainActor
    func pullChanges(modelContext: ModelContext) async throws {
        let since = lastSyncDate ?? Date.distantPast
        let request = SyncPullRequest(since: since)

        let response: SyncPullResponse = try await apiClient.post(.syncPull, body: request)

        // Merge wearable data (server wins).
        if let remoteWearables = response.wearables {
            for dto in remoteWearables {
                let existing = try? modelContext.fetch(
                    FetchDescriptor<DailyWearableData>(
                        predicate: #Predicate { $0.userId == dto.userId && $0.date == dto.date }
                    )
                ).first

                if let existing {
                    if existing.syncStatus == .pending {
                        existing.syncStatus = .conflict
                        await auditLogger.log(.dataWrite, metadata: [
                            "action": "conflict_server_wins",
                            "type": "wearable",
                            "date": dto.date.ISO8601Format()
                        ])
                    }
                    // Server wins — overwrite local fields.
                    existing.hrvMs = dto.hrvMs
                    existing.restingHR = dto.restingHR
                    existing.sleepHours = dto.sleepHours
                    existing.deepSleepMinutes = dto.deepSleepMinutes
                    existing.remSleepMinutes = dto.remSleepMinutes
                    existing.recoveryScore = dto.recoveryScore
                    existing.strain = dto.strain
                    existing.steps = dto.steps
                    existing.activeCalories = dto.activeCalories
                    existing.syncStatus = .synced
                } else {
                    let newRecord = DailyWearableData(
                        userId: dto.userId,
                        date: dto.date,
                        source: dto.source,
                        hrvMs: dto.hrvMs,
                        restingHR: dto.restingHR,
                        sleepHours: dto.sleepHours,
                        deepSleepMinutes: dto.deepSleepMinutes,
                        remSleepMinutes: dto.remSleepMinutes,
                        recoveryScore: dto.recoveryScore,
                        strain: dto.strain,
                        steps: dto.steps,
                        activeCalories: dto.activeCalories,
                        syncStatus: .synced
                    )
                    modelContext.insert(newRecord)
                }
            }
        }

        // Merge bloodwork (server wins).
        if let remoteBloodwork = response.bloodwork {
            for dto in remoteBloodwork {
                let existing = try? modelContext.fetch(
                    FetchDescriptor<BloodworkPanel>(
                        predicate: #Predicate { $0.userId == dto.userId && $0.labDate == dto.labDate }
                    )
                ).first

                if let existing {
                    if existing.syncStatus == .pending {
                        await auditLogger.log(.dataWrite, metadata: [
                            "action": "conflict_server_wins",
                            "type": "bloodwork"
                        ])
                    }
                    existing.markers = dto.markers
                    existing.notes = dto.notes
                    existing.syncStatus = .synced
                } else {
                    let newPanel = BloodworkPanel(
                        userId: dto.userId,
                        labDate: dto.labDate,
                        source: dto.source,
                        markers: dto.markers,
                        notes: dto.notes,
                        syncStatus: .synced
                    )
                    modelContext.insert(newPanel)
                }
            }
        }

        // Merge body composition (server wins).
        if let remoteBodyComp = response.bodyComposition {
            for dto in remoteBodyComp {
                let existing = try? modelContext.fetch(
                    FetchDescriptor<BodyComposition>(
                        predicate: #Predicate { $0.userId == dto.userId && $0.date == dto.date }
                    )
                ).first

                if let existing {
                    if existing.syncStatus == .pending {
                        await auditLogger.log(.dataWrite, metadata: [
                            "action": "conflict_server_wins",
                            "type": "body_composition"
                        ])
                    }
                    existing.weightKg = dto.weightKg
                    existing.bodyFatPercent = dto.bodyFatPercent
                    existing.muscleMassKg = dto.muscleMassKg
                    existing.visceralFat = dto.visceralFat
                    existing.syncStatus = .synced
                } else {
                    let newBC = BodyComposition(
                        userId: dto.userId,
                        date: dto.date,
                        weightKg: dto.weightKg,
                        bodyFatPercent: dto.bodyFatPercent,
                        muscleMassKg: dto.muscleMassKg,
                        visceralFat: dto.visceralFat,
                        source: dto.source,
                        syncStatus: .synced
                    )
                    modelContext.insert(newBC)
                }
            }
        }

        try modelContext.save()
    }
}
