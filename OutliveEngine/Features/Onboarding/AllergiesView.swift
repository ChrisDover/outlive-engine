// AllergiesView.swift
// OutliveEngine
//
// Allergen and dietary restriction selection. Users can search for allergens,
// pick from common presets, and declare dietary patterns. All selections
// influence supplement and nutrition protocol generation.

import SwiftUI

struct AllergiesView: View {
    @Bindable var viewModel: OnboardingViewModel
    @State private var searchText = ""

    private let commonAllergens = [
        "Dairy", "Gluten", "Nuts", "Shellfish",
        "Soy", "Eggs", "Fish", "Sesame",
    ]

    private let dietaryOptions = [
        "Vegetarian", "Vegan", "Keto", "Paleo",
        "Mediterranean", "Halal", "Kosher",
    ]

    private var filteredAllergens: [String] {
        guard !searchText.isEmpty else { return commonAllergens }
        return commonAllergens.filter {
            $0.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            OnboardingStepHeader(step: .allergies, progress: viewModel.progress)

            ScrollView {
                VStack(alignment: .leading, spacing: OutliveSpacing.lg) {
                    searchBar
                    selectedTags
                    allergenSection
                    dietarySection
                }
                .padding(.horizontal, OutliveSpacing.md)
                .padding(.top, OutliveSpacing.md)
                .padding(.bottom, OutliveSpacing.xl)
            }

            Spacer()

            buttonSection
        }
        .background(Color.surfaceBackground)
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { viewModel.previous() } label: {
                    Image(systemName: "chevron.left")
                        .font(.outliveHeadline)
                }
            }
        }
        .onAppear { viewModel.currentStep = .allergies }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: OutliveSpacing.xs) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.textTertiary)

            TextField("Search allergens...", text: $searchText)
                .font(.outliveBody)
                .foregroundStyle(Color.textPrimary)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.textTertiary)
                }
            }
        }
        .padding(OutliveSpacing.sm)
        .background(Color.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.small, style: .continuous))
    }

    // MARK: - Selected Tags

    @ViewBuilder
    private var selectedTags: some View {
        let allSelected = Array(viewModel.selectedAllergies) + Array(viewModel.dietaryRestrictions)

        if !allSelected.isEmpty {
            VStack(alignment: .leading, spacing: OutliveSpacing.xs) {
                Text("Selected")
                    .font(.outliveFootnote)
                    .foregroundStyle(Color.textSecondary)
                    .textCase(.uppercase)

                FlowLayout(spacing: OutliveSpacing.xs) {
                    ForEach(allSelected, id: \.self) { tag in
                        SelectedTag(title: tag) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewModel.selectedAllergies.remove(tag)
                                viewModel.dietaryRestrictions.remove(tag)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Allergen Section

    private var allergenSection: some View {
        VStack(alignment: .leading, spacing: OutliveSpacing.sm) {
            SectionHeader(title: "Common Allergens")

            FlowLayout(spacing: OutliveSpacing.xs) {
                ForEach(filteredAllergens, id: \.self) { allergen in
                    ToggleChip(
                        title: allergen,
                        isSelected: viewModel.selectedAllergies.contains(allergen)
                    ) {
                        toggleAllergen(allergen)
                    }
                }
            }
        }
    }

    // MARK: - Dietary Section

    private var dietarySection: some View {
        VStack(alignment: .leading, spacing: OutliveSpacing.sm) {
            SectionHeader(title: "Dietary Patterns")

            FlowLayout(spacing: OutliveSpacing.xs) {
                ForEach(dietaryOptions, id: \.self) { option in
                    ToggleChip(
                        title: option,
                        isSelected: viewModel.dietaryRestrictions.contains(option)
                    ) {
                        toggleDietaryRestriction(option)
                    }
                }
            }
        }
    }

    // MARK: - Buttons

    private var buttonSection: some View {
        VStack(spacing: OutliveSpacing.sm) {
            OutliveButton(title: "Continue", style: .primary) {
                viewModel.next()
            }

            Button("Skip for Now") {
                viewModel.skipStep()
            }
            .font(.outliveSubheadline)
            .foregroundStyle(Color.textSecondary)
        }
        .padding(.horizontal, OutliveSpacing.md)
        .padding(.bottom, OutliveSpacing.lg)
    }

    // MARK: - Toggle Helpers

    private func toggleAllergen(_ allergen: String) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if viewModel.selectedAllergies.contains(allergen) {
                viewModel.selectedAllergies.remove(allergen)
            } else {
                viewModel.selectedAllergies.insert(allergen)
            }
        }
    }

    private func toggleDietaryRestriction(_ restriction: String) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if viewModel.dietaryRestrictions.contains(restriction) {
                viewModel.dietaryRestrictions.remove(restriction)
            } else {
                viewModel.dietaryRestrictions.insert(restriction)
            }
        }
    }
}

// MARK: - Toggle Chip

private struct ToggleChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.outliveSubheadline)
                .foregroundStyle(isSelected ? Color.white : Color.textPrimary)
                .padding(.horizontal, OutliveSpacing.sm)
                .padding(.vertical, OutliveSpacing.xs)
                .background(
                    RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.small, style: .continuous)
                        .fill(isSelected ? Color.domainTraining : Color.surfaceCard)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.small, style: .continuous)
                        .strokeBorder(isSelected ? Color.clear : Color.textTertiary.opacity(0.4), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}

// MARK: - Selected Tag

private struct SelectedTag: View {
    let title: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: OutliveSpacing.xxs) {
            Text(title)
                .font(.outliveCaption)
                .foregroundStyle(Color.domainTraining)

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.domainTraining.opacity(0.6))
            }
        }
        .padding(.horizontal, OutliveSpacing.xs)
        .padding(.vertical, OutliveSpacing.xxs)
        .background(
            RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.small, style: .continuous)
                .fill(Color.domainTraining.opacity(0.12))
        )
    }
}

// MARK: - Flow Layout

/// A simple flow layout that wraps children horizontally.
private struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)

        for (index, subview) in subviews.enumerated() {
            let point = CGPoint(
                x: bounds.minX + result.positions[index].x,
                y: bounds.minY + result.positions[index].y
            )
            subview.place(at: point, anchor: .topLeading, proposal: .unspecified)
        }
    }

    private func arrangeSubviews(
        proposal: ProposedViewSize,
        subviews: Subviews
    ) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += rowHeight + spacing
                rowHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            rowHeight = max(rowHeight, size.height)
            currentX += size.width + spacing
            totalWidth = max(totalWidth, currentX - spacing)
            totalHeight = currentY + rowHeight
        }

        return (positions, CGSize(width: totalWidth, height: totalHeight))
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        AllergiesView(viewModel: OnboardingViewModel())
            .environment(AppState())
    }
}
