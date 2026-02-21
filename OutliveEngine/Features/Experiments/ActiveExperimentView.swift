// ActiveExperimentView.swift
// OutliveEngine
//
// Shows an active experiment's progress with baseline vs test comparison and snapshot entry.

import SwiftUI
import SwiftData

struct ActiveExperimentView: View {

    @Bindable var experiment: Experiment
    @Environment(\.modelContext) private var modelContext
    @State private var showingAddSnapshot = false

    private var totalDays: Int {
        guard let endDate = experiment.endDate else { return 0 }
        return max(1, Calendar.current.dateComponents([.day], from: experiment.startDate, to: endDate).day ?? 1)
    }

    private var elapsedDays: Int {
        let days = Calendar.current.dateComponents([.day], from: experiment.startDate, to: Date()).day ?? 0
        return min(max(days, 0), totalDays)
    }

    private var progress: Double {
        totalDays > 0 ? Double(elapsedDays) / Double(totalDays) : 0
    }

    var body: some View {
        ScrollView {
            VStack(spacing: OutliveSpacing.lg) {
                progressSection
                hypothesisSection
                phaseIndicator
                dataComparisonSection
                snapshotHistorySection
            }
            .padding(.horizontal, OutliveSpacing.md)
            .padding(.bottom, OutliveSpacing.xl)
        }
        .background(Color.surfaceBackground)
        .navigationTitle(experiment.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddSnapshot = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.outliveTitle3)
                        .foregroundStyle(Color.domainTraining)
                }
            }
        }
        .sheet(isPresented: $showingAddSnapshot) {
            AddSnapshotSheet(
                metrics: experiment.trackedMetrics,
                phase: currentPhase,
                onSave: addSnapshot
            )
        }
    }

    // MARK: - Progress

    private var progressSection: some View {
        VStack(spacing: OutliveSpacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: OutliveSpacing.xxs) {
                    Text("Day \(elapsedDays) of \(totalDays)")
                        .font(.outliveTitle3)
                        .foregroundStyle(Color.textPrimary)

                    Text(experiment.status.rawValue.capitalized)
                        .font(.outliveCaption)
                        .foregroundStyle(Color.recoveryGreen)
                }

                Spacer()

                MetricRing(value: progress, label: "Progress", color: .domainTraining)
                    .frame(width: 70, height: 88)
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.textTertiary.opacity(0.2))

                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.domainTraining)
                        .frame(width: geometry.size.width * progress)

                    // Midpoint marker (baseline/test boundary)
                    Rectangle()
                        .fill(Color.textSecondary)
                        .frame(width: 2)
                        .offset(x: geometry.size.width * 0.5 - 1)
                }
            }
            .frame(height: 8)

            HStack {
                Text("Baseline")
                    .font(.outliveCaption)
                    .foregroundStyle(Color.textTertiary)

                Spacer()

                Text("Testing")
                    .font(.outliveCaption)
                    .foregroundStyle(Color.textTertiary)
            }
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

    // MARK: - Phase Indicator

    private var phaseIndicator: some View {
        HStack(spacing: OutliveSpacing.sm) {
            phaseBlock(title: "Baseline", snapshots: experiment.baselineSnapshots.count, isActive: currentPhase == .baseline)
            phaseBlock(title: "Testing", snapshots: experiment.testSnapshots.count, isActive: currentPhase == .testing)
        }
    }

    private func phaseBlock(title: String, snapshots: Int, isActive: Bool) -> some View {
        VStack(spacing: OutliveSpacing.xxs) {
            Text(title)
                .font(.outliveHeadline)
                .foregroundStyle(isActive ? Color.textPrimary : Color.textTertiary)

            Text("\(snapshots) snapshots")
                .font(.outliveCaption)
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(OutliveSpacing.md)
        .background(isActive ? Color.domainTraining.opacity(0.08) : Color.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.medium, style: .continuous))
        .overlay {
            if isActive {
                RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.medium, style: .continuous)
                    .strokeBorder(Color.domainTraining.opacity(0.3), lineWidth: 1)
            }
        }
    }

    // MARK: - Data Comparison

    private var dataComparisonSection: some View {
        VStack(spacing: OutliveSpacing.sm) {
            SectionHeader(title: "Metric Comparison")

            ForEach(experiment.trackedMetrics, id: \.self) { metric in
                let baselineAvg = averageFor(metric, in: experiment.baselineSnapshots)
                let testAvg = averageFor(metric, in: experiment.testSnapshots)

                HStack {
                    Text(metric)
                        .font(.outliveSubheadline)
                        .foregroundStyle(Color.textPrimary)

                    Spacer()

                    VStack(alignment: .trailing, spacing: 0) {
                        Text(baselineAvg.map { formatValue($0) } ?? "--")
                            .font(.outliveMonoSmall)
                            .foregroundStyle(Color.textSecondary)

                        Text("baseline")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.textTertiary)
                    }
                    .frame(width: 60)

                    VStack(alignment: .trailing, spacing: 0) {
                        Text(testAvg.map { formatValue($0) } ?? "--")
                            .font(.outliveMonoSmall)
                            .foregroundStyle(Color.textPrimary)

                        Text("test")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.textTertiary)
                    }
                    .frame(width: 60)
                }
                .padding(.horizontal, OutliveSpacing.md)
                .padding(.vertical, OutliveSpacing.xs)
            }
            .background(Color.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.medium, style: .continuous))
        }
    }

    // MARK: - Snapshot History

    private var snapshotHistorySection: some View {
        VStack(spacing: OutliveSpacing.sm) {
            SectionHeader(title: "Recent Snapshots")

            let allSnapshots = (experiment.baselineSnapshots + experiment.testSnapshots)
                .sorted { $0.date > $1.date }
                .prefix(10)

            if allSnapshots.isEmpty {
                Text("No snapshots recorded yet. Tap + to add your first measurement.")
                    .font(.outliveBody)
                    .foregroundStyle(Color.textSecondary)
                    .padding(OutliveSpacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.surfaceCard)
                    .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.medium, style: .continuous))
            } else {
                ForEach(Array(allSnapshots), id: \.date) { snapshot in
                    HStack {
                        Text(snapshot.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.outliveCaption)
                            .foregroundStyle(Color.textSecondary)

                        Spacer()

                        Text("\(snapshot.metrics.count) metrics")
                            .font(.outliveCaption)
                            .foregroundStyle(Color.textTertiary)
                    }
                    .padding(.horizontal, OutliveSpacing.md)
                    .padding(.vertical, OutliveSpacing.xs)
                }
                .background(Color.surfaceCard)
                .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.medium, style: .continuous))
            }
        }
    }

    // MARK: - Helpers

    private var currentPhase: ExperimentPhase {
        progress < 0.5 ? .baseline : .testing
    }

    private func averageFor(_ metric: String, in snapshots: [ExperimentSnapshot]) -> Double? {
        let values = snapshots.compactMap { $0.metrics[metric] }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private func formatValue(_ value: Double) -> String {
        if value == value.rounded() && abs(value) < 10_000 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }

    private func addSnapshot(_ metrics: [String: Double]) {
        let snapshot = ExperimentSnapshot(date: Date(), metrics: metrics)
        if currentPhase == .baseline {
            var snapshots = experiment.baselineSnapshots
            snapshots.append(snapshot)
            experiment.baselineSnapshots = snapshots
        } else {
            var snapshots = experiment.testSnapshots
            snapshots.append(snapshot)
            experiment.testSnapshots = snapshots
        }
    }
}

