// NutritionCardView.swift
// OutliveEngine
//
// Detail view for the nutrition protocol card. Displays macro rings,
// calorie targets, and an expandable meal plan with per-meal macros.

import SwiftUI

struct NutritionCardView: View {

    let nutrition: NutritionPlan
    let completedMeals: Set<Int>
    let onToggleMeal: (Int) -> Void

    @State private var expandedMealIndex: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: OutliveSpacing.md) {
            macroRingsRow
            calorieTarget
            mealsList

            if let notes = nutrition.notes, !notes.isEmpty {
                notesSection(notes)
            }
        }
    }

    // MARK: - Macro Rings

    private var macroRingsRow: some View {
        HStack(spacing: OutliveSpacing.lg) {
            Spacer()

            MetricRing(
                value: macroFraction(consumed: consumedProtein, target: nutrition.protein),
                label: "Protein",
                color: .domainTraining,
                lineWidth: 6
            )
            .frame(width: 72, height: 92)
            .overlay(alignment: .bottom) {
                Text("\(nutrition.protein)g")
                    .font(.outliveMonoSmall)
                    .foregroundStyle(Color.textSecondary)
                    .offset(y: 8)
            }

            MetricRing(
                value: macroFraction(consumed: consumedCarbs, target: nutrition.carbs),
                label: "Carbs",
                color: .domainNutrition,
                lineWidth: 6
            )
            .frame(width: 72, height: 92)
            .overlay(alignment: .bottom) {
                Text("\(nutrition.carbs)g")
                    .font(.outliveMonoSmall)
                    .foregroundStyle(Color.textSecondary)
                    .offset(y: 8)
            }

            MetricRing(
                value: macroFraction(consumed: consumedFat, target: nutrition.fat),
                label: "Fat",
                color: .recoveryYellow,
                lineWidth: 6
            )
            .frame(width: 72, height: 92)
            .overlay(alignment: .bottom) {
                Text("\(nutrition.fat)g")
                    .font(.outliveMonoSmall)
                    .foregroundStyle(Color.textSecondary)
                    .offset(y: 8)
            }

            Spacer()
        }
        .padding(.top, OutliveSpacing.xs)
    }

    // MARK: - Calorie Target

    private var calorieTarget: some View {
        HStack {
            VStack(alignment: .leading, spacing: OutliveSpacing.xxs) {
                Text("TDEE")
                    .font(.outliveCaption)
                    .foregroundStyle(Color.textTertiary)

                Text("\(nutrition.tdee)")
                    .font(.outliveMonoData)
                    .foregroundStyle(Color.textPrimary)
                + Text(" kcal")
                    .font(.outliveMonoSmall)
                    .foregroundStyle(Color.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: OutliveSpacing.xxs) {
                Text("Target")
                    .font(.outliveCaption)
                    .foregroundStyle(Color.textTertiary)

                let totalCalories = nutrition.meals.reduce(0) { $0 + $1.calories }
                Text("\(totalCalories)")
                    .font(.outliveMonoData)
                    .foregroundStyle(Color.domainNutrition)
                + Text(" kcal")
                    .font(.outliveMonoSmall)
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .padding(OutliveSpacing.sm)
        .background(Color.surfaceBackground.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.small, style: .continuous))
    }

    // MARK: - Meals List

    private var mealsList: some View {
        VStack(spacing: 0) {
            ForEach(Array(nutrition.meals.enumerated()), id: \.offset) { index, meal in
                mealRow(meal, index: index)

                if index < nutrition.meals.count - 1 {
                    Divider()
                        .padding(.leading, 40)
                }
            }
        }
        .background(Color.surfaceBackground.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.small, style: .continuous))
    }

    private func mealRow(_ meal: MealPlan, index: Int) -> some View {
        VStack(spacing: 0) {
            Button {
                onToggleMeal(index)
            } label: {
                HStack(alignment: .top, spacing: OutliveSpacing.sm) {
                    Image(systemName: completedMeals.contains(index) ? "checkmark.circle.fill" : "circle")
                        .font(.outliveBody)
                        .foregroundStyle(completedMeals.contains(index) ? Color.recoveryGreen : Color.textTertiary)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: OutliveSpacing.xxs) {
                        HStack {
                            Text(mealTimingLabel(meal.timing))
                                .font(.outliveHeadline)
                                .foregroundStyle(completedMeals.contains(index) ? Color.textTertiary : Color.textPrimary)

                            Spacer()

                            Text("\(meal.calories) kcal")
                                .font(.outliveMonoSmall)
                                .foregroundStyle(Color.domainNutrition)
                        }

                        Text(meal.description)
                            .font(.outliveSubheadline)
                            .foregroundStyle(Color.textSecondary)
                            .lineLimit(expandedMealIndex == index ? nil : 2)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, OutliveSpacing.sm)
                .padding(.vertical, OutliveSpacing.xs)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expandable macro detail
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    expandedMealIndex = expandedMealIndex == index ? nil : index
                }
            } label: {
                HStack(spacing: OutliveSpacing.xs) {
                    Spacer()
                    Text(expandedMealIndex == index ? "Hide macros" : "Show macros")
                        .font(.outliveCaption)
                        .foregroundStyle(Color.domainNutrition)
                    Image(systemName: "chevron.down")
                        .font(.outliveCaption)
                        .foregroundStyle(Color.domainNutrition)
                        .rotationEffect(.degrees(expandedMealIndex == index ? 180 : 0))
                }
                .padding(.horizontal, OutliveSpacing.sm)
                .padding(.bottom, OutliveSpacing.xs)
            }
            .buttonStyle(.plain)

            if expandedMealIndex == index {
                macroDetailRow(meal)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func macroDetailRow(_ meal: MealPlan) -> some View {
        HStack(spacing: OutliveSpacing.lg) {
            macroLabel("P", value: meal.protein, color: .domainTraining)
            macroLabel("C", value: meal.carbs, color: .domainNutrition)
            macroLabel("F", value: meal.fat, color: .recoveryYellow)
        }
        .padding(.horizontal, OutliveSpacing.sm)
        .padding(.bottom, OutliveSpacing.sm)
        .padding(.leading, 36)
    }

    private func macroLabel(_ letter: String, value: Int, color: Color) -> some View {
        HStack(spacing: OutliveSpacing.xxs) {
            Text(letter)
                .font(.outliveCaption)
                .fontWeight(.bold)
                .foregroundStyle(color)

            Text("\(value)g")
                .font(.outliveMonoSmall)
                .foregroundStyle(Color.textSecondary)
        }
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
        .background(Color.domainNutrition.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.small, style: .continuous))
    }

    // MARK: - Helpers

    private var consumedProtein: Int {
        completedMeals.reduce(0) { total, index in
            guard nutrition.meals.indices.contains(index) else { return total }
            return total + nutrition.meals[index].protein
        }
    }

    private var consumedCarbs: Int {
        completedMeals.reduce(0) { total, index in
            guard nutrition.meals.indices.contains(index) else { return total }
            return total + nutrition.meals[index].carbs
        }
    }

    private var consumedFat: Int {
        completedMeals.reduce(0) { total, index in
            guard nutrition.meals.indices.contains(index) else { return total }
            return total + nutrition.meals[index].fat
        }
    }

    private func macroFraction(consumed: Int, target: Int) -> Double {
        guard target > 0 else { return 0 }
        return min(Double(consumed) / Double(target), 1.0)
    }

    private func mealTimingLabel(_ timing: MealTiming) -> String {
        switch timing {
        case .breakfast: return "Breakfast"
        case .amSnack:   return "AM Snack"
        case .lunch:     return "Lunch"
        case .pmSnack:   return "PM Snack"
        case .dinner:    return "Dinner"
        case .preBed:    return "Pre-Bed"
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
        meals: [
            MealPlan(timing: .breakfast, description: "Eggs, avocado, sourdough toast", calories: 550, protein: 35, carbs: 40, fat: 28),
            MealPlan(timing: .lunch, description: "Grilled chicken, brown rice, broccoli", calories: 650, protein: 50, carbs: 65, fat: 15),
            MealPlan(timing: .dinner, description: "Salmon, sweet potato, mixed greens", calories: 700, protein: 45, carbs: 55, fat: 25),
        ],
        notes: "Higher carbs around training window."
    )

    ProtocolCard(
        icon: "fork.knife",
        title: "Nutrition",
        accentColor: .domainNutrition,
        summary: "2400 kcal target"
    ) {
        NutritionCardView(
            nutrition: nutrition,
            completedMeals: [0],
            onToggleMeal: { _ in }
        )
    }
    .padding()
    .background(Color.surfaceBackground)
}
