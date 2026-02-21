// SleepCardView.swift
// OutliveEngine
//
// Detail view for the sleep protocol card. Shows target bedtime and wake time,
// an evening checklist, notes, and a countdown to bedtime.

import SwiftUI

struct SleepCardView: View {

    let sleep: SleepProtocol
    let completedItems: Set<Int>
    let onToggle: (Int) -> Void

    @State private var currentTime = Date.now
    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: OutliveSpacing.md) {
            timeDisplay
            bedtimeCountdown
            eveningChecklist

            if let notes = sleep.notes, !notes.isEmpty {
                notesSection(notes)
            }
        }
    }

    // MARK: - Time Display

    private var timeDisplay: some View {
        HStack(spacing: OutliveSpacing.xl) {
            Spacer()

            timeBlock(
                label: "Bedtime",
                time: sleep.targetBedtime,
                icon: "moon.fill",
                color: .domainSleep
            )

            // Arrow
            Image(systemName: "arrow.right")
                .font(.outliveTitle3)
                .foregroundStyle(Color.textTertiary)

            timeBlock(
                label: "Wake",
                time: sleep.targetWakeTime,
                icon: "sunrise.fill",
                color: .domainNutrition
            )

            Spacer()
        }
    }

    private func timeBlock(label: String, time: String, icon: String, color: Color) -> some View {
        VStack(spacing: OutliveSpacing.xs) {
            Image(systemName: icon)
                .font(.outliveTitle3)
                .foregroundStyle(color)

            Text(time)
                .font(.system(size: 28, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.textPrimary)

            Text(label)
                .font(.outliveCaption)
                .foregroundStyle(Color.textSecondary)
        }
    }

    // MARK: - Bedtime Countdown

    private var bedtimeCountdown: some View {
        Group {
            if let countdown = timeUntilBedtime {
                HStack(spacing: OutliveSpacing.xs) {
                    Image(systemName: countdown.isOverdue ? "exclamationmark.triangle.fill" : "clock")
                        .font(.outliveSubheadline)
                        .foregroundStyle(countdown.isOverdue ? Color.recoveryRed : Color.domainSleep)

                    if countdown.isOverdue {
                        Text("Bedtime was \(countdown.display) ago")
                            .font(.outliveSubheadline)
                            .foregroundStyle(Color.recoveryRed)
                    } else {
                        Text("\(countdown.display) until bedtime")
                            .font(.outliveSubheadline)
                            .foregroundStyle(Color.domainSleep)
                    }

                    Spacer()
                }
                .padding(OutliveSpacing.sm)
                .background(
                    (countdown.isOverdue ? Color.recoveryRed : Color.domainSleep).opacity(0.08)
                )
                .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.small, style: .continuous))
            }
        }
        .onReceive(timer) { _ in
            currentTime = .now
        }
    }

    // MARK: - Evening Checklist

    private var eveningChecklist: some View {
        VStack(alignment: .leading, spacing: OutliveSpacing.xs) {
            Text("Evening Checklist")
                .font(.outliveCaption)
                .fontWeight(.semibold)
                .foregroundStyle(Color.domainSleep)
                .textCase(.uppercase)

            VStack(spacing: 0) {
                ForEach(Array(sleep.eveningChecklist.enumerated()), id: \.offset) { index, item in
                    checklistRow(item, index: index)

                    if index < sleep.eveningChecklist.count - 1 {
                        Divider()
                            .padding(.leading, 40)
                    }
                }
            }
            .background(Color.surfaceBackground.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.small, style: .continuous))
        }
    }

    private func checklistRow(_ item: String, index: Int) -> some View {
        Button {
            onToggle(index)
        } label: {
            HStack(spacing: OutliveSpacing.sm) {
                Image(systemName: completedItems.contains(index)
                      ? "checkmark.circle.fill"
                      : "circle")
                    .font(.outliveBody)
                    .foregroundStyle(completedItems.contains(index)
                                     ? Color.recoveryGreen
                                     : Color.textTertiary)
                    .frame(width: 24)

                Text(item)
                    .font(.outliveSubheadline)
                    .foregroundStyle(completedItems.contains(index)
                                     ? Color.textTertiary
                                     : Color.textPrimary)
                    .strikethrough(completedItems.contains(index))
                    .multilineTextAlignment(.leading)

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
        .background(Color.domainSleep.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.small, style: .continuous))
    }

    // MARK: - Helpers

    private struct CountdownInfo {
        let display: String
        let isOverdue: Bool
    }

    private var timeUntilBedtime: CountdownInfo? {
        guard let bedtimeDate = parseTimeToday(sleep.targetBedtime) else { return nil }

        let interval = bedtimeDate.timeIntervalSince(currentTime)

        if interval <= 0 {
            let overdue = abs(interval)
            let hours = Int(overdue) / 3600
            let minutes = (Int(overdue) % 3600) / 60
            if hours > 0 {
                return CountdownInfo(display: "\(hours)h \(minutes)m", isOverdue: true)
            }
            return CountdownInfo(display: "\(minutes)m", isOverdue: true)
        }

        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60

        if hours > 0 {
            return CountdownInfo(display: "\(hours)h \(minutes)m", isOverdue: false)
        }
        return CountdownInfo(display: "\(minutes)m", isOverdue: false)
    }

    private func parseTimeToday(_ timeString: String) -> Date? {
        let parts = timeString.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return nil }

        var calendar = Calendar.current
        calendar.timeZone = .current
        return calendar.date(
            bySettingHour: parts[0],
            minute: parts[1],
            second: 0,
            of: currentTime
        )
    }
}

// MARK: - Preview

#Preview {
    let sleep = SleepProtocol(
        targetBedtime: "22:00",
        targetWakeTime: "06:00",
        eveningChecklist: [
            "Dim lights 2 hours before bed",
            "No screens 1 hour before bed",
            "Bedroom temperature 65-68 F",
            "No caffeine after 12:00 PM",
            "No alcohol within 3 hours of bedtime",
        ],
        notes: "Standard sleep protocol. Aim for 7-8 hours."
    )

    ProtocolCard(
        icon: "moon.fill",
        title: "Sleep Protocol",
        accentColor: .domainSleep,
        summary: "Bed 22:00 - Wake 06:00"
    ) {
        SleepCardView(
            sleep: sleep,
            completedItems: [0, 3],
            onToggle: { _ in }
        )
    }
    .padding()
    .background(Color.surfaceBackground)
}
