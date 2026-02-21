// BodyCompositionView.swift
// OutliveEngine
//
// Latest body composition data with trend chart and input form.

import SwiftUI
import SwiftData

struct BodyCompositionView: View {

    @Query(sort: \BodyComposition.date, order: .reverse)
    private var measurements: [BodyComposition]

    @Environment(\.modelContext) private var modelContext
    @State private var showingAddForm = false

    private var latest: BodyComposition? { measurements.first }

    var body: some View {
        NavigationStack {
            Group {
                if measurements.isEmpty {
                    EmptyStateView(
                        icon: "figure.stand",
                        title: "No Body Composition Data",
                        message: "Track your weight, body fat, muscle mass, and visceral fat over time.",
                        actionTitle: "Add Measurement"
                    ) {
                        showingAddForm = true
                    }
                } else {
                    compositionContent
                }
            }
            .navigationTitle("Body Composition")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddForm = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.outliveHeadline)
                    }
                }
            }
            .sheet(isPresented: $showingAddForm) {
                AddMeasurementSheet(onSave: saveMeasurement)
            }
            .background(Color.surfaceBackground)
        }
    }

    // MARK: - Content

    private var compositionContent: some View {
        ScrollView {
            VStack(spacing: OutliveSpacing.lg) {
                if let latest {
                    latestMetrics(latest)
                }
                weightTrendChart
                measurementHistory
            }
            .padding(.horizontal, OutliveSpacing.md)
            .padding(.bottom, OutliveSpacing.xl)
        }
    }

    // MARK: - Latest Metrics

    private func latestMetrics(_ entry: BodyComposition) -> some View {
        VStack(spacing: OutliveSpacing.sm) {
            HStack {
                Text("Latest")
                    .font(.outliveTitle3)
                    .foregroundStyle(Color.textPrimary)

                Spacer()

                HStack(spacing: OutliveSpacing.xxs) {
                    Text(entry.source.rawValue.capitalized)
                        .font(.outliveCaption)
                        .foregroundStyle(Color.domainTraining)
                        .padding(.horizontal, OutliveSpacing.xs)
                        .padding(.vertical, 2)
                        .background(Color.domainTraining.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.small, style: .continuous))

                    Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.outliveCaption)
                        .foregroundStyle(Color.textTertiary)
                }
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: OutliveSpacing.sm) {
                metricCard(title: "Weight", value: formatKg(entry.weightKg), unit: "kg")
                metricCard(
                    title: "Body Fat",
                    value: entry.bodyFatPercent.map { String(format: "%.1f", $0) } ?? "--",
                    unit: "%"
                )
                metricCard(
                    title: "Muscle Mass",
                    value: entry.muscleMassKg.map { formatKg($0) } ?? "--",
                    unit: "kg"
                )
                metricCard(
                    title: "Visceral Fat",
                    value: entry.visceralFat.map { String(format: "%.0f", $0) } ?? "--",
                    unit: "level"
                )
            }
        }
        .padding(OutliveSpacing.md)
        .background(Color.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.medium, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
    }

    private func metricCard(title: String, value: String, unit: String) -> some View {
        VStack(spacing: OutliveSpacing.xxs) {
            Text(title)
                .font(.outliveCaption)
                .foregroundStyle(Color.textSecondary)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.outliveTitle2)
                    .foregroundStyle(Color.textPrimary)

                Text(unit)
                    .font(.outliveMonoSmall)
                    .foregroundStyle(Color.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(OutliveSpacing.sm)
        .background(Color.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.small, style: .continuous))
    }

    // MARK: - Weight Trend Chart

    private var weightTrendChart: some View {
        let sortedByDate = measurements.reversed() // oldest first
        let weights = Array(sortedByDate.map(\.weightKg))

        return VStack(spacing: OutliveSpacing.sm) {
            SectionHeader(title: "Weight Trend")

            if weights.count >= 2 {
                GeometryReader { geometry in
                    let width = geometry.size.width
                    let height = geometry.size.height
                    let minVal = (weights.min() ?? 0) * 0.98
                    let maxVal = (weights.max() ?? 1) * 1.02
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

                        // Gradient fill
                        Path { path in
                            for (index, weight) in weights.enumerated() {
                                let x = width * CGFloat(index) / CGFloat(weights.count - 1)
                                let y = range > 0
                                    ? height * (1 - CGFloat((weight - minVal) / range))
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
                                colors: [Color.domainTraining.opacity(0.3), Color.domainTraining.opacity(0.0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                        // Line
                        Path { path in
                            for (index, weight) in weights.enumerated() {
                                let x = width * CGFloat(index) / CGFloat(weights.count - 1)
                                let y = range > 0
                                    ? height * (1 - CGFloat((weight - minVal) / range))
                                    : height / 2

                                if index == 0 {
                                    path.move(to: CGPoint(x: x, y: y))
                                } else {
                                    path.addLine(to: CGPoint(x: x, y: y))
                                }
                            }
                        }
                        .stroke(Color.domainTraining, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    }
                }
                .frame(height: 160)
                .padding(OutliveSpacing.md)
                .background(Color.surfaceCard)
                .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.medium, style: .continuous))
            } else {
                Text("Add more measurements to see weight trends.")
                    .font(.outliveBody)
                    .foregroundStyle(Color.textSecondary)
                    .padding(OutliveSpacing.md)
            }
        }
    }

    // MARK: - History

    private var measurementHistory: some View {
        VStack(spacing: OutliveSpacing.sm) {
            SectionHeader(title: "History")

            ForEach(measurements) { entry in
                HStack {
                    Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.outliveSubheadline)
                        .foregroundStyle(Color.textSecondary)

                    Spacer()

                    Text(formatKg(entry.weightKg))
                        .font(.outliveMonoData)
                        .foregroundStyle(Color.textPrimary)

                    Text("kg")
                        .font(.outliveMonoSmall)
                        .foregroundStyle(Color.textTertiary)

                    if let bf = entry.bodyFatPercent {
                        Text("\(String(format: "%.1f", bf))%")
                            .font(.outliveMonoSmall)
                            .foregroundStyle(Color.textSecondary)
                            .frame(width: 50, alignment: .trailing)
                    }
                }
                .padding(.horizontal, OutliveSpacing.md)
                .padding(.vertical, OutliveSpacing.xs)

                if entry.id != measurements.last?.id {
                    Divider().padding(.leading, OutliveSpacing.md)
                }
            }
            .background(Color.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.medium, style: .continuous))
        }
    }

    // MARK: - Actions

    private func saveMeasurement(_ measurement: NewMeasurement) {
        let entry = BodyComposition(
            userId: "",
            date: measurement.date,
            weightKg: measurement.weightKg,
            bodyFatPercent: measurement.bodyFatPercent,
            muscleMassKg: measurement.muscleMassKg,
            visceralFat: measurement.visceralFat,
            source: measurement.source
        )
        modelContext.insert(entry)
    }

    private func formatKg(_ value: Double) -> String {
        String(format: "%.1f", value)
    }
}

