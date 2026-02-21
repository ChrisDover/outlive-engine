// ProfileEditView.swift
// OutliveEngine
//
// Edit user profile: display name, birth date, biological sex, height, goals, allergies.

import SwiftUI
import SwiftData

struct ProfileEditView: View {

    @Query private var profiles: [UserProfile]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var displayName = ""
    @State private var birthDate = Date()
    @State private var hasBirthDate = false
    @State private var biologicalSex = ""
    @State private var heightCm = ""
    @State private var selectedGoals: Set<HealthGoal> = []
    @State private var allergiesText = ""
    @State private var dietaryRestrictionsText = ""
    @State private var hasLoaded = false

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        Form {
            basicInfoSection
            goalsSection
            allergiesSection
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { saveProfile() }
            }
        }
        .onAppear { loadProfile() }
    }

    // MARK: - Basic Info

    private var basicInfoSection: some View {
        Section("Basic Information") {
            TextField("Display Name", text: $displayName)

            Toggle("Set Birth Date", isOn: $hasBirthDate)
            if hasBirthDate {
                DatePicker("Birth Date", selection: $birthDate, displayedComponents: .date)
            }

            Picker("Biological Sex", selection: $biologicalSex) {
                Text("Not Set").tag("")
                Text("Male").tag("male")
                Text("Female").tag("female")
            }

            TextField("Height (cm)", text: $heightCm)
                .keyboardType(.decimalPad)
        }
    }

    // MARK: - Goals

    private var goalsSection: some View {
        Section("Health Goals") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: OutliveSpacing.xs) {
                ForEach(HealthGoal.allCases, id: \.self) { goal in
                    goalChip(goal)
                }
            }
        }
    }

    private func goalChip(_ goal: HealthGoal) -> some View {
        let isSelected = selectedGoals.contains(goal)

        return Button {
            if isSelected {
                selectedGoals.remove(goal)
            } else {
                selectedGoals.insert(goal)
            }
        } label: {
            Text(goal.rawValue.capitalized)
                .font(.outliveSubheadline)
                .foregroundStyle(isSelected ? .white : Color.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, OutliveSpacing.xs)
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

    // MARK: - Allergies

    private var allergiesSection: some View {
        Section {
            VStack(alignment: .leading, spacing: OutliveSpacing.xxs) {
                Text("Allergies")
                    .font(.outliveCaption)
                    .foregroundStyle(Color.textSecondary)

                TextField("Comma-separated (e.g., peanuts, shellfish)", text: $allergiesText)
                    .font(.outliveBody)
            }

            VStack(alignment: .leading, spacing: OutliveSpacing.xxs) {
                Text("Dietary Restrictions")
                    .font(.outliveCaption)
                    .foregroundStyle(Color.textSecondary)

                TextField("Comma-separated (e.g., gluten-free, dairy-free)", text: $dietaryRestrictionsText)
                    .font(.outliveBody)
            }
        } header: {
            Text("Allergies & Diet")
        }
    }

    // MARK: - Data

    private func loadProfile() {
        guard !hasLoaded, let profile else { return }
        hasLoaded = true
        displayName = profile.displayName ?? ""
        if let bd = profile.birthDate {
            birthDate = bd
            hasBirthDate = true
        }
        biologicalSex = profile.biologicalSex ?? ""
        heightCm = profile.heightCm.map { String(format: "%.0f", $0) } ?? ""
        selectedGoals = Set(profile.goals)
        allergiesText = profile.allergies.joined(separator: ", ")
        dietaryRestrictionsText = profile.dietaryRestrictions.joined(separator: ", ")
    }

    private func saveProfile() {
        guard let profile else { return }

        profile.displayName = displayName.isEmpty ? nil : displayName
        profile.birthDate = hasBirthDate ? birthDate : nil
        profile.biologicalSex = biologicalSex.isEmpty ? nil : biologicalSex
        profile.heightCm = Double(heightCm)
        profile.goals = Array(selectedGoals)
        profile.allergies = parseCommaSeparated(allergiesText)
        profile.dietaryRestrictions = parseCommaSeparated(dietaryRestrictionsText)
        profile.updatedAt = Date()

        dismiss()
    }

    private func parseCommaSeparated(_ text: String) -> [String] {
        text.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ProfileEditView()
    }
    .modelContainer(for: UserProfile.self, inMemory: true)
}
