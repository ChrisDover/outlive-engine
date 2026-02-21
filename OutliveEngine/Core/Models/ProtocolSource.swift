// ProtocolSource.swift
// OutliveEngine
//
// Evidence-backed protocol sources that feed the daily protocol engine.

import Foundation
import SwiftData

@Model
final class ProtocolSource: Sendable {

    var userId: String
    var name: String
    var author: String
    var category: String

    // MARK: - Stored as JSON Data

    private var rulesData: Data?

    var rules: [String] {
        get { (try? JSONDecoder().decode([String].self, from: rulesData ?? Data())) ?? [] }
        set { rulesData = try? JSONEncoder().encode(newValue) }
    }

    var evidenceLevel: EvidenceLevel
    var isActive: Bool
    var priority: Int

    // MARK: - Metadata

    var syncStatus: SyncStatus

    // MARK: - Init

    init(
        userId: String,
        name: String,
        author: String,
        category: String,
        rules: [String] = [],
        evidenceLevel: EvidenceLevel = .observational,
        isActive: Bool = true,
        priority: Int = 0,
        syncStatus: SyncStatus = .pending
    ) {
        self.userId = userId
        self.name = name
        self.author = author
        self.category = category
        self.rulesData = try? JSONEncoder().encode(rules)
        self.evidenceLevel = evidenceLevel
        self.isActive = isActive
        self.priority = priority
        self.syncStatus = syncStatus
    }
}
