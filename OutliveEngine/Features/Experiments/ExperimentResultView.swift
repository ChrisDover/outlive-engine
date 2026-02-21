// ExperimentResultView.swift
// OutliveEngine
//
// Shows completed experiment results with baseline vs test comparison.

import SwiftUI

struct ExperimentResultView: View {

    let experiment: Experiment

    var body: some View {
        ScrollView {
            VStack(spacing: OutliveSpacing.lg) {
                summarySection
                hypothesisSection
                metricComparisonSection
                resultTextSection
            }
            .padding(.horizontal, OutliveSpacing.md)
            .padding(.bottom, OutliveSpacing.xl)
        }
        .background(Color.surfaceBackground)
        .navigationTitle("Results")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Summary

    private var summarySection: some View {
        VStack(spacing: OutliveSpacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: OutliveSpacing.xxs) {
                    Text(experiment.title)
                        .font(.outliveTitle3)
                        .foregroundStyle(Color.textPrimary)

                    HStack(spacing: OutliveSpacing.xs) {
                        Text("Completed")
                            .font(.outliveCaption)
                            .foregroundStyle(Color.recoveryGreen)
                            .padding(.horizontal, OutliveSpacing.xs)
                            .padding(.vertical, 2)
                            .background(Color.recoveryGreen.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.small, style: .continuous))

                        Text(durationText)
                            .font(.outliveCaption)
                            .foregroundStyle(Color.textTertiary)
                    }
                }

                Spacer()
            }

            HStack(spacing: OutliveSpacing.lg) {
                VStack(spacing: OutliveSpacing.xxs) {
                    Text("\(experiment.baselineSnapshots.count)")
                        .font(.outliveMonoData)
                        .foregroundStyle(Color.textPrimary)
                    Text("Baseline")
                        .font(.outliveCaption)
                        .foregroundStyle(Color.textSecondary)
                }

                VStack(spacing: OutliveSpacing.xxs) {
                    Text("\(experiment.testSnapshots.count)")
                        .font(.outliveMonoData)
                        .foregroundStyle(Color.textPrimary)
                    Text("Test")
                        .font(.outliveCaption)
                        .foregroundStyle(Color.textSecondary)
                }

                VStack(spacing: OutliveSpacing.xxs) {
                    Text("\(experiment.trackedMetrics.count)")
                        .font(.outliveMonoData)
                        .foregroundStyle(Color.textPrimary)
                    Text("Metrics")
                        .font(.outliveCaption)
                        .foregroundStyle(Color.textSecondary)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(OutliveSpacing.md)
        .background(Color.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.medium, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
    }

    // MARK: - Hypothesis

    private var hypothesisSection: some View {
        VStack(alignment: .leading, spacing: OutliveSpacing.xs) {
            Text("Hypothesis")
                .font(.outliveCaption)
                .foregroundStyle(Color.textSecondary)

            Text(experiment.hypothesis)
                .font(.outliveBody)
                .foregroundStyle(Color.textPrimary)
        }
        .padding(OutliveSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.medium, style: .continuous))
    }

    // MARK: - Metric Comparison

    private var metricComparisonSection: some View {
        VStack(spacing: OutliveSpacing.sm) {
            SectionHeader(title: "Metric-by-Metric Comparison")

            ForEach(experiment.trackedMetrics, id: \.self) { metric in
                MetricComparisonRow(
                    metric: metric,
                    baselineSnapshots: experiment.baselineSnapshots,
                    testSnapshots: experiment.testSnapshots
                )
            }
        }
    }

    // MARK: - Result Text

    @ViewBuilder
    private var resultTextSection: some View {
        if let result = experiment.result, !result.isEmpty {
            VStack(alignment: .leading, spacing: OutliveSpacing.xs) {
                SectionHeader(title: "Conclusion")

                Text(result)
                    .font(.outliveBody)
                    .foregroundStyle(Color.textPrimary)
                    .padding(OutliveSpacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.surfaceCard)
                    .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.medium, style: .continuous))
            }
        }
    }

    // MARK: - Helpers

    private var durationText: String {
        guard let endDate = experiment.endDate else { return "" }
        let days = Calendar.current.dateComponents([.day], from: experiment.startDate, to: endDate).day ?? 0
        return "\(days) days"
    }
}

