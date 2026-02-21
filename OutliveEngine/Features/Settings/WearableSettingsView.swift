// WearableSettingsView.swift
// OutliveEngine
//
// Connected wearable devices list with connect/disconnect actions and sync settings.

import SwiftUI

struct WearableSettingsView: View {

    @State private var connectedDevices: [WearableDevice] = [
        WearableDevice(source: .appleWatch, isConnected: true, lastSync: Date()),
    ]

    @State private var syncFrequency: SyncFrequency = .hourly

    var body: some View {
        List {
            connectedSection
            availableSection
            syncSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Wearable Devices")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Connected Devices

    private var connectedSection: some View {
        Section("Connected") {
            let connected = connectedDevices.filter(\.isConnected)

            if connected.isEmpty {
                Text("No devices connected")
                    .font(.outliveBody)
                    .foregroundStyle(Color.textSecondary)
            } else {
                ForEach(connected) { device in
                    connectedDeviceRow(device)
                }
            }
        }
    }

    private func connectedDeviceRow(_ device: WearableDevice) -> some View {
        HStack(spacing: OutliveSpacing.sm) {
            Image(systemName: device.source.icon)
                .font(.outliveTitle3)
                .foregroundStyle(Color.domainInterventions)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: OutliveSpacing.xxs) {
                Text(device.source.displayName)
                    .font(.outliveHeadline)
                    .foregroundStyle(Color.textPrimary)

                if let lastSync = device.lastSync {
                    Text("Last sync: \(lastSync.formatted(date: .abbreviated, time: .shortened))")
                        .font(.outliveCaption)
                        .foregroundStyle(Color.textTertiary)
                }
            }

            Spacer()

            Button("Disconnect") {
                disconnectDevice(device)
            }
            .font(.outliveCaption)
            .foregroundStyle(Color.recoveryRed)
        }
    }

    // MARK: - Available Devices

    private var availableSection: some View {
        Section("Available") {
            let disconnected = WearableSource.allCases.filter { source in
                !connectedDevices.contains { $0.source == source && $0.isConnected }
            }

            ForEach(disconnected, id: \.self) { source in
                HStack(spacing: OutliveSpacing.sm) {
                    Image(systemName: source.icon)
                        .font(.outliveTitle3)
                        .foregroundStyle(Color.textTertiary)
                        .frame(width: 32)

                    Text(source.displayName)
                        .font(.outliveBody)
                        .foregroundStyle(Color.textPrimary)

                    Spacer()

                    Button("Connect") {
                        connectDevice(source)
                    }
                    .font(.outliveSubheadline)
                    .foregroundStyle(Color.domainTraining)
                }
            }
        }
    }

    // MARK: - Sync Settings

    private var syncSection: some View {
        Section {
            Picker("Sync Frequency", selection: $syncFrequency) {
                ForEach(SyncFrequency.allCases, id: \.self) { frequency in
                    Text(frequency.label).tag(frequency)
                }
            }
        } header: {
            Text("Sync Settings")
        } footer: {
            Text("How often the app pulls new data from connected wearables.")
        }
    }

    // MARK: - Actions

    private func connectDevice(_ source: WearableSource) {
        let device = WearableDevice(source: source, isConnected: true, lastSync: nil)
        connectedDevices.append(device)
    }

    private func disconnectDevice(_ device: WearableDevice) {
        if let index = connectedDevices.firstIndex(where: { $0.id == device.id }) {
            connectedDevices[index].isConnected = false
        }
    }
}

// MARK: - Supporting Types

private struct WearableDevice: Identifiable {
    let id = UUID()
    let source: WearableSource
    var isConnected: Bool
    var lastSync: Date?
}

private enum SyncFrequency: String, CaseIterable {
    case realtime
    case hourly
    case daily

    var label: String {
        switch self {
        case .realtime: return "Real-time"
        case .hourly:   return "Hourly"
        case .daily:    return "Daily"
        }
    }
}

extension WearableSource {

    var displayName: String {
        switch self {
        case .appleWatch: return "Apple Watch"
        case .whoop:      return "WHOOP"
        case .oura:       return "Oura Ring"
        case .garmin:     return "Garmin"
        case .manual:     return "Manual Entry"
        }
    }

    var icon: String {
        switch self {
        case .appleWatch: return "applewatch"
        case .whoop:      return "waveform.path.ecg.rectangle"
        case .oura:       return "circle.circle"
        case .garmin:     return "watchface.applewatch.case"
        case .manual:     return "hand.tap"
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        WearableSettingsView()
    }
}
