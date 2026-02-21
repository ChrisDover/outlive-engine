// MainTabView.swift
// OutliveEngine
//
// Primary tab navigation hosting all top-level screens.

import SwiftUI

struct MainTabView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState

        TabView(selection: $state.selectedTab) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                NavigationStack {
                    tabContent(for: tab)
                        .navigationTitle(tab.title)
                }
                .tabItem {
                    Label(tab.title, systemImage: tab.icon)
                }
                .tag(tab)
            }
        }
    }

    // MARK: - Tab Content

    @ViewBuilder
    private func tabContent(for tab: AppTab) -> some View {
        switch tab {
        case .dashboard:
            DailyDashboardView()

        case .protocols:
            ProtocolLibraryView()

        case .data:
            DataHubView()

        case .experiments:
            ExperimentDashboardView()

        case .settings:
            SettingsView()
        }
    }
}

// MARK: - Preview

#Preview {
    MainTabView()
        .environment(AppState())
        .modelContainer(try! DataStore.previewContainer())
}
