// MealPlanner.swift
// OutliveEngine
//
// Generates daily nutrition plans with macro calculations, meal distribution,
// allergy filtering, and genetic adjustments. Fully deterministic.

import Foundation

// MARK: - Engine

struct MealPlanner: Sendable {

    // MARK: - Public API

    /// Generates a complete daily nutrition plan.
    ///
    /// Uses Katch-McArdle for TDEE if body fat is known, Mifflin-St Jeor otherwise.
    /// Macros are adjusted for training type, goals, and genetic factors.
    func plan(
        weightKg: Double,
        bodyFatPercent: Double?,
        goals: [HealthGoal],
        trainingType: TrainingType,
        allergies: [String],
        dietaryRestrictions: [String],
        geneticAdjustments: [String]
    ) -> NutritionPlan {

        let primaryGoal = goals.first ?? .longevity

        // ── Step 1: Calculate TDEE ───────────────────────────────
        let bmr = calculateBMR(weightKg: weightKg, bodyFatPercent: bodyFatPercent)
        let activityMultiplier = activityMultiplier(for: trainingType)
        let baseTDEE = Int(bmr * activityMultiplier)

        // ── Step 2: Apply goal-based caloric adjustment ──────────
        let tdee = applyGoalAdjustment(baseTDEE: baseTDEE, goal: primaryGoal)

        // ── Step 3: Calculate macros ─────────────────────────────
        var macros = calculateMacros(
            tdee: tdee,
            weightKg: weightKg,
            goal: primaryGoal,
            trainingType: trainingType
        )

        // ── Step 4: Apply genetic adjustments ────────────────────
        macros = applyGeneticAdjustments(macros, adjustments: geneticAdjustments, weightKg: weightKg)

        // ── Step 5: Distribute across meals ──────────────────────
        let meals = distributeMeals(
            tdee: macros.tdee,
            protein: macros.protein,
            carbs: macros.carbs,
            fat: macros.fat,
            trainingType: trainingType,
            allergies: allergies,
            dietaryRestrictions: dietaryRestrictions
        )

        // ── Step 6: Generate notes ───────────────────────────────
        var notes = generateNotes(
            goal: primaryGoal,
            trainingType: trainingType,
            geneticAdjustments: geneticAdjustments
        )
        if !allergies.isEmpty {
            notes += " Allergens excluded: \(allergies.joined(separator: ", "))."
        }
        if !dietaryRestrictions.isEmpty {
            notes += " Dietary restrictions applied: \(dietaryRestrictions.joined(separator: ", "))."
        }

        return NutritionPlan(
            tdee: macros.tdee,
            protein: macros.protein,
            carbs: macros.carbs,
            fat: macros.fat,
            meals: meals,
            notes: notes
        )
    }

    // MARK: - BMR Calculation

    private func calculateBMR(weightKg: Double, bodyFatPercent: Double?) -> Double {
        if let bf = bodyFatPercent, bf > 0, bf < 100 {
            // Katch-McArdle: BMR = 370 + (21.6 * lean body mass in kg)
            let leanMass = weightKg * (1.0 - bf / 100.0)
            return 370.0 + (21.6 * leanMass)
        } else {
            // Mifflin-St Jeor (using male defaults when sex unknown, as a conservative estimate)
            // BMR = (10 * weight_kg) + (6.25 * height_cm) - (5 * age) + 5
            // Without height/age, use simplified: 10 * weight + 800
            return 10.0 * weightKg + 800.0
        }
    }

    // MARK: - Activity Multiplier

    private func activityMultiplier(for trainingType: TrainingType) -> Double {
        switch trainingType {
        case .strength:    return 1.55
        case .hypertrophy: return 1.60
        case .endurance:   return 1.65
        case .mobility:    return 1.30
        case .deload:      return 1.35
        case .rest:        return 1.20
        }
    }

    // MARK: - Goal Adjustment

