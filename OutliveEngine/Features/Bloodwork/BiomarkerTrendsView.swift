// BiomarkerTrendsView.swift
// OutliveEngine
//
// Shows trends for a selected biomarker across multiple panels with line chart.

import SwiftUI
import SwiftData

struct BiomarkerTrendsView: View {

    @Query(sort: \BloodworkPanel.labDate, order: .forward)
    private var panels: [BloodworkPanel]

    @State private var selectedMarkerName: String?

    private var availableMarkerNames: [String] {
        var names: [String] = []
        var seen: Set<String> = []
        for panel in panels {
            for marker in panel.markers where !seen.contains(marker.name) {
                seen.insert(marker.name)
                names.append(marker.name)
            }
        }
        return names.sorted()
    }

    var body: some View {
        NavigationStack {
            Group {
                if panels.isEmpty {
                    EmptyStateView(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "No Trend Data",
                        message: "Add at least two bloodwork panels to see biomarker trends over time."
                    )
                } else {
                    trendContent
                }
            }
            .navigationTitle("Biomarker Trends")
            .background(Color.surfaceBackground)
        }
    }

    // MARK: - Content

    private var trendContent: some View {
        ScrollView {
            VStack(spacing: OutliveSpacing.lg) {
                markerPicker
                if let selectedMarkerName {
                    let dataPoints = dataPointsFor(selectedMarkerName)
                    if dataPoints.count >= 2 {
                        trendSummary(dataPoints)
                        trendChart(dataPoints)
                        historyList(dataPoints)
                    } else {
                        noDataMessage
                    }
                }
            }
            .padding(.horizontal, OutliveSpacing.md)
            .padding(.bottom, OutliveSpacing.xl)
        }
        .onAppear {
            if selectedMarkerName == nil {
                selectedMarkerName = availableMarkerNames.first
            }
        }
    }

    // MARK: - Marker Picker

