// GutHealthCardView.swift
// OutliveEngine
//
// Detail view for gut health protocol items. Displays fiber target and progress,
// probiotic/prebiotic protocol, and fermented foods checklist.

import SwiftUI

struct GutHealthCardView: View {

    let nutrition: NutritionPlan
    let supplements: [SupplementDose]

    @State private var completedFoods: Set<Int> = []

    // Standard fiber target (grams)
    private let fiberTarget = 30

    var body: some View {
        VStack(alignment: .leading, spacing: OutliveSpacing.md) {
            fiberSection
            probioticSection
            fermentedFoodsSection
        }
    }

    // MARK: - Fiber Target

    private var fiberSection: some View {
        VStack(alignment: .leading, spacing: OutliveSpacing.xs) {
            Text("DAILY FIBER")
                .font(.outliveCaption)
                .fontWeight(.semibold)
                .foregroundStyle(Color.recoveryGreen)
                .textCase(.uppercase)

            HStack(spacing: OutliveSpacing.md) {
                // Fiber ring
                MetricRing(
                    value: fiberProgress,
                    label: "Fiber",
                    color: .recoveryGreen,
                    lineWidth: 6
                )
                .frame(width: 64, height: 84)

                VStack(alignment: .leading, spacing: OutliveSpacing.xxs) {
                    Text("Target: \(fiberTarget)g")
                        .font(.outliveMonoData)
                        .foregroundStyle(Color.textPrimary)

                    Text("Estimated from meal plan")
                        .font(.outliveCaption)
                        .foregroundStyle(Color.textSecondary)

                    // Simple fiber estimate based on carbs
                    let estimatedFiber = estimatedDailyFiber
                    Text("~\(estimatedFiber)g estimated")
                        .font(.outliveMonoSmall)
                        .foregroundStyle(estimatedFiber >= fiberTarget
                                         ? Color.recoveryGreen
                                         : Color.recoveryYellow)
                }

                Spacer()
            }
            .padding(OutliveSpacing.sm)
            .background(Color.surfaceBackground.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.small, style: .continuous))
        }
    }

    // MARK: - Probiotic / Prebiotic Section

    private var probioticSection: some View {
        VStack(alignment: .leading, spacing: OutliveSpacing.xs) {
            Text("PROBIOTIC & PREBIOTIC")
                .font(.outliveCaption)
                .fontWeight(.semibold)
                .foregroundStyle(Color.recoveryGreen)
                .textCase(.uppercase)

            let gutSupplements = supplements.filter { supplement in
                let name = supplement.name.lowercased()
                return name.contains("probiotic") ||
                       name.contains("prebiotic") ||
                       name.contains("glutamine") ||
                       name.contains("fiber")
            }

            if gutSupplements.isEmpty {
                HStack(spacing: OutliveSpacing.xs) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(Color.textTertiary)

                    Text("No specific gut supplements in today's stack. Consider adding a multi-strain probiotic.")
                        .font(.outliveSubheadline)
                        .foregroundStyle(Color.textSecondary)
                }
                .padding(OutliveSpacing.sm)
                .background(Color.surfaceBackground.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.small, style: .continuous))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(gutSupplements.enumerated()), id: \.offset) { index, supplement in
                        HStack(spacing: OutliveSpacing.sm) {
                            Image(systemName: supplement.taken ? "checkmark.circle.fill" : "circle")
                                .font(.outliveBody)
                                .foregroundStyle(supplement.taken ? Color.recoveryGreen : Color.textTertiary)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: OutliveSpacing.xxs) {
                                Text(supplement.name)
                                    .font(.outliveBody)
                                    .foregroundStyle(Color.textPrimary)

                                Text(supplement.dose)
                                    .font(.outliveMonoSmall)
                                    .foregroundStyle(Color.textSecondary)
                            }

                            Spacer()

                            Text(timingLabel(supplement.timing))
                                .font(.outliveCaption)
                                .foregroundStyle(Color.domainSupplements)
                        }
                        .padding(.horizontal, OutliveSpacing.sm)
                        .padding(.vertical, OutliveSpacing.xs)

                        if index < gutSupplements.count - 1 {
                            Divider()
                                .padding(.leading, 40)
                        }
                    }
                }
                .background(Color.surfaceBackground.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.small, style: .continuous))
            }
        }
    }

    // MARK: - Fermented Foods

    private var fermentedFoodsSection: some View {
        VStack(alignment: .leading, spacing: OutliveSpacing.xs) {
            Text("FERMENTED FOODS")
                .font(.outliveCaption)
                .fontWeight(.semibold)
                .foregroundStyle(Color.recoveryGreen)
                .textCase(.uppercase)

            Text("Aim for 1-2 servings daily for microbiome diversity")
                .font(.outliveCaption)
                .foregroundStyle(Color.textSecondary)

            VStack(spacing: 0) {
                ForEach(Array(fermentedFoods.enumerated()), id: \.offset) { index, food in
                    Button {
                        toggleFood(at: index)
                    } label: {
                        HStack(spacing: OutliveSpacing.sm) {
                            Image(systemName: completedFoods.contains(index)
                                  ? "checkmark.circle.fill"
                                  : "circle")
                                .font(.outliveBody)
                                .foregroundStyle(completedFoods.contains(index)
                                                 ? Color.recoveryGreen
                                                 : Color.textTertiary)
                                .frame(width: 24)

                            Text(food)
                                .font(.outliveSubheadline)
                                .foregroundStyle(completedFoods.contains(index)
                                                 ? Color.textTertiary
                                                 : Color.textPrimary)
                                .strikethrough(completedFoods.contains(index))

                            Spacer()
                        }
                        .padding(.horizontal, OutliveSpacing.sm)
                        .padding(.vertical, OutliveSpacing.xs)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if index < fermentedFoods.count - 1 {
                        Divider()
                            .padding(.leading, 40)
                    }
                }
            }
            .background(Color.surfaceBackground.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.small, style: .continuous))
        }
    }

    // MARK: - Helpers

    private var fermentedFoods: [String] {
        [
            "Yogurt (plain, full-fat)",
            "Sauerkraut or kimchi",
            "Kefir",
            "Kombucha",
            "Miso",
        ]
    }

    /// Estimates daily fiber from the meal plan carbohydrate content.
    /// Rough heuristic: ~12% of carbs come from fiber in a whole-foods diet.
    private var estimatedDailyFiber: Int {
        Int(Double(nutrition.carbs) * 0.12)
    }

    private var fiberProgress: Double {
        min(Double(estimatedDailyFiber) / Double(fiberTarget), 1.0)
    }

    private func toggleFood(at index: Int) {
        if completedFoods.contains(index) {
            completedFoods.remove(index)
        } else {
            completedFoods.insert(index)
        }
    }

    private func timingLabel(_ timing: SupplementTiming) -> String {
        switch timing {
        case .waking:        return "On Waking"
        case .withBreakfast: return "Breakfast"
        case .midMorning:    return "Mid-AM"
        case .withLunch:     return "Lunch"
        case .afternoon:     return "Afternoon"
        case .withDinner:    return "Dinner"
        case .preBed:        return "Pre-Bed"
        }
    }
}

// MARK: - Preview

#Preview {
    let nutrition = NutritionPlan(
        tdee: 2400,
        protein: 180,
        carbs: 250,
        fat: 75,
        meals: []
    )

    let supplements: [SupplementDose] = [
        SupplementDose(name: "Probiotic (Multi-strain)", dose: "50 billion CFU", timing: .waking, rationale: "Gut microbiome diversity", taken: true),
        SupplementDose(name: "L-Glutamine", dose: "5g", timing: .waking, rationale: "Gut barrier support"),
    ]

    ProtocolCard(
        icon: "leaf.fill",
        title: "Gut Health",
        accentColor: .recoveryGreen,
        summary: "Fiber, probiotics, and fermented foods"
    ) {
        GutHealthCardView(nutrition: nutrition, supplements: supplements)
    }
    .padding()
    .background(Color.surfaceBackground)
}
