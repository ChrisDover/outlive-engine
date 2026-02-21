// OutliveEngineApp.swift
// OutliveEngine
//
// App entry point. Configures the SwiftData container and injects shared state.

import SwiftUI
import SwiftData

@main
struct OutliveEngineApp: App {
    private let modelContainer: ModelContainer
    @State private var appState = AppState()

    init() {
        do {
            modelContainer = try DataStore.makeContainer()
        } catch {
            fatalError("Failed to initialize ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
        }
        .modelContainer(modelContainer)
    }
}