// MARK: - New Measurement

private struct NewMeasurement {
    var date: Date = .now
    var weightKg: Double = 0
    var bodyFatPercent: Double?
    var muscleMassKg: Double?
    var visceralFat: Double?
    var source: WearableSource = .manual
}

// MARK: - Add Measurement Sheet

private struct AddMeasurementSheet: View {

    let onSave: (NewMeasurement) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var date = Date()
    @State private var weightText = ""
    @State private var bodyFatText = ""
    @State private var muscleText = ""
    @State private var visceralText = ""
    @State private var source: WearableSource = .manual

    var body: some View {
        NavigationStack {
            Form {
                Section("Measurement Date") {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }

                Section("Body Metrics") {
                    TextField("Weight (kg)", text: $weightText)
                        .keyboardType(.decimalPad)

                    TextField("Body Fat %", text: $bodyFatText)
                        .keyboardType(.decimalPad)

                    TextField("Muscle Mass (kg)", text: $muscleText)
                        .keyboardType(.decimalPad)

                    TextField("Visceral Fat Level", text: $visceralText)
                        .keyboardType(.decimalPad)
                }

                Section("Source") {
                    Picker("Source", selection: $source) {
                        ForEach(WearableSource.allCases, id: \.self) { source in
                            Text(source.rawValue.capitalized).tag(source)
                        }
                    }
                }
            }
            .navigationTitle("New Measurement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let weight = Double(weightText), weight > 0 else { return }
                        let measurement = NewMeasurement(
                            date: date,
                            weightKg: weight,
                            bodyFatPercent: Double(bodyFatText),
                            muscleMassKg: Double(muscleText),
                            visceralFat: Double(visceralText),
                            source: source
                        )
                        onSave(measurement)
                        dismiss()
                    }
                    .disabled(Double(weightText) == nil || Double(weightText) ?? 0 <= 0)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    BodyCompositionView()
        .modelContainer(for: BodyComposition.self, inMemory: true)
}
