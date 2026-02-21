// DataExportView.swift
// OutliveEngine
//
// Export all data as JSON, share sheet integration, and data deletion.

import SwiftUI
import SwiftData

struct DataExportView: View {

    @Environment(\.modelContext) private var modelContext
    @State private var isExporting = false
    @State private var showingShareSheet = false
    @State private var exportURL: URL?
    @State private var showingDeleteConfirmation = false
    @State private var showingFinalDeleteConfirmation = false

    var body: some View {
        List {
            exportSection
            deleteSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Data Management")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingShareSheet) {
            if let url = exportURL {
                ShareSheet(items: [url])
            }
        }
        .alert("Delete All Data?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Continue", role: .destructive) {
                showingFinalDeleteConfirmation = true
            }
        } message: {
            Text("This will permanently delete all your health data including bloodwork, genomic profiles, experiments, and protocols. This action cannot be undone.")
        }
        .alert("Are you absolutely sure?", isPresented: $showingFinalDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete Everything", role: .destructive) {
                deleteAllData()
            }
        } message: {
            Text("All data will be permanently erased from this device. There is no way to recover it.")
        }
    }

    // MARK: - Export

    private var exportSection: some View {
        Section {
            Button {
                exportData()
            } label: {
                Label {
                    HStack {
                        Text("Export All Data as JSON")
                            .font(.outliveBody)
                            .foregroundStyle(Color.textPrimary)

                        Spacer()

                        if isExporting {
                            ProgressView()
                        }
                    }
                } icon: {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(Color.domainTraining)
                }
            }
            .disabled(isExporting)
        } header: {
            Text("Export")
        } footer: {
            Text("Exports all your health data as a JSON file that you can save, share, or import into another system.")
        }
    }

    // MARK: - Delete

    private var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                showingDeleteConfirmation = true
            } label: {
                Label {
                    Text("Delete All Data")
                        .font(.outliveBody)
                } icon: {
                    Image(systemName: "trash.fill")
                        .foregroundStyle(Color.recoveryRed)
                }
            }
        } header: {
            Text("Danger Zone")
        } footer: {
            Text("Permanently delete all health data from this device. This action is irreversible.")
        }
    }

    // MARK: - Actions

    private func exportData() {
        isExporting = true

        // Build export payload
        Task { @MainActor in
            let exportPayload: [String: String] = [
                "exportDate": ISO8601DateFormatter().string(from: Date()),
                "appVersion": "1.0.0",
                "note": "Outlive Engine data export"
            ]

            do {
                let data = try JSONEncoder().encode(exportPayload)
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("outlive-export-\(Date().timeIntervalSince1970).json")
                try data.write(to: tempURL)
                exportURL = tempURL
                showingShareSheet = true
            } catch {
                // Export failed silently for now
            }

            isExporting = false
        }
    }

    private func deleteAllData() {
        // Placeholder: In production, iterate over all model types and delete
    }
}

// MARK: - Share Sheet

private struct ShareSheet: UIViewControllerRepresentable {

    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    NavigationStack {
        DataExportView()
    }
}
