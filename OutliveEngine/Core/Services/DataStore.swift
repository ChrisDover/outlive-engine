// DataStore.swift
// OutliveEngine
//
// Configures the SwiftData ModelContainer for all persistent model types.

import Foundation
import SwiftData

enum DataStore {

    /// All model types registered in the Outlive Engine schema.
    private static let modelTypes: [any PersistentModel.Type] = [
        UserProfile.self,
        GenomicProfile.self,
        BloodworkPanel.self,
        DailyWearableData.self,
        BodyComposition.self,
        DailyProtocol.self,
        Experiment.self,
        ProtocolSource.self
    ]

    // MARK: - Production Container

    /// Creates the main ModelContainer backed by persistent storage.
    static func makeContainer() throws -> ModelContainer {
        let schema = Schema(modelTypes)
        let configuration = ModelConfiguration(
            "OutliveEngine",
            schema: schema
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    // MARK: - Preview Container

    /// Creates an in-memory ModelContainer for SwiftUI previews and tests.
    static func previewContainer() throws -> ModelContainer {
        let schema = Schema(modelTypes)
        let configuration = ModelConfiguration(
            "OutliveEngine",
            schema: schema,
            isStoredInMemoryOnly: true
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
