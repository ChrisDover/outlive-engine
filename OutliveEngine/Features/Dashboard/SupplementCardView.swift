// SupplementCardView.swift
// OutliveEngine
//
// Detail view for the supplements protocol card. Groups supplements by timing,
// provides take/untake toggles, rationale popovers, and timer navigation.

import SwiftUI

struct SupplementCardView: View {

    let supplements: [SupplementDose]
    let onToggle: (Int) -> Void

    @State private var rationalePopoverIndex: Int?
    @State private var timerSupplement: SupplementDose?

    var body: some View {
        VStack(alignment: .leading, spacing: OutliveSpacing.md) {
            progressSummary

            ForEach(timingGroups, id: \.timing) { group in
                timingSection(group)
            }
        }
        .sheet(item: $timerSupplement) { supplement in
            NavigationStack {
                SupplementTimerView(supplement: supplement)
            }
        }
    }

    // MARK: - Progress Summary

    private var progressSummary: some View {
        HStack {
            let taken = supplements.filter(\.taken).count

            Text("\(taken) of \(supplements.count) taken")
                .font(.outliveSubheadline)
                .foregroundStyle(Color.textSecondary)

            Spacer()

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Color.domainSupplements.opacity(0.15))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Color.domainSupplements)
                        .frame(width: geometry.size.width * progressFraction, height: 6)
                }
            }
            .frame(width: 100, height: 6)
        }
    }

    // MARK: - Timing Sections

    private func timingSection(_ group: TimingGroup) -> some View {
        VStack(alignment: .leading, spacing: OutliveSpacing.xs) {
            // Timing header
            Text(timingLabel(group.timing))
                .font(.outliveCaption)
                .fontWeight(.semibold)
                .foregroundStyle(Color.domainSupplements)
                .textCase(.uppercase)
                .padding(.horizontal, OutliveSpacing.xs)
                .padding(.vertical, OutliveSpacing.xxs)
                .background(Color.domainSupplements.opacity(0.1))
                .clipShape(Capsule())

            // Supplement rows
            VStack(spacing: 0) {
                ForEach(group.entries, id: \.globalIndex) { entry in
                    supplementRow(entry)

                    if entry.globalIndex != group.entries.last?.globalIndex {
                        Divider()
                            .padding(.leading, 40)
                    }
                }
            }
            .background(Color.surfaceBackground.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.small, style: .continuous))
        }
    }

    private func supplementRow(_ entry: SupplementEntry) -> some View {
        HStack(spacing: OutliveSpacing.sm) {
            // Take toggle
            Button {
                onToggle(entry.globalIndex)
            } label: {
                Image(systemName: entry.dose.taken ? "checkmark.circle.fill" : "circle")
                    .font(.outliveBody)
                    .foregroundStyle(entry.dose.taken ? Color.recoveryGreen : Color.textTertiary)
                    .frame(width: 24)
            }
            .buttonStyle(.plain)

            // Name and dose
            VStack(alignment: .leading, spacing: OutliveSpacing.xxs) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        rationalePopoverIndex = rationalePopoverIndex == entry.globalIndex ? nil : entry.globalIndex
                    }
                } label: {
                    Text(entry.dose.name)
                        .font(.outliveBody)
                        .foregroundStyle(entry.dose.taken ? Color.textTertiary : Color.textPrimary)
                        .strikethrough(entry.dose.taken)
                }
                .buttonStyle(.plain)

                Text(entry.dose.dose)
                    .font(.outliveMonoSmall)
                    .foregroundStyle(Color.domainSupplements)
            }

            Spacer()

            // Timer button (for supplements that benefit from timing)
            Button {
                timerSupplement = entry.dose
            } label: {
                Image(systemName: "timer")
                    .font(.outliveSubheadline)
                    .foregroundStyle(Color.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, OutliveSpacing.sm)
        .padding(.vertical, OutliveSpacing.xs)
        .overlay {
            // Rationale popover
            if rationalePopoverIndex == entry.globalIndex {
                rationaleOverlay(entry.dose.rationale)
            }
        }
    }

    // MARK: - Rationale Popover

    private func rationaleOverlay(_ rationale: String) -> some View {
        VStack(alignment: .leading, spacing: OutliveSpacing.xs) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(Color.domainSupplements)
                Text("Rationale")
                    .font(.outliveCaption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                Button {
                    withAnimation { rationalePopoverIndex = nil }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.textTertiary)
                }
                .buttonStyle(.plain)
            }

            Text(rationale)
                .font(.outliveSubheadline)
                .foregroundStyle(Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(OutliveSpacing.sm)
        .background(Color.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.small, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        .offset(y: 50)
        .zIndex(10)
    }

    // MARK: - Helpers

    private var progressFraction: CGFloat {
        guard !supplements.isEmpty else { return 0 }
        return CGFloat(supplements.filter(\.taken).count) / CGFloat(supplements.count)
    }

    private var timingGroups: [TimingGroup] {
        let timingOrder: [SupplementTiming] = [
            .waking, .withBreakfast, .midMorning, .withLunch,
            .afternoon, .withDinner, .preBed
        ]

        var groups: [TimingGroup] = []

        for timing in timingOrder {
            let entries = supplements.enumerated()
                .filter { $0.element.timing == timing }
                .map { SupplementEntry(globalIndex: $0.offset, dose: $0.element) }

            if !entries.isEmpty {
                groups.append(TimingGroup(timing: timing, entries: entries))
            }
        }

        return groups
    }

    private func timingLabel(_ timing: SupplementTiming) -> String {
        switch timing {
        case .waking:        return "On Waking"
        case .withBreakfast: return "With Breakfast"
        case .midMorning:    return "Mid-Morning"
        case .withLunch:     return "With Lunch"
        case .afternoon:     return "Afternoon"
        case .withDinner:    return "With Dinner"
        case .preBed:        return "Pre-Bed"
        }
    }
}

// MARK: - Supporting Types

private struct TimingGroup: Sendable {
    let timing: SupplementTiming
    let entries: [SupplementEntry]
}

private struct SupplementEntry: Sendable {
    let globalIndex: Int
    let dose: SupplementDose
}

// MARK: - SupplementDose Identifiable Conformance

extension SupplementDose: @retroactive Identifiable {
    var id: String { "\(name)-\(timing.rawValue)-\(dose)" }
}

// MARK: - Preview

#Preview {
    let supplements: [SupplementDose] = [
        SupplementDose(name: "Vitamin D3", dose: "5000 IU", timing: .withBreakfast, rationale: "Immune and bone health support", taken: true),
        SupplementDose(name: "Omega-3", dose: "2g", timing: .withBreakfast, rationale: "Anti-inflammatory, cardiovascular support"),
        SupplementDose(name: "Creatine", dose: "5g", timing: .withBreakfast, rationale: "Muscle strength and cellular energy"),
        SupplementDose(name: "Magnesium Glycinate", dose: "200mg", timing: .preBed, rationale: "Sleep quality and muscle recovery"),
    ]

    ProtocolCard(
        icon: "pill.fill",
        title: "Supplements",
        accentColor: .domainSupplements,
        summary: "1/4 taken"
    ) {
        SupplementCardView(supplements: supplements, onToggle: { _ in })
    }
    .padding()
    .background(Color.surfaceBackground)
}
