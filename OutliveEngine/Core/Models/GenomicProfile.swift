// GenomicProfile.swift
// OutliveEngine
//
// Genomic data model. Raw SNP data is stored on-device only and never syncs to server.

import Foundation
import SwiftData

@Model
final class GenomicProfile {

    var userId: String

    /// Encrypted raw SNP data. Stored on-device only — never syncs to server.
    @Attribute(.allowsCloudEncryption)
    var encryptedSNPData: Data?

    var fileHash: String
    var processedDate: Date

    // MARK: - Stored as JSON Data

    private var risksData: Data?

    var risks: [GeneticRisk] {
        get { (try? JSONDecoder().decode([GeneticRisk].self, from: risksData ?? Data())) ?? [] }
        set { risksData = try? JSONEncoder().encode(newValue) }
    }

    // MARK: - Metadata

    var syncStatus: SyncStatus

    // MARK: - Init

    init(
        userId: String,
        encryptedSNPData: Data? = nil,
        fileHash: String,
        processedDate: Date = .now,
        risks: [GeneticRisk] = [],
        syncStatus: SyncStatus = .pending
    ) {
        self.userId = userId
        self.encryptedSNPData = encryptedSNPData
        self.fileHash = fileHash
        self.processedDate = processedDate
        self.risksData = try? JSONEncoder().encode(risks)
        self.syncStatus = syncStatus
    }
}
