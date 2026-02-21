// SupplementTimerView.swift
// OutliveEngine
//
// Full-screen countdown for supplement timing windows. Displays the supplement
// name and dose above a TimerView, with optional notification scheduling.

import SwiftUI
import UserNotifications

struct SupplementTimerView: View {

    let supplement: SupplementDose

    @Environment(\.dismiss) private var dismiss
    @State private var isComplete = false
    @State private var notificationScheduled = false

    /// Default timer duration for supplements (30 minutes between doses).
    private let defaultTimerSeconds = 30 * 60

    var body: some View {
        VStack(spacing: OutliveSpacing.xl) {
            Spacer()

            supplementInfo
            timerSection

            if isComplete {
                completionBanner
            }

            Spacer()

            notificationToggle
            dismissButton
        }
        .padding(OutliveSpacing.lg)
        .background(Color.surfaceBackground)
        .navigationTitle("Supplement Timer")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
                    .foregroundStyle(Color.domainSupplements)
            }
        }
    }

    // MARK: - Supplement Info

    private var supplementInfo: some View {
        VStack(spacing: OutliveSpacing.sm) {
            Image(systemName: "pill.fill")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(Color.domainSupplements)

            Text(supplement.name)
                .font(.outliveTitle2)
                .foregroundStyle(Color.textPrimary)
                .multilineTextAlignment(.center)

            Text(supplement.dose)
                .font(.outliveMonoData)
                .foregroundStyle(Color.domainSupplements)

            Text(timingLabel)
                .font(.outliveSubheadline)
                .foregroundStyle(Color.textSecondary)
        }
    }

    // MARK: - Timer

    private var timerSection: some View {
        TimerView(totalSeconds: defaultTimerSeconds) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                isComplete = true
            }
        }
    }

    // MARK: - Completion

    private var completionBanner: some View {
        HStack(spacing: OutliveSpacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .font(.outliveTitle3)
                .foregroundStyle(Color.recoveryGreen)

            VStack(alignment: .leading, spacing: OutliveSpacing.xxs) {
                Text("Timer Complete")
                    .font(.outliveHeadline)
                    .foregroundStyle(Color.textPrimary)

                Text("Time for your next supplement window")
                    .font(.outliveSubheadline)
                    .foregroundStyle(Color.textSecondary)
            }

            Spacer()
        }
        .padding(OutliveSpacing.md)
        .background(Color.recoveryGreen.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.medium, style: .continuous))
        .transition(.scale.combined(with: .opacity))
    }

    // MARK: - Notification Toggle

    private var notificationToggle: some View {
        Button {
            toggleNotification()
        } label: {
            HStack(spacing: OutliveSpacing.sm) {
                Image(systemName: notificationScheduled ? "bell.fill" : "bell")
                    .foregroundStyle(notificationScheduled
                                     ? Color.domainSupplements
                                     : Color.textSecondary)

                Text(notificationScheduled ? "Reminder scheduled" : "Remind me when done")
                    .font(.outliveSubheadline)
                    .foregroundStyle(notificationScheduled
                                     ? Color.domainSupplements
                                     : Color.textSecondary)

                Spacer()

                if notificationScheduled {
                    Image(systemName: "checkmark")
                        .font(.outliveCaption)
                        .foregroundStyle(Color.domainSupplements)
                }
            }
            .padding(OutliveSpacing.md)
            .background(Color.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.small, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Dismiss

    private var dismissButton: some View {
        OutliveButton(title: isComplete ? "Done" : "Cancel", style: isComplete ? .primary : .secondary) {
            dismiss()
        }
    }

    // MARK: - Helpers

    private var timingLabel: String {
        switch supplement.timing {
        case .waking:        return "Take on waking"
        case .withBreakfast: return "Take with breakfast"
        case .midMorning:    return "Take mid-morning"
        case .withLunch:     return "Take with lunch"
        case .afternoon:     return "Take in the afternoon"
        case .withDinner:    return "Take with dinner"
        case .preBed:        return "Take before bed"
        }
    }

    private func toggleNotification() {
        if notificationScheduled {
            UNUserNotificationCenter.current().removePendingNotificationRequests(
                withIdentifiers: ["supplement-timer-\(supplement.name)"]
            )
            notificationScheduled = false
            return
        }

        // Request notification permission and schedule
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            scheduleNotification()
        }
    }

    private func scheduleNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Supplement Timer"
        content.body = "Time to take \(supplement.name) (\(supplement.dose))"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(defaultTimerSeconds),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: "supplement-timer-\(supplement.name)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if error == nil {
                Task { @MainActor in
                    notificationScheduled = true
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SupplementTimerView(
            supplement: SupplementDose(
                name: "Creatine Monohydrate",
                dose: "5g",
                timing: .withBreakfast,
                rationale: "Muscle strength and cellular energy"
            )
        )
    }
}