// MARK: - Metric Comparison Row

private struct MetricComparisonRow: View {

    let metric: String
    let baselineSnapshots: [ExperimentSnapshot]
    let testSnapshots: [ExperimentSnapshot]

    private var baselineAvg: Double? {
        let values = baselineSnapshots.compactMap { $0.metrics[metric] }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private var testAvg: Double? {
        let values = testSnapshots.compactMap { $0.metrics[metric] }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private var percentChange: Double? {
        guard let baseline = baselineAvg, let test = testAvg, baseline != 0 else { return nil }
        return ((test - baseline) / baseline) * 100
    }

    var body: some View {
        HStack(spacing: OutliveSpacing.sm) {
            changeIndicator

            VStack(alignment: .leading, spacing: OutliveSpacing.xxs) {
                Text(metric)
                    .font(.outliveHeadline)
                    .foregroundStyle(Color.textPrimary)

                HStack(spacing: OutliveSpacing.md) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Baseline")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.textTertiary)
                        Text(baselineAvg.map { formatValue($0) } ?? "--")
                            .font(.outliveMonoSmall)
                            .foregroundStyle(Color.textSecondary)
                    }

                    Image(systemName: "arrow.right")
                        .font(.outliveCaption)
                        .foregroundStyle(Color.textTertiary)

                    VStack(alignment: .leading, spacing: 0) {
                        Text("Test")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.textTertiary)
                        Text(testAvg.map { formatValue($0) } ?? "--")
                            .font(.outliveMonoSmall)
                            .foregroundStyle(Color.textPrimary)
                    }
                }
            }

            Spacer()

            if let pct = percentChange {
                VStack(alignment: .trailing, spacing: 0) {
                    Text(changeLabel)
                        .font(.system(size: 10))
                        .foregroundStyle(Color.textTertiary)

                    HStack(spacing: 2) {
                        Image(systemName: changeArrow)
                            .font(.system(size: 10))
                        Text("\(formatValue(abs(pct)))%")
                            .font(.outliveMonoSmall)
                    }
                    .foregroundStyle(changeColor)
                }
            }
        }
        .padding(OutliveSpacing.md)
        .background(Color.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.medium, style: .continuous))
    }

    private var changeIndicator: some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(changeColor)
            .frame(width: 4, height: 44)
    }

    private var changeColor: Color {
        guard let pct = percentChange else { return .textTertiary }
        if abs(pct) < 3 { return .textSecondary }
        return pct > 0 ? .recoveryGreen : .recoveryRed
    }

    private var changeArrow: String {
        guard let pct = percentChange else { return "minus" }
        if abs(pct) < 3 { return "minus" }
        return pct > 0 ? "arrow.up.right" : "arrow.down.right"
    }

    private var changeLabel: String {
        guard let pct = percentChange else { return "N/A" }
        if abs(pct) < 3 { return "No Change" }
        return pct > 0 ? "Improved" : "Declined"
    }

    private func formatValue(_ value: Double) -> String {
        if value == value.rounded() && abs(value) < 10_000 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ExperimentResultView(
            experiment: Experiment(
                userId: "preview",
                title: "Creatine Loading Test",
                hypothesis: "5g creatine daily will improve grip strength by 10% within 28 days.",
                trackedMetrics: ["Grip Strength", "Body Weight", "Recovery Score"],
                baselineSnapshots: [
                    ExperimentSnapshot(date: Date(), metrics: ["Grip Strength": 45, "Body Weight": 82, "Recovery Score": 72])
                ],
                testSnapshots: [
                    ExperimentSnapshot(date: Date(), metrics: ["Grip Strength": 50, "Body Weight": 83, "Recovery Score": 75])
                ],
                startDate: Calendar.current.date(byAdding: .day, value: -28, to: Date())!,
                endDate: Date(),
                status: .completed,
                result: "Grip strength improved by approximately 11%, exceeding the hypothesized 10%. Body weight increased modestly, consistent with creatine water retention."
            )
        )
    }
}