// MARK: - Add Snapshot Sheet

private struct AddSnapshotSheet: View {

    let metrics: [String]
    let phase: ExperimentPhase
    let onSave: ([String: Double]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var values: [String: String] = [:]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(phase == .baseline ? "Baseline Phase" : "Testing Phase")
                        .font(.outliveHeadline)
                        .foregroundStyle(Color.domainTraining)
                }

                Section("Metric Values") {
                    ForEach(metrics, id: \.self) { metric in
                        HStack {
                            Text(metric)
                                .font(.outliveSubheadline)

                            Spacer()

                            TextField("Value", text: Binding(
                                get: { values[metric, default: ""] },
                                set: { values[metric] = $0 }
                            ))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                        }
                    }
                }
            }
            .navigationTitle("Add Snapshot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var metricValues: [String: Double] = [:]
                        for (key, value) in values {
                            if let doubleValue = Double(value) {
                                metricValues[key] = doubleValue
                            }
                        }
                        onSave(metricValues)
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Experiment Phase

enum ExperimentPhase {
    case baseline, testing
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ActiveExperimentView(
            experiment: Experiment(
                userId: "preview",
                title: "Creatine Loading Test",
                hypothesis: "5g creatine daily will improve grip strength by 10% within 28 days.",
                trackedMetrics: ["Grip Strength", "Body Weight", "Recovery Score"],
                startDate: Calendar.current.date(byAdding: .day, value: -7, to: Date())!,
                endDate: Calendar.current.date(byAdding: .day, value: 21, to: Date()),
                status: .baseline
            )
        )
    }
}
