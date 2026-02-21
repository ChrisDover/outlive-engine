// AppState.swift
// OutliveEngine
//
// Observable app-wide state driving navigation and authentication flow.

import SwiftUI

// MARK: - App Tab

enum AppTab: String, CaseIterable, Sendable {
    case dashboard
    case protocols
    case data
    case experiments
    case settings

    var title: String {
        switch self {
        case .dashboard:   "Dashboard"
        case .protocols:   "Protocols"
        case .data:        "Data"
        case .experiments: "Experiments"
        case .settings:    "Settings"
        }
    }

    var icon: String {
        switch self {
        case .dashboard:   "heart.text.clipboard"
        case .protocols:   "list.bullet.clipboard"
        case .data:        "chart.xyaxis.line"
        case .experiments: "flask"
        case .settings:    "gearshape"
        }
    }
}

// MARK: - App State

@Observable
final class AppState: Sendable {
    var isAuthenticated: Bool = false
    var hasCompletedOnboarding: Bool = false
    var selectedTab: AppTab = .dashboard
    var currentUserId: String?
}