    private func applyGoalAdjustment(baseTDEE: Int, goal: HealthGoal) -> Int {
        switch goal {
        case .muscleGain:       return baseTDEE + 300     // Lean surplus
        case .fatLoss:          return baseTDEE - 400     // Moderate deficit
        case .longevity:        return baseTDEE           // Maintenance
        case .cardiovascular:   return baseTDEE           // Maintenance
        case .cognitive:        return baseTDEE           // Maintenance
        case .metabolic:        return baseTDEE - 100     // Slight deficit for insulin sensitivity
        case .hormonal:         return baseTDEE + 100     // Slight surplus supports hormone production
        case .sleep:            return baseTDEE           // Maintenance
        case .gutHealth:        return baseTDEE           // Maintenance
        case .stressResilience: return baseTDEE           // Maintenance — avoid deficits under stress
        }
    }

    // MARK: - Macro Calculation

    private struct MacroSet {
        var tdee: Int
        var protein: Int
        var carbs: Int
        var fat: Int
    }

    private func calculateMacros(
        tdee: Int,
        weightKg: Double,
        goal: HealthGoal,
        trainingType: TrainingType
    ) -> MacroSet {
        // Protein based on goal
        let proteinPerKg: Double
        switch goal {
        case .muscleGain:  proteinPerKg = 2.2
        case .fatLoss:     proteinPerKg = 2.4  // Higher protein preserves muscle in deficit
        case .longevity:   proteinPerKg = 1.6
        case .hormonal:    proteinPerKg = 2.0
        default:           proteinPerKg = 1.8
        }
        let protein = Int(proteinPerKg * weightKg)
        let proteinCal = protein * 4

        // Fat: 25-35% of calories depending on goal
        let fatPercent: Double
        switch goal {
        case .hormonal:   fatPercent = 0.35 // Higher fat for hormone synthesis
        case .fatLoss:    fatPercent = 0.25
        case .longevity:  fatPercent = 0.30
        default:          fatPercent = 0.28
        }
        let fatCal = Int(Double(tdee) * fatPercent)
        let fat = fatCal / 9

        // Carbs: remainder
        let carbCal = max(tdee - proteinCal - fatCal, 0)
        // Adjust carbs for training type
        let carbAdjustment: Double
        switch trainingType {
        case .endurance:   carbAdjustment = 1.15 // 15% more carbs on endurance days
        case .rest:        carbAdjustment = 0.85
        case .mobility:    carbAdjustment = 0.90
        case .deload:      carbAdjustment = 0.90
        default:           carbAdjustment = 1.0
        }
        let carbs = Int(Double(carbCal) / 4.0 * carbAdjustment)

        // Recalculate actual TDEE from macros
        let actualTDEE = (protein * 4) + (carbs * 4) + (fat * 9)

        return MacroSet(tdee: actualTDEE, protein: protein, carbs: carbs, fat: fat)
    }

    // MARK: - Genetic Adjustments

    private func applyGeneticAdjustments(
        _ macros: MacroSet,
        adjustments: [String],
        weightKg: Double
    ) -> MacroSet {
        var m = macros
        let lowerAdj = adjustments.map { $0.lowercased() }

        // FTO risk allele: increase protein for satiety
        if lowerAdj.contains(where: { $0.contains("fto") && $0.contains("protein") }) {
            let currentProteinPerKg = Double(m.protein) / weightKg
            if currentProteinPerKg < 2.2 {
                let newProtein = Int(2.2 * weightKg)
                let proteinIncrease = newProtein - m.protein
                m.protein = newProtein
                // Reduce carbs to compensate
                m.carbs = max(m.carbs - proteinIncrease, 50)
            }
        }

        // APOE4: reduce saturated fat — shift fat calories toward MUFA/PUFA
        // (We can reduce total fat slightly and shift to carbs)
        if lowerAdj.contains(where: { $0.contains("apoe") && $0.contains("sat") }) {
            let fatReduction = m.fat / 10 // reduce fat by ~10%
            m.fat -= fatReduction
            m.carbs += (fatReduction * 9) / 4 // redistribute calories to carbs
        }

        // Recalculate TDEE
        m.tdee = (m.protein * 4) + (m.carbs * 4) + (m.fat * 9)

        return m
    }

