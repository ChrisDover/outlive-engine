// NotificationSettingsView.swift
// OutliveEngine
//
// Notification toggles and time pickers for scheduled notifications.

import SwiftUI

struct NotificationSettingsView: View {

    @State private var supplementReminders = true
    @State private var sleepReminder = true
    @State private var morningProtocol = true
    @State private var weeklyReport = true

    @State private var supplementTime = defaultTime(hour: 8, minute: 0)
    @State private var sleepTime = defaultTime(hour: 21, minute: 30)
    @State private var morningTime = defaultTime(hour: 6, minute: 30)
    @State private var weeklyReportDay: Weekday = .sunday

    var body: some View {
        List {
            supplementSection
            sleepSection
            morningSection
            weeklySection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Supplements

    private var supplementSection: some View {
        Section {
            Toggle(isOn: $supplementReminders) {
                Label {
                    Text("Supplement Reminders")
                        .font(.outliveBody)
                } icon: {
                    Image(systemName: "pill.fill")
                        .foregroundStyle(Color.domainSupplements)
                }
            }
            .tint(Color.recoveryGreen)

            if supplementReminders {
                DatePicker(
                    "Morning Stack Time",
                    selection: $supplementTime,
                    displayedComponents: .hourAndMinute
                )
                .font(.outliveSubheadline)
            }
        } header: {
            Text("Supplements")
        } footer: {
            Text("Receive reminders to take your supplement stacks at scheduled times.")
        }
    }

    // MARK: - Sleep

    private var sleepSection: some View {
        Section {
            Toggle(isOn: $sleepReminder) {
                Label {
                    Text("Sleep Wind-Down")
                        .font(.outliveBody)
                } icon: {
                    Image(systemName: "moon.fill")
                        .foregroundStyle(Color.domainSleep)
                }
            }
            .tint(Color.recoveryGreen)

            if sleepReminder {
                DatePicker(
                    "Wind-Down Time",
                    selection: $sleepTime,
                    displayedComponents: .hourAndMinute
                )
                .font(.outliveSubheadline)
            }
        } header: {
            Text("Sleep")
        } footer: {
            Text("A reminder to begin your evening wind-down routine for optimal sleep.")
        }
    }

    // MARK: - Morning Protocol

    private var morningSection: some View {
        Section {
            Toggle(isOn: $morningProtocol) {
                Label {
                    Text("Morning Protocol")
                        .font(.outliveBody)
                } icon: {
                    Image(systemName: "sunrise.fill")
                        .foregroundStyle(Color.domainNutrition)
                }
            }
            .tint(Color.recoveryGreen)

            if morningProtocol {
                DatePicker(
                    "Protocol Time",
                    selection: $morningTime,
                    displayedComponents: .hourAndMinute
                )
                .font(.outliveSubheadline)
            }
        } header: {
            Text("Morning")
        } footer: {
            Text("Start your day with your personalized morning protocol review.")
        }
    }

    // MARK: - Weekly Report

    private var weeklySection: some View {
        Section {
            Toggle(isOn: $weeklyReport) {
                Label {
                    Text("Weekly Report")
                        .font(.outliveBody)
                } icon: {
                    Image(systemName: "chart.bar.doc.horizontal.fill")
                        .foregroundStyle(Color.domainTraining)
                }
            }
            .tint(Color.recoveryGreen)

            if weeklyReport {
                Picker("Day", selection: $weeklyReportDay) {
                    ForEach(Weekday.allCases, id: \.self) { day in
                        Text(day.rawValue.capitalized).tag(day)
                    }
                }
                .font(.outliveSubheadline)
            }
        } header: {
            Text("Weekly")
        } footer: {
            Text("Receive your weekly performance and adherence report.")
        }
    }

    // MARK: - Helpers

    private static func defaultTime(hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components) ?? Date()
    }
}

// MARK: - Weekday

private enum Weekday: String, CaseIterable {
    case sunday, monday, tuesday, wednesday, thursday, friday, saturday
}

// MARK: - Preview

#Preview {
    NavigationStack {
        NotificationSettingsView()
    }
}
