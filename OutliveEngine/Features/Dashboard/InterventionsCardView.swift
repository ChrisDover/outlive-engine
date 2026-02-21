// InterventionsCardView.swift
// OutliveEngine
//
// Detail view for the interventions protocol card. Displays intervention type,
// duration, temperature, timer access, and expandable notes.

import SwiftUI

struct InterventionsCardView: View {

    let interventions: [InterventionBlock]
    let completedInterventions: Set<Int>
    let onToggle: (Int) -> Void

    @State private var expandedNoteIndex: Int?
    @State private var timerIntervention: TimerInterventionState?

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(interventions.enumerated()), id: \.offset) { index, intervention in
                interventionRow(intervention, index: index)

                if index < interventions.count - 1 {
                    Divider()
                        .padding(.leading, 40)
                }
            }
        }
        .background(Color.surfaceBackground.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.small, style: .continuous))
        .sheet(item: $timerIntervention) { state in
            NavigationStack {
                interventionTimerSheet(state)
            }
            .presentationDetents([.medium])
        }
    }

    // MARK: - Intervention Row

    private func interventionRow(_ intervention: InterventionBlock, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: OutliveSpacing.sm) {
                // Completion toggle
                Button {
                    onToggle(index)
                } label: {
                    Image(systemName: completedInterventions.contains(index)
                          ? "checkmark.circle.fill"
                          : "circle")
                        .font(.outliveBody)
                        .foregroundStyle(completedInterventions.contains(index)
                                         ? Color.recoveryGreen
                                         : Color.textTertiary)
                        .frame(width: 24)
                }
                .buttonStyle(.plain)

                // Icon
                Image(systemName: interventionIcon(intervention.type))
                    .font(.outliveTitle3)
                    .foregroundStyle(Color.domainInterventions)
                    .frame(width: 32, height: 32)

                // Details
                VStack(alignment: .leading, spacing: OutliveSpacing.xxs) {
                    Text(interventionName(intervention.type))
                        .font(.outliveBody)
                        .foregroundStyle(completedInterventions.contains(index)
                                         ? Color.textTertiary
                                         : Color.textPrimary)
                        .strikethrough(completedInterventions.contains(index))

                    HStack(spacing: OutliveSpacing.xs) {
                        Label("\(intervention.duration) min", systemImage: "clock")
                            .font(.outliveMonoSmall)
                            .foregroundStyle(Color.textSecondary)

                        if let temp = intervention.temperature {
                            Label(temp, systemImage: "thermometer.medium")
                                .font(.outliveMonoSmall)
                                .foregroundStyle(temperatureColor(intervention.type))
                        }
                    }
                }

                Spacer()

                // Actions
                HStack(spacing: OutliveSpacing.sm) {
                    // Notes toggle
                    if intervention.notes != nil {
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                expandedNoteIndex = expandedNoteIndex == index ? nil : index
                            }
                        } label: {
                            Image(systemName: "note.text")
                                .font(.outliveSubheadline)
                                .foregroundStyle(expandedNoteIndex == index
                                                 ? Color.domainInterventions
                                                 : Color.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }

                    // Timer button for timed interventions
                    if isTimedIntervention(intervention.type) {
                        Button {
                            timerIntervention = TimerInterventionState(
                                name: interventionName(intervention.type),
                                duration: intervention.duration,
                                index: index
                            )
                        } label: {
                            Image(systemName: "timer")
                                .font(.outliveSubheadline)
                                .foregroundStyle(Color.domainInterventions)
                                .padding(OutliveSpacing.xs)
                                .background(Color.domainInterventions.opacity(0.12))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, OutliveSpacing.sm)
            .padding(.vertical, OutliveSpacing.xs)

            // Expandable notes
            if expandedNoteIndex == index, let notes = intervention.notes {
                Text(notes)
                    .font(.outliveSubheadline)
                    .foregroundStyle(Color.textSecondary)
                    .padding(.horizontal, OutliveSpacing.md)
                    .padding(.bottom, OutliveSpacing.sm)
                    .padding(.leading, 36)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Timer Sheet

    private func interventionTimerSheet(_ state: TimerInterventionState) -> some View {
        VStack(spacing: OutliveSpacing.lg) {
            Text(state.name)
                .font(.outliveTitle2)
                .foregroundStyle(Color.textPrimary)

            TimerView(totalSeconds: state.duration * 60) {
                // Mark intervention as completed when timer finishes
                onToggle(state.index)
                timerIntervention = nil
            }

            OutliveButton(title: "Done", style: .secondary) {
                timerIntervention = nil
            }
            .padding(.horizontal, OutliveSpacing.xl)
        }
        .padding(OutliveSpacing.lg)
        .navigationTitle("Timer")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Close") {
                    timerIntervention = nil
                }
                .foregroundStyle(Color.domainInterventions)
            }
        }
    }

    // MARK: - Helpers

    private func interventionIcon(_ type: InterventionType) -> String {
        switch type {
        case .sauna:      return "flame.fill"
        case .coldPlunge: return "snowflake"
        case .breathwork: return "wind"
        case .redLight:   return "light.max"
        case .grounding:  return "leaf.fill"
        case .meditation: return "brain.head.profile"
        }
    }

    private func interventionName(_ type: InterventionType) -> String {
        switch type {
        case .sauna:      return "Sauna"
        case .coldPlunge: return "Cold Plunge"
        case .breathwork: return "Breathwork"
        case .redLight:   return "Red Light"
        case .grounding:  return "Grounding"
        case .meditation: return "Meditation"
        }
    }

    private func temperatureColor(_ type: InterventionType) -> Color {
        switch type {
        case .sauna:      return .recoveryRed
        case .coldPlunge: return .domainInterventions
        default:          return .textSecondary
        }
    }

    private func isTimedIntervention(_ type: InterventionType) -> Bool {
        switch type {
        case .sauna, .coldPlunge, .breathwork, .meditation, .redLight:
            return true
        case .grounding:
            return false
        }
    }
}

// MARK: - Timer State

private struct TimerInterventionState: Identifiable {
    let name: String
    let duration: Int
    let index: Int
    var id: String { "\(name)-\(index)" }
}

// MARK: - Preview

#Preview {
    let interventions: [InterventionBlock] = [
        InterventionBlock(type: .sauna, duration: 20, temperature: "180-200 F", notes: "Deliberate heat exposure for cardiovascular benefits"),
        InterventionBlock(type: .coldPlunge, duration: 3, temperature: "38-45 F", notes: "Post-sauna cold exposure"),
        InterventionBlock(type: .breathwork, duration: 10, temperature: nil, notes: "Box breathing protocol"),
    ]

    ProtocolCard(
        icon: "snowflake",
        title: "Interventions",
        accentColor: .domainInterventions,
        summary: "Sauna, Cold Plunge, Breathwork"
    ) {
        InterventionsCardView(
            interventions: interventions,
            completedInterventions: [1],
            onToggle: { _ in }
        )
    }
    .padding()
    .background(Color.surfaceBackground)
}