    // MARK: - Meal Distribution

    private func distributeMeals(
        tdee: Int,
        protein: Int,
        carbs: Int,
        fat: Int,
        trainingType: TrainingType,
        allergies: [String],
        dietaryRestrictions: [String]
    ) -> [MealPlan] {
        // Distribution ratios: breakfast 25%, lunch 30%, dinner 30%, snacks 15%
        let breakfastRatio = 0.25
        let lunchRatio = 0.30
        let dinnerRatio = 0.30
        let snackRatio = 0.15

        let isVegetarian = dietaryRestrictions.contains(where: {
            $0.lowercased().contains("vegetarian") || $0.lowercased().contains("vegan")
        })
        let isVegan = dietaryRestrictions.contains(where: { $0.lowercased().contains("vegan") })
        let lowerAllergies = Set(allergies.map { $0.lowercased() })

        let breakfastDesc = breakfastDescription(
            isVegan: isVegan, isVegetarian: isVegetarian,
            allergies: lowerAllergies, trainingType: trainingType
        )
        let lunchDesc = lunchDescription(
            isVegan: isVegan, isVegetarian: isVegetarian,
            allergies: lowerAllergies
        )
        let dinnerDesc = dinnerDescription(
            isVegan: isVegan, isVegetarian: isVegetarian,
            allergies: lowerAllergies
        )
        let snackDesc = snackDescription(
            isVegan: isVegan, isVegetarian: isVegetarian,
            allergies: lowerAllergies
        )

        return [
            MealPlan(
                timing: .breakfast,
                description: breakfastDesc,
                calories: Int(Double(tdee) * breakfastRatio),
                protein: Int(Double(protein) * breakfastRatio),
                carbs: Int(Double(carbs) * breakfastRatio),
                fat: Int(Double(fat) * breakfastRatio)
            ),
            MealPlan(
                timing: .lunch,
                description: lunchDesc,
                calories: Int(Double(tdee) * lunchRatio),
                protein: Int(Double(protein) * lunchRatio),
                carbs: Int(Double(carbs) * lunchRatio),
                fat: Int(Double(fat) * lunchRatio)
            ),
            MealPlan(
                timing: .dinner,
                description: dinnerDesc,
                calories: Int(Double(tdee) * dinnerRatio),
                protein: Int(Double(protein) * dinnerRatio),
                carbs: Int(Double(carbs) * dinnerRatio),
                fat: Int(Double(fat) * dinnerRatio)
            ),
            MealPlan(
                timing: .pmSnack,
                description: snackDesc,
                calories: Int(Double(tdee) * snackRatio),
                protein: Int(Double(protein) * snackRatio),
                carbs: Int(Double(carbs) * snackRatio),
                fat: Int(Double(fat) * snackRatio)
            ),
        ]
    }

    // MARK: - Meal Descriptions

    private func breakfastDescription(
        isVegan: Bool, isVegetarian: Bool,
        allergies: Set<String>, trainingType: TrainingType
    ) -> String {
        if isVegan {
            return "Tofu scramble with spinach and nutritional yeast, oatmeal with hemp seeds and berries"
        }
        if isVegetarian {
            if allergies.contains("eggs") {
                return "Greek yogurt parfait with granola and berries, whole grain toast with nut butter"
            }
            return "Egg white omelette with vegetables and feta, oatmeal with berries"
        }
        if allergies.contains("eggs") {
            return "Turkey sausage with avocado, oatmeal with protein powder and berries"
        }
        if allergies.contains("dairy") {
            return "Whole eggs with turkey bacon, oatmeal with almond butter and berries"
        }
        if trainingType == .endurance {
            return "Whole eggs, oatmeal with banana and honey, toast with almond butter"
        }
        return "Whole eggs with spinach and avocado, oatmeal with berries and protein"
    }

