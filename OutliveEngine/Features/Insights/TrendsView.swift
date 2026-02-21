// TrendsView.swift
// OutliveEngine
//
// Multi-metric trend view with selectable metrics and time range picker.

import SwiftUI
import SwiftData

struct TrendsView: View {

    @Query(sort: \DailyWearableData.date, order: .forward)
    private var allWearableData: [DailyWearableData]

    @State private var selectedMetric: TrendMetric = .hrv
    @State private var timeRange: TimeRange = .thirtyDays

    private var filteredData: [DailyWearableData] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -timeRange.days, to: Date()) ?? Date()
        return allWearableData.filter { $0.date >= cutoff }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: OutliveSpacing.lg) {
                    metricPicker
                    timeRangePicker
                    chartSection
                    statisticsSection
                }
                .padding(.horizontal, OutliveSpacing.md)
                .padding(.bottom, OutliveSpacing.xl)
            }
            .navigationTitle("Trends")
            .background(Color.surfaceBackground)
        }
    }

    // MARK: - Metric Picker

    private var metricPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: OutliveSpacing.xs) {
                ForEach(TrendMetric.allCases, id: \.self) { metric in
                    Button {
                        withAnimation { selectedMetric = metric }
                    } label: {
                        HStack(spacing: OutliveSpacing.xxs) {
                            Image(systemName: metric.icon)
                                .font(.outliveCaption)

                            Text(metric.title)
                                .font(.outliveSubheadline)
                        }
                        .foregroundStyle(selectedMetric == metric ? .white : Color.textPrimary)
                        .padding(.horizontal, OutliveSpacing.sm)
                        .padding(.vertical, OutliveSpacing.xs)
                        .background(selectedMetric == metric ? Color.domainTraining : Color.surfaceCard)
                        .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.small, style: .continuous))
                    }
                }
            }
        }
    }

    // MARK: - Time Range

    private var timeRangePicker: some View {
        Picker("Time Range", selection: $timeRange) {
            ForEach(TimeRange.allCases, id: \.self) { range in
                Text(range.label).tag(range)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Chart

    private var chartSection: some View {
        let values = filteredData.compactMap { extractValue(from: $0, metric: selectedMetric) }

        return VStack(spacing: OutliveSpacing.sm) {
            SectionHeader(title: selectedMetric.title)

            if values.count >= 2 {
                GeometryReader { geometry in
                    let width = geometry.size.width
                    let height = geometry.size.height
                    let minVal = (values.min() ?? 0) * 0.9
                    let maxVal = (values.max() ?? 1) * 1.1
                    let range = maxVal - minVal

                    ZStack {
                        // Grid
                        ForEach(0..<4) { i in
                            let y = height * CGFloat(i) / 3.0
                            Path { path in
                                path.move(to: CGPoint(x: 0, y: y))
                                path.addLine(to: CGPoint(x: width, y: y))
                            }
                            .stroke(Color.textTertiary.opacity(0.2), lineWidth: 0.5)
                        }

                        // Gradient fill
                        Path { path in
                            for (index, value) in values.enumerated() {
                                let x = width * CGFloat(index) / CGFloat(values.count - 1)
                                let y = range > 0
                                    ? height * (1 - CGFloat((value - minVal) / range))
                                    : height / 2

                                if index == 0 {
                                    path.move(to: CGPoint(x: x, y: y))
                                } else {
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                            }
                            path.addLine(to: CGPoint(x: width, y: height))
                            path.addLine(to: CGPoint(x: 0, y: height))
                            path.closeSubpath()
                        }
                        .fill(
                            LinearGradient(
                                colors: [selectedMetric.color.opacity(0.3), selectedMetric.color.opacity(0.0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                        // Line
                        Path { path in
                            for (index, value) in values.enumerated() {
                                let x = width * CGFloat(index) / CGFloat(values.count - 1)
                                let y = range > 0
                                    ? height * (1 - CGFloat((value - minVal) / range))
                                    : height / 2

                                if index == 0 {
                                    path.move(to: CGPoint(x: x, y: y))
                                } else {
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                            }
                        }
                        .stroke(selectedMetric.color, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                        // Range labels
                        VStack {
                            HStack {
                                Text(formatValue(maxVal))
                                    .font(.outliveMonoSmall)
                                    .foregroundStyle(Color.textTertiary)
                                Spacer()
                            }
                            Spacer()
                            HStack {
                                Text(formatValue(minVal))
                                    .font(.outliveMonoSmall)
                                    .foregroundStyle(Color.textTertiary)
                                Spacer()
                            }
                        }
                    }
                }
                .frame(height: 200)
                .padding(OutliveSpacing.md)
                .background(Color.surfaceCard)
                .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.medium, style: .continuous))
            } else {
                Text("Not enough data for the selected time range. Keep tracking to see trends.")
                    .font(.outliveBody)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(OutliveSpacing.lg)
                    .frame(maxWidth: .infinity)
                    .background(Color.surfaceCard)
                    .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.medium, style: .continuous))
            }
        }
    }

    // MARK: - Statistics

    private var statisticsSection: some View {
        let values = filteredData.compactMap { extractValue(from: $0, metric: selectedMetric) }

        return VStack(spacing: OutliveSpacing.sm) {
            SectionHeader(title: "Statistics")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: OutliveSpacing.sm) {
                statCard(title: "Average", value: values.isEmpty ? "--" : formatValue(values.reduce(0, +) / Double(values.count)))
                statCard(title: "Min", value: values.min().map { formatValue($0) } ?? "--")
                statCard(title: "Max", value: values.max().map { formatValue($0) } ?? "--")
            }
        }
    }

    private func statCard(title: String, value: String) -> some View {
        VStack(spacing: OutliveSpacing.xxs) {
            Text(value)
                .font(.outliveMonoData)
                .foregroundStyle(Color.textPrimary)
            Text(title)
                .font(.outliveCaption)
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(OutliveSpacing.md)
        .background(Color.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.medium, style: .continuous))
    }

    // MARK: - Helpers

    private func extractValue(from data: DailyWearableData, metric: TrendMetric) -> Double? {
        switch metric {
        case .hrv:        return data.hrvMs
        case .rhr:        return data.restingHR.map(Double.init)
        case .sleep:      return data.sleepHours
        case .deepSleep:  return data.deepSleepMinutes.map(Double.init)
        case .recovery:   return data.recoveryScore
        case .steps:      return data.steps.map(Double.init)
        case .strain:     return data.strain
        }
    }

    private func formatValue(_ value: Double) -> String {
        if value >= 100 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }
}

// MARK: - Trend Metric

private enum TrendMetric: String, CaseIterable {
    case hrv, rhr, sleep, deepSleep, recovery, steps, strain

    var title: String {
        switch self {
        case .hrv:       return "HRV"
        case .rhr:       return "RHR"
        case .sleep:     return "Sleep"
        case .deepSleep: return "Deep Sleep"
        case .recovery:  return "Recovery"
        case .steps:     return "Steps"
        case .strain:    return "Strain"
        }
    }

    var icon: String {
        switch self {
        case .hrv:       return "waveform.path.ecg"
        case .rhr:       return "heart.fill"
        case .sleep:     return "bed.double.fill"
        case .deepSleep: return "moon.zzz.fill"
        case .recovery:  return "arrow.counterclockwise.heart"
        case .steps:     return "figure.walk"
        case .strain:    return "flame.fill"
        }
    }

    var color: Color {
        switch self {
        case .hrv:       return .domainTraining
        case .rhr:       return .recoveryRed
        case .sleep:     return .domainSleep
        case .deepSleep: return .domainSleep
        case .recovery:  return .recoveryGreen
        case .steps:     return .domainNutrition
        case .strain:    return .domainInterventions
        }
    }
}

// MARK: - Time Range

private enum TimeRange: String, CaseIterable {
    case sevenDays
    case thirtyDays
    case ninetyDays

    var days: Int {
        switch self {
        case .sevenDays:  return 7
        case .thirtyDays: return 30
        case .ninetyDays: return 90
        }
    }

    var label: String {
        switch self {
        case .sevenDays:  return "7d"
        case .thirtyDays: return "30d"
        case .ninetyDays: return "90d"
        }
    }
}

// MARK: - Preview

#Preview {
    TrendsView()
        .modelContainer(for: DailyWearableData.self, inMemory: true)
}
