// TrainingCardView.swift
// OutliveEngine
//
// Detail view for the training protocol card. Displays workout type, duration,
// RPE target, and a toggleable exercise checklist.

import SwiftUI

struct TrainingCardView: View {

    let training: TrainingBlock
    let completedExercises: Set<Int>
    let onToggle: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: OutliveSpacing.md) {
            headerBadges
            exerciseList

            if let notes = training.notes, !notes.isEmpty {
                notesSection(notes)
            }
        }
    }

    // MARK: - Header Badges

    private var headerBadges: some View {
        HStack(spacing: OutliveSpacing.xs) {
            badge(
                icon: trainingIcon,
                text: training.type.rawValue.capitalized,
                color: .domainTraining
            )

            badge(
                icon: "clock",
                text: "\(training.duration) min",
                color: .textSecondary
            )

            badge(
                icon: "flame",
                text: "RPE \(String(format: "%.1f", training.rpeTarget))",
                color: rpeColor
            )

            Spacer()
        }
    }

    private func badge(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: OutliveSpacing.xxs) {
            Image(systemName: icon)
                .font(.outliveCaption)
            Text(text)
                .font(.outliveCaption)
        }
        .foregroundStyle(color)
        .padding(.horizontal, OutliveSpacing.xs)
        .padding(.vertical, OutliveSpacing.xxs)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }

    // MARK: - Exercise List

    private var exerciseList: some View {
        VStack(spacing: 0) {
            ForEach(Array(training.exercises.enumerated()), id: \.offset) { index, exercise in
                exerciseRow(exercise, index: index)

                if index < training.exercises.count - 1 {
                    Divider()
                        .padding(.leading, 40)
                }
            }
        }
        .background(Color.surfaceBackground.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.small, style: .continuous))
    }

    private func exerciseRow(_ exercise: Exercise, index: Int) -> some View {
        Button {
            onToggle(index)
        } label: {
            HStack(alignment: .top, spacing: OutliveSpacing.sm) {
                Image(systemName: completedExercises.contains(index) ? "checkmark.circle.fill" : "circle")
                    .font(.outliveBody)
                    .foregroundStyle(completedExercises.contains(index) ? Color.recoveryGreen : Color.textTertiary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: OutliveSpacing.xxs) {
                    Text(exercise.name)
                        .font(.outliveBody)
                        .foregroundStyle(completedExercises.contains(index) ? Color.textTertiary : Color.textPrimary)
                        .strikethrough(completedExercises.contains(index))

                    HStack(spacing: OutliveSpacing.sm) {
                        Text("\(exercise.sets) sets")
                            .font(.outliveMonoSmall)
                            .foregroundStyle(Color.textSecondary)

                        Text(exercise.reps)
                            .font(.outliveMonoSmall)
                            .foregroundStyle(Color.textSecondary)

                        if let weight = exercise.weight {
                            Text(weight)
                                .font(.outliveMonoSmall)
                                .foregroundStyle(Color.domainTraining)
                        }
                    }

                    if let notes = exercise.notes {
                        Text(notes)
                            .font(.outliveCaption)
                            .foregroundStyle(Color.textTertiary)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, OutliveSpacing.sm)
            .padding(.vertical, OutliveSpacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Notes

    private func notesSection(_ notes: String) -> some View {
        HStack(alignment: .top, spacing: OutliveSpacing.xs) {
            Image(systemName: "note.text")
                .font(.outliveCaption)
                .foregroundStyle(Color.textTertiary)

            Text(notes)
                .font(.outliveSubheadline)
                .foregroundStyle(Color.textSecondary)
                .italic()
        }
        .padding(OutliveSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.domainTraining.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.small, style: .continuous))
    }

    // MARK: - Helpers

    private var trainingIcon: String {
        switch training.type {
        case .strength:    return "scalemass.fill"
        case .hypertrophy: return "figure.strengthtraining.traditional"
        case .endurance:   return "figure.run"
        case .mobility:    return "figure.flexibility"
        case .deload:      return "arrow.down.circle"
        case .rest:        return "bed.double.fill"
        }
    }

    private var rpeColor: Color {
        if training.rpeTarget >= 8.0 { return .recoveryRed }
        if training.rpeTarget >= 6.0 { return .recoveryYellow }
        return .recoveryGreen
    }
}

// MARK: - Preview

#Preview {
    let training = TrainingBlock(
        type: .strength,
        exercises: [
            Exercise(name: "Barbell Back Squat", sets: 4, reps: "5", weight: "225 lbs", notes: "Compound lower body"),
            Exercise(name: "Bench Press", sets: 4, reps: "5", weight: "185 lbs", notes: nil),
            Exercise(name: "Barbell Row", sets: 4, reps: "5", weight: nil, notes: "Horizontal pull"),
        ],
        duration: 60,
        rpeTarget: 8.0,
        notes: "Focus on bracing and controlled tempo today."
    )

    ProtocolCard(
        icon: "dumbbell.fill",
        title: "Strength Training",
        accentColor: .domainTraining,
        summary: "60 min — RPE 8.0 — 3 exercises"
    ) {
        TrainingCardView(
            training: training,
            completedExercises: [1],
            onToggle: { _ in }
        )
    }
    .padding()
    .background(Color.surfaceBackground)
}
