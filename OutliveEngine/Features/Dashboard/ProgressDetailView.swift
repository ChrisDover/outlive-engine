// ProgressDetailView.swift
// OutliveEngine
//
// Adherence breakdown across all protocol domains with per-domain MetricRings,
// total adherence score, and simple 7-day / 30-day trend visualizations.

import SwiftUI

struct ProgressDetailView: View {

    let viewModel: DashboardViewModel

    @State private var selectedRange: TrendRange = .sevenDay

    var body: some View {
        ScrollView {
            VStack(spacing: OutliveSpacing.lg) {
                totalAdherenceSection
                domainBreakdownSection
                trendSection
            }
            .padding(.horizontal, OutliveSpacing.md)
            .padding(.bottom, OutliveSpacing.xxl)
        }
        .background(Color.surfaceBackground)
        .navigationTitle("Progress")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Total Adherence

    private var totalAdherenceSection: some View {
        VStack(spacing: OutliveSpacing.md) {
            MetricRing(
                value: viewModel.calculateAdherence(),
                label: "Total Adherence",
                color: totalColor,
                lineWidth: 12
            )
            .frame(width: 140, height: 170)

            Text(adherenceDescription)
                .font(.outliveSubheadline)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(OutliveSpacing.lg)
        .frame(maxWidth: .infinity)
        .background(Color.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.medium, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
    }

    // MARK: - Domain Breakdown

    private var domainBreakdownSection: some View {
        VStack(alignment: .leading, spacing: OutliveSpacing.md) {
            SectionHeader(title: "Domain Breakdown")

            VStack(spacing: OutliveSpacing.sm) {
                ForEach(ProtocolDomain.allCases, id: \.self) { domain in
                    domainRow(domain)
                }
            }
            .padding(OutliveSpacing.md)
            .background(Color.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.medium, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
        }
    }

    private func domainRow(_ domain: ProtocolDomain) -> some View {
        HStack(spacing: OutliveSpacing.md) {
            MetricRing(
                value: viewModel.domainAdherence(for: domain),
                label: "",
                color: domain.color,
                lineWidth: 5
            )
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: OutliveSpacing.xxs) {
                Text(domain.displayName)
                    .font(.outliveHeadline)
                    .foregroundStyle(Color.textPrimary)

                Text(domainStatusText(domain))
                    .font(.outliveCaption)
                    .foregroundStyle(Color.textSecondary)
            }

            Spacer()

            Text("\(Int(viewModel.domainAdherence(for: domain) * 100))%")
                .font(.outliveMonoData)
                .foregroundStyle(domain.color)
        }
        .padding(.vertical, OutliveSpacing.xxs)
    }

    // MARK: - Trends

    private var trendSection: some View {
        VStack(alignment: .leading, spacing: OutliveSpacing.md) {
            HStack {
                SectionHeader(title: "Trends")

                Spacer()

                Picker("Range", selection: $selectedRange) {
                    ForEach(TrendRange.allCases, id: \.self) { range in
                        Text(range.displayName).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
            }

            trendChart
                .padding(OutliveSpacing.md)
                .background(Color.surfaceCard)
                .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.medium, style: .continuous))
                .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
        }
    }

    private var trendChart: some View {
        VStack(alignment: .leading, spacing: OutliveSpacing.sm) {
            Text("Adherence Over Time")
                .font(.outliveCaption)
                .foregroundStyle(Color.textSecondary)

            // Placeholder trend chart using paths
            GeometryReader { geometry in
                let data = placeholderTrendData
                let width = geometry.size.width
                let height = geometry.size.height
                let stepX = width / CGFloat(max(data.count - 1, 1))

                ZStack {
                    // Grid lines
                    ForEach([0.25, 0.5, 0.75, 1.0], id: \.self) { level in
                        Path { path in
                            let y = height * (1 - CGFloat(level))
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: width, y: y))
                        }
                        .stroke(Color.textTertiary.opacity(0.3), style: StrokeStyle(lineWidth: 0.5, dash: [4]))
                    }

                    // Grid labels
                    VStack {
                        Text("100%")
                            .font(.outliveCaption)
                            .foregroundStyle(Color.textTertiary)
                        Spacer()
                        Text("50%")
                            .font(.outliveCaption)
                            .foregroundStyle(Color.textTertiary)
                        Spacer()
                        Text("0%")
                            .font(.outliveCaption)
                            .foregroundStyle(Color.textTertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)

                    // Gradient fill under line
                    Path { path in
                        guard !data.isEmpty else { return }

                        path.move(to: CGPoint(x: 0, y: height))

                        for (index, value) in data.enumerated() {
                            let x = CGFloat(index) * stepX
                            let y = height * (1 - CGFloat(value))
                            path.addLine(to: CGPoint(x: x, y: y))
                        }

                        path.addLine(to: CGPoint(x: CGFloat(data.count - 1) * stepX, y: height))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [Color.domainTraining.opacity(0.2), Color.domainTraining.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    // Line
                    Path { path in
                        guard !data.isEmpty else { return }

                        for (index, value) in data.enumerated() {
                            let x = CGFloat(index) * stepX
                            let y = height * (1 - CGFloat(value))

                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(Color.domainTraining, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                    // Data points
                    ForEach(Array(data.enumerated()), id: \.offset) { index, value in
                        let x = CGFloat(index) * stepX
                        let y = height * (1 - CGFloat(value))

                        Circle()
                            .fill(Color.domainTraining)
                            .frame(width: 6, height: 6)
                            .position(x: x, y: y)
                    }

                    // Today marker
                    if let lastValue = data.last {
                        let x = CGFloat(data.count - 1) * stepX
                        let y = height * (1 - CGFloat(lastValue))

                        Circle()
                            .fill(Color.surfaceCard)
                            .frame(width: 10, height: 10)
                            .overlay(Circle().stroke(Color.domainTraining, lineWidth: 2))
                            .position(x: x, y: y)
                    }
                }
            }
            .frame(height: 160)
            .padding(.trailing, 36) // Space for grid labels

            // Day labels
            HStack {
                ForEach(dayLabels, id: \.self) { label in
                    Text(label)
                        .font(.outliveCaption)
                        .foregroundStyle(Color.textTertiary)
                    if label != dayLabels.last {
                        Spacer()
                    }
                }
            }
            .padding(.trailing, 36)
        }
    }

    // MARK: - Helpers

    private var totalColor: Color {
        let value = viewModel.calculateAdherence()
        if value >= 0.75 { return .recoveryGreen }
        if value >= 0.4 { return .recoveryYellow }
        return .recoveryRed
    }

    private var adherenceDescription: String {
        let value = viewModel.calculateAdherence()
        if value >= 0.9 { return "Outstanding adherence. Keep up the consistency." }
        if value >= 0.75 { return "Strong adherence today. A few items remaining." }
        if value >= 0.5 { return "Good progress. Complete remaining items to stay on track." }
        if value >= 0.25 { return "Getting started. Focus on the highest-impact items first." }
        return "Begin your protocol to start tracking adherence."
    }

    private func domainStatusText(_ domain: ProtocolDomain) -> String {
        let adherence = viewModel.domainAdherence(for: domain)
        let percent = Int(adherence * 100)

        switch domain {
        case .training:
            let total = viewModel.dailyProtocol?.training?.exercises.count ?? 0
            let done = viewModel.completedExercises.count
            return "\(done)/\(total) exercises — \(percent)%"

        case .nutrition:
            let total = viewModel.dailyProtocol?.nutrition?.meals.count ?? 0
            let done = viewModel.completedMeals.count
            return "\(done)/\(total) meals — \(percent)%"

        case .supplements:
            let supplements = viewModel.dailyProtocol?.supplements ?? []
            let done = supplements.filter(\.taken).count
            return "\(done)/\(supplements.count) taken — \(percent)%"

        case .interventions:
            let total = viewModel.dailyProtocol?.interventions.count ?? 0
            let done = viewModel.completedInterventions.count
            return "\(done)/\(total) completed — \(percent)%"

        case .sleep:
            let total = viewModel.dailyProtocol?.sleep?.eveningChecklist.count ?? 0
            let done = viewModel.completedChecklistItems.count
            return "\(done)/\(total) checklist items — \(percent)%"
        }
    }

    /// Placeholder trend data for visualization. In production, this would query
    /// historical DailyProtocol adherence scores from SwiftData.
    private var placeholderTrendData: [Double] {
        switch selectedRange {
        case .sevenDay:
            // Last 7 days with today's actual adherence as the final point
            var data: [Double] = [0.65, 0.72, 0.80, 0.68, 0.85, 0.78]
            data.append(viewModel.calculateAdherence())
            return data

        case .thirtyDay:
            // Last 30 days (sampled at weekly intervals) with today's adherence
            var data: [Double] = [0.55, 0.62, 0.68, 0.72, 0.70, 0.78]
            data.append(viewModel.calculateAdherence())
            return data
        }
    }

    private var dayLabels: [String] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "E"

        let dayCount = selectedRange == .sevenDay ? 7 : 7 // Show 7 labels either way
        let stride = selectedRange == .sevenDay ? 1 : 5

        return (0..<dayCount).reversed().map { offset in
            let date = calendar.date(byAdding: .day, value: -(offset * stride), to: .now) ?? .now
            return offset == 0 ? "Today" : formatter.string(from: date)
        }
    }
}

// MARK: - Trend Range

enum TrendRange: String, CaseIterable, Sendable {
    case sevenDay
    case thirtyDay

    var displayName: String {
        switch self {
        case .sevenDay:  return "7 Day"
        case .thirtyDay: return "30 Day"
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ProgressDetailView(viewModel: DashboardViewModel())
    }
}
