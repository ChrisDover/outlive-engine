// ContentView.swift
// OutliveEngine
//
// Root view that gates between onboarding and the main tab interface.

import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if appState.isAuthenticated && appState.hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingFlow()
            }
        }
        .animation(.easeInOut, value: appState.isAuthenticated)
        .animation(.easeInOut, value: appState.hasCompletedOnboarding)
    }

}

// MARK: - Preview

#Preview {
    ContentView()
        .environment(AppState())
        .modelContainer(try! DataStore.previewContainer())
}
