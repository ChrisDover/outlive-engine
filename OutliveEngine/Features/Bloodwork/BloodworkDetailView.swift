// BloodworkDetailView.swift
// OutliveEngine
//
// Shows all markers for a single bloodwork panel grouped by category.

import SwiftUI

struct BloodworkDetailView: View {

    let panel: BloodworkPanel

    private let analyzer = BiomarkerAnalyzer()

    var body: some View {
        ScrollView {
            VStack(spacing: OutliveSpacing.lg) {
                panelSummary
                markerGroups
                notesSection
            }
            .padding(.horizontal, OutliveSpacing.md)
            .padding(.bottom, OutliveSpacing.xl)
        }
        .background(Color.surfaceBackground)
        .navigationTitle(panel.labDate.formatted(date: .abbreviated, time: .omitted))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Panel Summary

    private var panelSummary: some View {
        let counts = statusCounts

        return VStack(spacing: OutliveSpacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: OutliveSpacing.xxs) {
                    Text("Panel Summary")
                        .font(.outliveTitle3)
                        .foregroundStyle(Color.textPrimary)

                    Text("\(panel.markers.count) biomarkers analyzed")
                        .font(.outliveSubheadline)
                        .foregroundStyle(Color.textSecondary)
                }

                Spacer()

                Text(panel.source.rawValue.capitalized)
                    .font(.outliveCaption)
                    .foregroundStyle(Color.domainBloodwork)
                    .padding(.horizontal, OutliveSpacing.xs)
                    .padding(.vertical, OutliveSpacing.xxs)
                    .background(Color.domainBloodwork.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.small, style: .continuous))
            }

            HStack(spacing: OutliveSpacing.md) {
                summaryPill(label: "Optimal", count: counts.optimal, color: .recoveryGreen)
                summaryPill(label: "Normal", count: counts.normal, color: .domainTraining)
                summaryPill(label: "Suboptimal", count: counts.suboptimal, color: .recoveryYellow)
                summaryPill(label: "Critical", count: counts.critical, color: .recoveryRed)
            }
        }
        .padding(OutliveSpacing.md)
        .background(Color.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.medium, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
    }

    private func summaryPill(label: String, count: Int, color: Color) -> some View {
        VStack(spacing: OutliveSpacing.xxs) {
            Text("\(count)")
                .font(.outliveMonoData)
                .foregroundStyle(color)
            Text(label)
                .font(.outliveCaption)
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Marker Groups

    private var markerGroups: some View {
        let grouped = groupedMarkers

        return ForEach(MarkerCategory.allCases, id: \.self) { category in
            if let markers = grouped[category], !markers.isEmpty {
                VStack(spacing: OutliveSpacing.sm) {
                    SectionHeader(title: category.title)

                    ForEach(markers, id: \.name) { marker in
                        BiomarkerGauge(
                            name: marker.name,
                            value: marker.value,
                            unit: marker.unit,
                            optimalLow: marker.optimalLow,
                            optimalHigh: marker.optimalHigh,
                            normalLow: marker.normalLow,
                            normalHigh: marker.normalHigh
                        )
                    }
                }
            }
        }
    }

    // MARK: - Notes

    @ViewBuilder
    private var notesSection: some View {
        if let notes = panel.notes, !notes.isEmpty {
            VStack(spacing: OutliveSpacing.sm) {
                SectionHeader(title: "Notes")

                Text(notes)
                    .font(.outliveBody)
                    .foregroundStyle(Color.textSecondary)
                    .padding(OutliveSpacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.surfaceCard)
                    .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.medium, style: .continuous))
            }
        }
    }

    // MARK: - Helpers

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

    private var groupedMarkers: [MarkerCategory: [BloodworkMarker]] {
        Dictionary(grouping: panel.markers) { marker in
            MarkerCategory.categorize(marker.name)
        }
    }
}

// MARK: - Marker Categories

private enum MarkerCategory: String, CaseIterable {
    case hormones
    case vitamins
    case metabolic
    case inflammatory
    case lipids
    case thyroid
    case other

    var title: String {
        switch self {
        case .hormones:      return "Hormones"
        case .vitamins:      return "Vitamins & Minerals"
        case .metabolic:     return "Metabolic"
        case .inflammatory:  return "Inflammatory"
        case .lipids:        return "Lipids & Cardiovascular"
        case .thyroid:       return "Thyroid"
        case .other:         return "Other"
        }
    }

    static func categorize(_ name: String) -> MarkerCategory {
        let lower = name.lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")

        if ["testosterone", "freetestosterone", "cortisol", "dheas", "dhea", "estradiol", "igf1", "shbg", "prolactin", "progesterone", "lh", "fsh"]
            .contains(where: { lower.contains($0) }) {
            return .hormones
        }
        if ["vitamind", "vitaminb12", "b12", "folate", "ferritin", "iron", "magnesium", "zinc", "vitamina", "vitaminc"]
            .contains(where: { lower.contains($0) }) {
            return .vitamins
        }
        if ["glucose", "insulin", "hba1c", "a1c", "hemoglobina1c"]
            .contains(where: { lower.contains($0) }) {
            return .metabolic
        }
        if ["hscrp", "crp", "homocysteine", "esr", "fibrinogen"]
            .contains(where: { lower.contains($0) }) {
            return .inflammatory
        }
        if ["apob", "lpa", "ldl", "hdl", "triglyceride", "cholesterol", "vldl"]
            .contains(where: { lower.contains($0) }) {
            return .lipids
        }
        if ["tsh", "freet3", "freet4", "t3", "t4", "thyroid"]
            .contains(where: { lower.contains($0) }) {
            return .thyroid
        }
        return .other
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        BloodworkDetailView(
            panel: BloodworkPanel(
                userId: "preview",
                labDate: Date(),
                source: .manual,
                markers: [
                    BloodworkMarker(name: "Testosterone", value: 680, unit: "ng/dL",
                                    optimalLow: 600, optimalHigh: 900, normalLow: 300, normalHigh: 1000),
                    BloodworkMarker(name: "Vitamin D", value: 38, unit: "ng/mL",
                                    optimalLow: 50, optimalHigh: 80, normalLow: 30, normalHigh: 100),
                    BloodworkMarker(name: "hsCRP", value: 3.2, unit: "mg/L",
                                    optimalLow: 0, optimalHigh: 1, normalLow: 0, normalHigh: 3),
                ],
                notes: "Fasted draw at 8am. Felt well-rested."
            )
        )
    }
}