    private var markerPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: OutliveSpacing.xs) {
                ForEach(availableMarkerNames, id: \.self) { name in
                    Button {
                        withAnimation { selectedMarkerName = name }
                    } label: {
                        Text(name)
                            .font(.outliveSubheadline)
                            .foregroundStyle(selectedMarkerName == name ? .white : Color.textPrimary)
                            .padding(.horizontal, OutliveSpacing.sm)
                            .padding(.vertical, OutliveSpacing.xs)
                            .background(selectedMarkerName == name ? Color.domainBloodwork : Color.surfaceCard)
                            .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.small, style: .continuous))
                    }
                }
            }
        }
    }

    // MARK: - Trend Summary

    private func trendSummary(_ dataPoints: [TrendDataPoint]) -> some View {
        let current = dataPoints.last!
        let previous = dataPoints[dataPoints.count - 2]
        let percentChange = previous.value != 0
            ? ((current.value - previous.value) / previous.value) * 100
            : 0

        return HStack(spacing: OutliveSpacing.md) {
            VStack(alignment: .leading, spacing: OutliveSpacing.xxs) {
                Text("Current")
                    .font(.outliveCaption)
                    .foregroundStyle(Color.textSecondary)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(formatValue(current.value))
                        .font(.outliveTitle2)
                        .foregroundStyle(Color.textPrimary)

                    Text(current.unit)
                        .font(.outliveMonoSmall)
                        .foregroundStyle(Color.textSecondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: OutliveSpacing.xxs) {
                Text("Change")
                    .font(.outliveCaption)
                    .foregroundStyle(Color.textSecondary)

                HStack(spacing: 4) {
                    Image(systemName: trendArrow(percentChange))
                        .foregroundStyle(trendColor(percentChange))

                    Text("\(formatValue(abs(percentChange)))%")
                        .font(.outliveMonoData)
                        .foregroundStyle(trendColor(percentChange))
                }
            }
        }
        .padding(OutliveSpacing.md)
        .background(Color.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.medium, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
    }

    // MARK: - Trend Chart

    private func trendChart(_ dataPoints: [TrendDataPoint]) -> some View {
        VStack(spacing: OutliveSpacing.sm) {
            SectionHeader(title: "Trend")

            GeometryReader { geometry in
                let width = geometry.size.width
                let height = geometry.size.height
                let values = dataPoints.map(\.value)
                let minVal = (values.min() ?? 0) * 0.9
                let maxVal = (values.max() ?? 1) * 1.1
                let range = maxVal - minVal

                ZStack {
                    // Grid lines
                    ForEach(0..<4) { i in
                        let y = height * CGFloat(i) / 3.0
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: width, y: y))
                        }
                        .stroke(Color.textTertiary.opacity(0.2), lineWidth: 0.5)
                    }

                    // Line
                    if dataPoints.count >= 2 {
                        Path { path in
                            for (index, point) in dataPoints.enumerated() {
                                let x = width * CGFloat(index) / CGFloat(dataPoints.count - 1)
                                let y = range > 0
                                    ? height * (1 - CGFloat((point.value - minVal) / range))
                                    : height / 2

                                if index == 0 {
                                    path.move(to: CGPoint(x: x, y: y))
                                } else {
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                            }
                        }
                        .stroke(Color.domainBloodwork, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                        // Data points
                        ForEach(dataPoints.indices, id: \.self) { index in
                            let point = dataPoints[index]
                            let x = width * CGFloat(index) / CGFloat(dataPoints.count - 1)
                            let y = range > 0
                                ? height * (1 - CGFloat((point.value - minVal) / range))
                                : height / 2

                            Circle()
                                .fill(Color.domainBloodwork)
                                .frame(width: 8, height: 8)
                                .position(x: x, y: y)
                        }
                    }
                }
            }
            .frame(height: 180)
            .padding(OutliveSpacing.md)
            .background(Color.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.medium, style: .continuous))
        }
    }

    // MARK: - History List

    private func historyList(_ dataPoints: [TrendDataPoint]) -> some View {
        VStack(spacing: OutliveSpacing.sm) {
            SectionHeader(title: "History")

            ForEach(dataPoints.reversed()) { point in
                HStack {
                    Text(point.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.outliveSubheadline)
                        .foregroundStyle(Color.textSecondary)

                    Spacer()

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(formatValue(point.value))
                            .font(.outliveMonoData)
                            .foregroundStyle(Color.textPrimary)

                        Text(point.unit)
                            .font(.outliveMonoSmall)
                            .foregroundStyle(Color.textTertiary)
                    }
                }
                .padding(.horizontal, OutliveSpacing.md)
                .padding(.vertical, OutliveSpacing.xs)
            }
            .background(Color.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.medium, style: .continuous))
        }
    }

    // MARK: - No Data

    private var noDataMessage: some View {
        Text("Need at least two panels with this marker to show trends.")
            .font(.outliveBody)
            .foregroundStyle(Color.textSecondary)
            .multilineTextAlignment(.center)
            .padding(OutliveSpacing.lg)
    }

    // MARK: - Helpers

    private func dataPointsFor(_ name: String) -> [TrendDataPoint] {
        panels.compactMap { panel in
            guard let marker = panel.markers.first(where: { $0.name == name }) else {
                return nil
            }
            return TrendDataPoint(
                id: "\(panel.labDate.timeIntervalSince1970)-\(name)",
                date: panel.labDate,
                value: marker.value,
                unit: marker.unit
            )
        }
    }

    private func trendArrow(_ percentChange: Double) -> String {
        if abs(percentChange) < 3 { return "arrow.right" }
        return percentChange > 0 ? "arrow.up.right" : "arrow.down.right"
    }

    private func trendColor(_ percentChange: Double) -> Color {
        if abs(percentChange) < 3 { return .textSecondary }
        return percentChange > 0 ? .recoveryGreen : .recoveryRed
    }

    private func formatValue(_ value: Double) -> String {
        if value == value.rounded() && abs(value) < 10_000 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }
}

// MARK: - Data Point

private struct TrendDataPoint: Identifiable {
    let id: String
    let date: Date
    let value: Double
    let unit: String
}

// MARK: - Preview

#Preview {
    BiomarkerTrendsView()
        .modelContainer(for: BloodworkPanel.self, inMemory: true)
}
