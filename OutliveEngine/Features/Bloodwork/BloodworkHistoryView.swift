// BloodworkHistoryView.swift
// OutliveEngine
//
// List of all bloodwork panels sorted by date with navigation to detail.

import SwiftUI
import SwiftData

struct BloodworkHistoryView: View {

    @Query(sort: \BloodworkPanel.labDate, order: .reverse)
    private var panels: [BloodworkPanel]

    @Environment(\.modelContext) private var modelContext
    @State private var showingAddPanel = false

    var body: some View {
        NavigationStack {
            Group {
                if panels.isEmpty {
                    EmptyStateView(
                        icon: "drop.fill",
                        title: "No Bloodwork Yet",
                        message: "Import your latest lab results to see biomarker trends and personalized insights.",
                        actionTitle: "Add Panel"
                    ) {
                        showingAddPanel = true
                    }
                } else {
                    panelList
                }
            }
            .navigationTitle("Bloodwork")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddPanel = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.outliveHeadline)
                            .foregroundStyle(Color.domainBloodwork)
                    }
                }
            }
            .sheet(isPresented: $showingAddPanel) {
                AddBloodworkPanelSheet()
            }
            .background(Color.surfaceBackground)
        }
    }

    // MARK: - Panel List

    private var panelList: some View {
        ScrollView {
            LazyVStack(spacing: OutliveSpacing.sm) {
                ForEach(panels) { panel in
                    NavigationLink {
                        BloodworkDetailView(panel: panel)
                    } label: {
                        PanelRow(panel: panel)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, OutliveSpacing.md)
            .padding(.bottom, OutliveSpacing.xl)
        }
    }
}

// MARK: - Panel Row

private struct PanelRow: View {

    let panel: BloodworkPanel

    var body: some View {
        HStack(spacing: OutliveSpacing.sm) {
            VStack(alignment: .leading, spacing: OutliveSpacing.xxs) {
                Text(panel.labDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.outliveHeadline)
                    .foregroundStyle(Color.textPrimary)

                HStack(spacing: OutliveSpacing.xs) {
                    sourceBadge
                    markerCountLabel
                }
            }

            Spacer()

            statusSummary

            Image(systemName: "chevron.right")
                .font(.outliveCaption)
                .foregroundStyle(Color.textTertiary)
        }
        .padding(OutliveSpacing.md)
        .background(Color.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.medium, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
    }

    private var sourceBadge: some View {
        Text(panel.source.rawValue.capitalized)
            .font(.outliveCaption)
            .foregroundStyle(Color.domainBloodwork)
            .padding(.horizontal, OutliveSpacing.xs)
            .padding(.vertical, 2)
            .background(Color.domainBloodwork.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.small, style: .continuous))
    }

    private var markerCountLabel: some View {
        Text("\(panel.markers.count) markers")
            .font(.outliveCaption)
            .foregroundStyle(Color.textTertiary)
    }

    private var statusSummary: some View {
        let counts = statusCounts
        return HStack(spacing: OutliveSpacing.xxs) {
            if counts.critical > 0 {
                statusDot(color: .recoveryRed, count: counts.critical)
            }
            if counts.suboptimal > 0 {
                statusDot(color: .recoveryYellow, count: counts.suboptimal)
            }
            if counts.optimal > 0 {
                statusDot(color: .recoveryGreen, count: counts.optimal)
            }
        }
    }

    private func statusDot(color: Color, count: Int) -> some View {
        HStack(spacing: 2) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text("\(count)")
                .font(.outliveMonoSmall)
                .foregroundStyle(Color.textSecondary)
        }
    }

    private var statusCounts: (optimal: Int, normal: Int, suboptimal: Int, critical: Int) {
        var optimal = 0, normal = 0, suboptimal = 0, critical = 0
        for marker in panel.markers {
            switch marker.status {
            case .optimal:    optimal += 1
            case .normal:     normal += 1
            case .suboptimal: suboptimal += 1
            case .critical:   critical += 1
            }
        }
        return (optimal, normal, suboptimal, critical)
    }
}

// MARK: - Add Panel Sheet (Placeholder)

private struct AddBloodworkPanelSheet: View {

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: OutliveSpacing.lg) {
                EmptyStateView(
                    icon: "doc.text.viewfinder",
                    title: "Add Bloodwork Panel",
                    message: "Import lab results from LabCorp, Quest, or enter values manually."
                )
            }
            .navigationTitle("New Panel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    BloodworkHistoryView()
        .modelContainer(for: BloodworkPanel.self, inMemory: true)
}
