// WeeklyReportView.swift
// OutliveEngine
//
// Weekly adherence summary with recovery distribution and key insights.

import SwiftUI
import SwiftData

struct WeeklyReportView: View {

    @Query(sort: \DailyProtocol.date, order: .reverse)
    private var protocols: [DailyProtocol]

    @Query(sort: \DailyWearableData.date, order: .reverse)
    private var wearableData: [DailyWearableData]

    private var weekProtocols: [DailyProtocol] {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return protocols.filter { $0.date >= weekAgo }
    }

    private var weekWearables: [DailyWearableData] {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return wearableData.filter { $0.date >= weekAgo }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: OutliveSpacing.lg) {
                    adherenceSummary
                    recoveryDistribution
                    keyMetrics
                    weeklyInsights
                }
                .padding(.horizontal, OutliveSpacing.md)
                .padding(.bottom, OutliveSpacing.xl)
            }
            .navigationTitle("Weekly Report")
            .background(Color.surfaceBackground)
        }
    }

    // MARK: - Adherence Summary

    private var adherenceSummary: some View {
        let scores = weekProtocols.compactMap(\.adherenceScore)
        let avgAdherence = scores.isEmpty ? 0.0 : scores.reduce(0, +) / Double(scores.count)

        return VStack(spacing: OutliveSpacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: OutliveSpacing.xxs) {
                    Text("Protocol Adherence")
                        .font(.outliveTitle3)
                        .foregroundStyle(Color.textPrimary)

                    Text("Last 7 days")
                        .font(.outliveCaption)
                        .foregroundStyle(Color.textSecondary)
                }

                Spacer()

                MetricRing(value: avgAdherence / 100.0, label: "Adherence", color: adherenceColor(avgAdherence))
                    .frame(width: 80, height: 100)
            }

            HStack(spacing: OutliveSpacing.md) {
                adherenceStat(title: "Days Tracked", value: "\(weekProtocols.count)", subtitle: "of 7")
                adherenceStat(title: "Average", value: String(format: "%.0f%%", avgAdherence), subtitle: "score")
                adherenceStat(title: "Best Day", value: String(format: "%.0f%%", scores.max() ?? 0), subtitle: "peak")
            }
        }
        .padding(OutliveSpacing.md)
        .background(Color.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.medium, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
    }

    private func adherenceStat(title: String, value: String, subtitle: String) -> some View {
        VStack(spacing: OutliveSpacing.xxs) {
            Text(value)
                .font(.outliveMonoData)
                .foregroundStyle(Color.textPrimary)
            Text(title)
                .font(.outliveCaption)
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Recovery Distribution

    private var recoveryDistribution: some View {
        let zones = weekProtocols.map(\.recoveryZone)
        let greenCount = zones.filter { $0 == .green }.count
        let yellowCount = zones.filter { $0 == .yellow }.count
        let redCount = zones.filter { $0 == .red }.count
        let total = max(zones.count, 1)

        return VStack(spacing: OutliveSpacing.sm) {
            SectionHeader(title: "Recovery Zones")

            // Bar chart
            HStack(spacing: OutliveSpacing.xs) {
                recoveryBar(label: "Green", count: greenCount, total: total, color: .recoveryGreen)
                recoveryBar(label: "Yellow", count: yellowCount, total: total, color: .recoveryYellow)
                recoveryBar(label: "Red", count: redCount, total: total, color: .recoveryRed)
            }
            .frame(height: 120)
            .padding(OutliveSpacing.md)
            .background(Color.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.medium, style: .continuous))
        }
    }

    private func recoveryBar(label: String, count: Int, total: Int, color: Color) -> some View {
        VStack(spacing: OutliveSpacing.xxs) {
            Spacer()

            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(color)
                .frame(height: max(CGFloat(count) / CGFloat(total) * 80, 4))

            Text("\(count)")
                .font(.outliveMonoSmall)
                .foregroundStyle(Color.textPrimary)

            Text(label)
                .font(.outliveCaption)
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Key Metrics

    private var keyMetrics: some View {
        VStack(spacing: OutliveSpacing.sm) {
            SectionHeader(title: "Key Metrics")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: OutliveSpacing.sm) {
                weekMetricCard(
                    title: "Avg HRV",
                    value: avgValue(weekWearables.compactMap(\.hrvMs)),
                    unit: "ms",
                    icon: "waveform.path.ecg"
                )
                weekMetricCard(
                    title: "Avg RHR",
                    value: avgValue(weekWearables.compactMap(\.restingHR).map(Double.init)),
                    unit: "bpm",
                    icon: "heart.fill"
                )
                weekMetricCard(
                    title: "Avg Sleep",
                    value: avgValue(weekWearables.compactMap(\.sleepHours)),
                    unit: "hrs",
                    icon: "bed.double.fill"
                )
                weekMetricCard(
                    title: "Avg Steps",
                    value: avgValue(weekWearables.compactMap(\.steps).map(Double.init)),
                    unit: "",
                    icon: "figure.walk"
                )
            }
        }
    }

    private func weekMetricCard(title: String, value: String, unit: String, icon: String) -> some View {
        VStack(spacing: OutliveSpacing.xs) {
            Image(systemName: icon)
                .font(.outliveTitle3)
                .foregroundStyle(Color.domainTraining)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.outliveMonoData)
                    .foregroundStyle(Color.textPrimary)

                if !unit.isEmpty {
                    Text(unit)
                        .font(.outliveMonoSmall)
                        .foregroundStyle(Color.textTertiary)
                }
            }

            Text(title)
                .font(.outliveCaption)
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(OutliveSpacing.md)
        .background(Color.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.medium, style: .continuous))
    }

    // MARK: - Weekly Insights

    private var weeklyInsights: some View {
        VStack(spacing: OutliveSpacing.sm) {
            SectionHeader(title: "Insights")

            if weekProtocols.isEmpty {
                Text("No protocol data this week. Start tracking to receive weekly insights.")
                    .font(.outliveBody)
                    .foregroundStyle(Color.textSecondary)
                    .padding(OutliveSpacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.surfaceCard)
                    .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.medium, style: .continuous))
            } else {
                ForEach(generateInsights(), id: \.self) { insight in
                    HStack(alignment: .top, spacing: OutliveSpacing.xs) {
                        Image(systemName: "lightbulb.fill")
                            .font(.outliveFootnote)
                            .foregroundStyle(Color.domainNutrition)
                            .padding(.top, 2)

                        Text(insight)
                            .font(.outliveBody)
                            .foregroundStyle(Color.textPrimary)
                    }
                    .padding(OutliveSpacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.surfaceCard)
                    .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.medium, style: .continuous))
                }
            }
        }
    }

    // MARK: - Helpers

    private func adherenceColor(_ score: Double) -> Color {
        switch score {
        case 80...: return .recoveryGreen
        case 50...: return .recoveryYellow
        default:    return .recoveryRed
        }
    }

    private func avgValue(_ values: [Double]) -> String {
        guard !values.isEmpty else { return "--" }
        let avg = values.reduce(0, +) / Double(values.count)
        if avg >= 100 {
            return String(format: "%.0f", avg)
        }
        return String(format: "%.1f", avg)
    }

    private func generateInsights() -> [String] {
        var insights: [String] = []

        let scores = weekProtocols.compactMap(\.adherenceScore)
        let avg = scores.isEmpty ? 0 : scores.reduce(0, +) / Double(scores.count)

        if avg >= 80 {
            insights.append("Strong adherence this week. Consistency is your greatest longevity lever.")
        } else if avg >= 50 {
            insights.append("Moderate adherence. Focus on completing your highest-priority protocols first.")
        } else {
            insights.append("Low adherence this week. Consider simplifying your protocol to improve consistency.")
        }

        let redDays = weekProtocols.filter { $0.recoveryZone == .red }.count
        if redDays >= 3 {
            insights.append("Multiple red recovery days detected. Prioritize sleep quality and reduce training volume.")
        }

        let avgSleep = weekWearables.compactMap(\.sleepHours)
        if !avgSleep.isEmpty {
            let sleepAvg = avgSleep.reduce(0, +) / Double(avgSleep.count)
            if sleepAvg < 7 {
                insights.append("Average sleep below 7 hours. Sleep is foundational — aim for 7-9 hours consistently.")
            }
        }

        return insights
    }
}

// MARK: - Preview

#Preview {
    WeeklyReportView()
        .modelContainer(for: [DailyProtocol.self, DailyWearableData.self], inMemory: true)
}
