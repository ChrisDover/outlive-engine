// NewExperimentView.swift
// OutliveEngine
//
// Form to create a new N-of-1 experiment with title, hypothesis, metrics, and duration.

import SwiftUI
import SwiftData

struct NewExperimentView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var hypothesis = ""
    @State private var selectedMetrics: Set<String> = []
    @State private var durationDays: Int = 14

    private let commonMetrics = [
        "HRV", "Resting Heart Rate", "Sleep Hours", "Deep Sleep",
        "REM Sleep", "Recovery Score", "Body Weight", "Body Fat %",
        "Energy Level", "Mood", "Soreness", "Grip Strength",
        "VO2 Estimate", "Steps", "Active Calories", "Blood Pressure",
        "Fasting Glucose", "Subjective Wellbeing"
    ]

    private let durationOptions = [7, 14, 21, 28, 42, 60, 90]

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
        && !hypothesis.trimmingCharacters(in: .whitespaces).isEmpty
        && !selectedMetrics.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                detailsSection
                metricsSection
                durationSection
            }
            .navigationTitle("New Experiment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { createExperiment() }
                        .disabled(!isValid)
                }
            }
            .background(Color.surfaceBackground)
        }
    }

    // MARK: - Sections

    private var detailsSection: some View {
        Section {
            TextField("Experiment Title", text: $title)

            VStack(alignment: .leading, spacing: OutliveSpacing.xxs) {
                Text("Hypothesis")
                    .font(.outliveCaption)
                    .foregroundStyle(Color.textSecondary)

                TextEditor(text: $hypothesis)
                    .frame(minHeight: 80)
                    .font(.outliveBody)
            }
        } header: {
            Text("Details")
        } footer: {
            Text("State what you expect to observe. Example: \"Taking creatine 5g daily will improve my grip strength within 4 weeks.\"")
        }
    }

    private var metricsSection: some View {
        Section {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: OutliveSpacing.xs) {
                ForEach(commonMetrics, id: \.self) { metric in
                    metricChip(metric)
                }
            }
        } header: {
            Text("Tracked Metrics (\(selectedMetrics.count) selected)")
        } footer: {
            Text("Select the metrics you will measure during baseline and testing phases.")
        }
    }

    private func metricChip(_ metric: String) -> some View {
        let isSelected = selectedMetrics.contains(metric)

        return Button {
            if isSelected {
                selectedMetrics.remove(metric)
            } else {
                selectedMetrics.insert(metric)
            }
        } label: {
            Text(metric)
                .font(.outliveCaption)
                .foregroundStyle(isSelected ? .white : Color.textPrimary)
                .padding(.horizontal, OutliveSpacing.xs)
                .padding(.vertical, OutliveSpacing.xs)
                .frame(maxWidth: .infinity)
                .background(isSelected ? Color.domainTraining : Color.surfaceCard)
                .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.small, style: .continuous))
                .overlay {
                    if !isSelected {
                        RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.small, style: .continuous)
                            .strokeBorder(Color.textTertiary.opacity(0.3), lineWidth: 1)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private var durationSection: some View {
        Section {
            Picker("Duration", selection: $durationDays) {
                ForEach(durationOptions, id: \.self) { days in
                    Text("\(days) days").tag(days)
                }
            }
            .pickerStyle(.segmented)
        } header: {
            Text("Duration")
        } footer: {
            Text("Baseline phase will be the first half, testing phase the second half. Total: \(durationDays) days.")
        }
    }

    // MARK: - Actions

    private func createExperiment() {
        let endDate = Calendar.current.date(byAdding: .day, value: durationDays, to: Date()) ?? Date()
        let experiment = Experiment(
            userId: "",
            title: title.trimmingCharacters(in: .whitespaces),
            hypothesis: hypothesis.trimmingCharacters(in: .whitespaces),
            trackedMetrics: Array(selectedMetrics).sorted(),
            startDate: Date(),
            endDate: endDate,
            status: .designing
        )
        modelContext.insert(experiment)
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    NewExperimentView()
        .modelContainer(for: Experiment.self, inMemory: true)
}
