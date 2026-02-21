// SettingsView.swift
// OutliveEngine
//
// Main settings screen with navigation to detail settings views.

import SwiftUI

struct SettingsView: View {

    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationStack {
            List {
                profileSection
                connectionsSection
                notificationsSection
                securitySection
                dataSection
                aboutSection
                signOutSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .background(Color.surfaceBackground)
        }
    }

    // MARK: - Profile

    private var profileSection: some View {
        Section {
            NavigationLink {
                ProfileEditView()
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: OutliveSpacing.xxs) {
                        Text("Profile")
                            .font(.outliveHeadline)
                            .foregroundStyle(Color.textPrimary)

                        Text("Name, birth date, goals, allergies")
                            .font(.outliveCaption)
                            .foregroundStyle(Color.textSecondary)
                    }
                } icon: {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.outliveTitle3)
                        .foregroundStyle(Color.domainTraining)
                }
            }
        }
    }

    // MARK: - Connections

    private var connectionsSection: some View {
        Section("Connections") {
            NavigationLink {
                WearableSettingsView()
            } label: {
                Label {
                    Text("Wearable Devices")
                        .font(.outliveBody)
                        .foregroundStyle(Color.textPrimary)
                } icon: {
                    Image(systemName: "applewatch")
                        .foregroundStyle(Color.domainInterventions)
                }
            }
        }
    }

    // MARK: - Notifications

    private var notificationsSection: some View {
        Section("Notifications") {
            NavigationLink {
                NotificationSettingsView()
            } label: {
                Label {
                    Text("Notification Preferences")
                        .font(.outliveBody)
                        .foregroundStyle(Color.textPrimary)
                } icon: {
                    Image(systemName: "bell.badge.fill")
                        .foregroundStyle(Color.domainNutrition)
                }
            }
        }
    }

    // MARK: - Security

    private var securitySection: some View {
        Section("Security") {
            NavigationLink {
                SecuritySettingsView()
            } label: {
                Label {
                    Text("Security & Encryption")
                        .font(.outliveBody)
                        .foregroundStyle(Color.textPrimary)
                } icon: {
                    Image(systemName: "lock.shield.fill")
                        .foregroundStyle(Color.recoveryGreen)
                }
            }
        }
    }

    // MARK: - Data

    private var dataSection: some View {
        Section("Data") {
            NavigationLink {
                DataExportView()
            } label: {
                Label {
                    Text("Export & Delete Data")
                        .font(.outliveBody)
                        .foregroundStyle(Color.textPrimary)
                } icon: {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(Color.domainSupplements)
                }
            }
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section("About") {
            NavigationLink {
                MedicalDisclaimerView()
            } label: {
                Label {
                    Text("Medical Disclaimer")
                        .font(.outliveBody)
                        .foregroundStyle(Color.textPrimary)
                } icon: {
                    Image(systemName: "cross.case.fill")
                        .foregroundStyle(Color.domainBloodwork)
                }
            }

            HStack {
                Label {
                    Text("Version")
                        .font(.outliveBody)
                        .foregroundStyle(Color.textPrimary)
                } icon: {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(Color.textSecondary)
                }

                Spacer()

                Text("1.0.0")
                    .font(.outliveMonoSmall)
                    .foregroundStyle(Color.textTertiary)
            }
        }
    }

    // MARK: - Sign Out

    private var signOutSection: some View {
        Section {
            Button(role: .destructive) {
                signOut()
            } label: {
                HStack {
                    Spacer()
                    Text("Sign Out")
                        .font(.outliveHeadline)
                    Spacer()
                }
            }
        }
    }

    // MARK: - Actions

    private func signOut() {
        appState.isAuthenticated = false
        appState.currentUserId = nil
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .environment(AppState())
}
