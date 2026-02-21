// SecuritySettingsView.swift
// OutliveEngine
//
// Encryption status, biometric lock, and audit log viewer.

import SwiftUI
import LocalAuthentication

struct SecuritySettingsView: View {

    @State private var biometricEnabled = false
    @State private var biometricType: BiometricType = .none
    @State private var showingAuditLog = false
    @State private var auditEntries: [AuditEntry] = []

    var body: some View {
        List {
            encryptionSection
            biometricSection
            auditSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Security")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { detectBiometricType() }
        .sheet(isPresented: $showingAuditLog) {
            AuditLogSheet(entries: auditEntries)
        }
    }

    // MARK: - Encryption

    private var encryptionSection: some View {
        Section {
            HStack {
                Label {
                    Text("Data Encryption")
                        .font(.outliveBody)
                        .foregroundStyle(Color.textPrimary)
                } icon: {
                    Image(systemName: "lock.shield.fill")
                        .foregroundStyle(Color.recoveryGreen)
                }

                Spacer()

                Text("Active")
                    .font(.outliveMonoSmall)
                    .foregroundStyle(Color.recoveryGreen)
                    .padding(.horizontal, OutliveSpacing.xs)
                    .padding(.vertical, 2)
                    .background(Color.recoveryGreen.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.small, style: .continuous))
            }

            VStack(alignment: .leading, spacing: OutliveSpacing.xs) {
                encryptionDetail(label: "Algorithm", value: "AES-256-GCM")
                encryptionDetail(label: "Key Derivation", value: "HKDF-SHA256")
                encryptionDetail(label: "Storage", value: "Secure Enclave")
                encryptionDetail(label: "Genomic Data", value: "On-device only, never synced")
            }
        } header: {
            Text("Encryption")
        } footer: {
            Text("All sensitive health data is encrypted at rest using keys stored in the Secure Enclave. Genomic data never leaves your device.")
        }
    }

    private func encryptionDetail(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.outliveSubheadline)
                .foregroundStyle(Color.textSecondary)

            Spacer()

            Text(value)
                .font(.outliveMonoSmall)
                .foregroundStyle(Color.textPrimary)
        }
    }

    // MARK: - Biometric

    private var biometricSection: some View {
        Section {
            Toggle(isOn: $biometricEnabled) {
                Label {
                    Text(biometricType.label)
                        .font(.outliveBody)
                        .foregroundStyle(Color.textPrimary)
                } icon: {
                    Image(systemName: biometricType.icon)
                        .foregroundStyle(Color.domainTraining)
                }
            }
            .tint(Color.recoveryGreen)
            .disabled(biometricType == .none)
        } header: {
            Text("Biometric Lock")
        } footer: {
            Text(biometricType == .none
                 ? "No biometric authentication is available on this device."
                 : "Require \(biometricType.label) to open the app.")
        }
    }

    // MARK: - Audit Log

    private var auditSection: some View {
        Section {
            Button {
                showingAuditLog = true
            } label: {
                Label {
                    Text("View Audit Log")
                        .font(.outliveBody)
                        .foregroundStyle(Color.textPrimary)
                } icon: {
                    Image(systemName: "doc.text.magnifyingglass")
                        .foregroundStyle(Color.domainSupplements)
                }
            }
        } header: {
            Text("Audit Trail")
        } footer: {
            Text("Review recent security events and data access activity.")
        }
    }

    // MARK: - Helpers

    private func detectBiometricType() {
        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            switch context.biometryType {
            case .faceID:    biometricType = .faceID
            case .touchID:   biometricType = .touchID
            case .opticID:   biometricType = .opticID
            @unknown default: biometricType = .none
            }
        } else {
            biometricType = .none
        }
    }
}

// MARK: - Biometric Type

private enum BiometricType {
    case faceID, touchID, opticID, none

    var label: String {
        switch self {
        case .faceID:  return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        case .none:    return "Biometric Lock"
        }
    }

    var icon: String {
        switch self {
        case .faceID:  return "faceid"
        case .touchID: return "touchid"
        case .opticID: return "opticid"
        case .none:    return "lock.fill"
        }
    }
}

// MARK: - Audit Log Sheet

private struct AuditLogSheet: View {

    let entries: [AuditEntry]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    VStack(spacing: OutliveSpacing.md) {
                        Spacer()
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 48, weight: .light))
                            .foregroundStyle(Color.recoveryGreen)

                        Text("No Recent Events")
                            .font(.outliveTitle3)
                            .foregroundStyle(Color.textPrimary)

                        Text("Security events will appear here as they occur.")
                            .font(.outliveBody)
                            .foregroundStyle(Color.textSecondary)
                            .multilineTextAlignment(.center)
                        Spacer()
                    }
                } else {
                    List(entries) { entry in
                        VStack(alignment: .leading, spacing: OutliveSpacing.xxs) {
                            HStack {
                                Text(entry.action.rawValue)
                                    .font(.outliveHeadline)
                                    .foregroundStyle(Color.textPrimary)

                                Spacer()

                                Text(entry.timestamp.formatted(date: .abbreviated, time: .shortened))
                                    .font(.outliveCaption)
                                    .foregroundStyle(Color.textTertiary)
                            }

                            if let endpoint = entry.endpoint {
                                Text(endpoint)
                                    .font(.outliveMonoSmall)
                                    .foregroundStyle(Color.textSecondary)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Audit Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SecuritySettingsView()
    }
}