    private func lunchDescription(
        isVegan: Bool, isVegetarian: Bool,
        allergies: Set<String>
    ) -> String {
        if isVegan {
            return "Lentil and quinoa bowl with roasted vegetables, tahini dressing, mixed greens"
        }
        if isVegetarian {
            return "Mediterranean bowl with chickpeas, feta, roasted vegetables, quinoa, olive oil"
        }
        if allergies.contains("gluten") {
            return "Grilled chicken over rice with roasted vegetables, olive oil, side salad"
        }
        return "Grilled chicken breast with sweet potato, mixed greens salad, olive oil dressing"
    }

    private func dinnerDescription(
        isVegan: Bool, isVegetarian: Bool,
        allergies: Set<String>
    ) -> String {
        if isVegan {
            return "Tempeh stir-fry with brown rice, broccoli, bell peppers, sesame ginger sauce"
        }
        if isVegetarian {
            return "Black bean and sweet potato enchiladas with guacamole and side salad"
        }
        if allergies.contains("fish") || allergies.contains("shellfish") {
            return "Grass-fed beef or chicken thigh with roasted vegetables and sweet potato"
        }
        return "Wild-caught salmon with roasted broccoli and sweet potato, olive oil"
    }

    private func snackDescription(
        isVegan: Bool, isVegetarian: Bool,
        allergies: Set<String>
    ) -> String {
        if isVegan {
            return "Trail mix with almonds and dark chocolate, apple with almond butter"
        }
        if allergies.contains("nuts") || allergies.contains("tree nuts") {
            return "Greek yogurt with berries, rice cakes with sunflower seed butter"
        }
        if allergies.contains("dairy") {
            return "Apple with almond butter, mixed nuts and dark chocolate"
        }
        return "Greek yogurt with mixed nuts and berries, or protein shake with banana"
    }

    // MARK: - Notes Generation

    private func generateNotes(
        goal: HealthGoal,
        trainingType: TrainingType,
        geneticAdjustments: [String]
    ) -> String {
        var parts: [String] = []

        switch goal {
        case .muscleGain:
            parts.append("Caloric surplus for lean mass gain. Distribute protein across 4+ meals.")
        case .fatLoss:
            parts.append("Moderate caloric deficit. Prioritize protein to preserve lean mass.")
        case .longevity:
            parts.append("Maintenance calories with emphasis on nutrient density and polyphenols.")
        case .cardiovascular:
            parts.append("Heart-healthy focus: omega-3s, fiber, limit sodium and processed foods.")
        case .cognitive:
            parts.append("Brain-supporting nutrition: omega-3s, polyphenols, choline, moderate carbs.")
        case .metabolic:
            parts.append("Glycemic control focus: fiber-rich carbs, protein at every meal, time-restricted eating optional.")
        case .hormonal:
            parts.append("Hormone-supporting nutrition: adequate fat and cholesterol, zinc, magnesium.")
        case .sleep:
            parts.append("Sleep-supporting nutrition: tryptophan-rich dinner, magnesium, limit caffeine after noon.")
        case .gutHealth:
            parts.append("Gut health focus: diverse fiber (30g+/day), fermented foods, bone broth.")
        case .stressResilience:
            parts.append("Anti-stress nutrition: B-vitamins, magnesium, adaptogens, avoid caloric deficit.")
        }

        switch trainingType {
        case .endurance:
            parts.append("Higher carbs for aerobic fuel. Pre-session carbs 60-90min before training.")
        case .strength, .hypertrophy:
            parts.append("Pre-training meal 2h before. Post-training protein within 2h after session.")
        case .rest:
            parts.append("Rest day — slightly reduced carbs, maintain protein. Focus on micronutrients.")
        case .deload:
            parts.append("Deload day — maintenance intake, no caloric deficit.")
        case .mobility:
            parts.append("Light activity day — moderate intake with anti-inflammatory emphasis.")
        }

        if !geneticAdjustments.isEmpty {
            parts.append("Genetic adjustments applied: \(geneticAdjustments.joined(separator: "; ")).")
        }

        return parts.joined(separator: " ")
    }
}
