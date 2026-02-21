// CircaseptanEngine.swift
// OutliveEngine
//
// Plans a 7-day training cycle (circaseptan rhythm) based on the user's
// health goals and current recovery zone. Fully deterministic.

import Foundation

// MARK: - Output Types

struct WeeklyPlan: Sendable, Codable, Hashable {
    let days: [DayPlan]
}

struct DayPlan: Sendable, Codable, Hashable {
    let dayNumber: Int           // 1–7
    let trainingFocus: TrainingType
    let nutritionFocus: String
    let isRecoveryDay: Bool
}

// MARK: - Engine

struct CircaseptanEngine: Sendable {

    // MARK: - Public API

    /// Plans a 7-day training cycle starting from `currentDay` (1–7).
    /// If recovery is degraded, the plan shifts training days to recovery.
    func planWeek(
        goals: [HealthGoal],
        currentDay: Int,
        recoveryZone: RecoveryZone
    ) -> WeeklyPlan {
        let primaryGoal = goals.first ?? .longevity
        let baseCycle = baseCycle(for: primaryGoal)
        let adjusted = applyRecoveryOverrides(baseCycle, currentDay: currentDay, zone: recoveryZone)
        return WeeklyPlan(days: adjusted)
    }

    // MARK: - Base Cycles

    /// Returns the default 7-day cycle template for a given primary goal.
    private func baseCycle(for goal: HealthGoal) -> [DayPlan] {
        switch goal {

        case .muscleGain:
            return [
                DayPlan(dayNumber: 1, trainingFocus: .strength,    nutritionFocus: "High protein, caloric surplus, pre-workout carbs",   isRecoveryDay: false),
                DayPlan(dayNumber: 2, trainingFocus: .hypertrophy, nutritionFocus: "High protein, moderate carbs for volume work",        isRecoveryDay: false),
                DayPlan(dayNumber: 3, trainingFocus: .hypertrophy, nutritionFocus: "High protein, emphasize post-workout nutrition",      isRecoveryDay: false),
                DayPlan(dayNumber: 4, trainingFocus: .mobility,    nutritionFocus: "Moderate calories, anti-inflammatory foods, hydrate", isRecoveryDay: true),
                DayPlan(dayNumber: 5, trainingFocus: .strength,    nutritionFocus: "High protein, caloric surplus, creatine timing",      isRecoveryDay: false),
                DayPlan(dayNumber: 6, trainingFocus: .hypertrophy, nutritionFocus: "High protein, higher carbs for volume",               isRecoveryDay: false),
                DayPlan(dayNumber: 7, trainingFocus: .rest,        nutritionFocus: "Maintenance calories, focus on micronutrient density", isRecoveryDay: true),
            ]

        case .fatLoss:
            return [
                DayPlan(dayNumber: 1, trainingFocus: .strength,    nutritionFocus: "High protein, moderate deficit, pre-workout carbs",    isRecoveryDay: false),
                DayPlan(dayNumber: 2, trainingFocus: .endurance,   nutritionFocus: "Moderate carbs for Zone 2, caloric deficit",           isRecoveryDay: false),
                DayPlan(dayNumber: 3, trainingFocus: .hypertrophy, nutritionFocus: "High protein to preserve muscle, moderate deficit",    isRecoveryDay: false),
                DayPlan(dayNumber: 4, trainingFocus: .mobility,    nutritionFocus: "Light deficit, anti-inflammatory focus, hydration",    isRecoveryDay: true),
                DayPlan(dayNumber: 5, trainingFocus: .strength,    nutritionFocus: "High protein, moderate deficit",                       isRecoveryDay: false),
                DayPlan(dayNumber: 6, trainingFocus: .endurance,   nutritionFocus: "Fasted-friendly cardio, refeed carbs post-session",    isRecoveryDay: false),
                DayPlan(dayNumber: 7, trainingFocus: .rest,        nutritionFocus: "Maintenance or slight deficit, nutrient-dense meals",  isRecoveryDay: true),
            ]

        case .cardiovascular:
            return [
                DayPlan(dayNumber: 1, trainingFocus: .endurance,   nutritionFocus: "Higher carbs for aerobic work, moderate protein",     isRecoveryDay: false),
                DayPlan(dayNumber: 2, trainingFocus: .strength,    nutritionFocus: "High protein, moderate carbs",                        isRecoveryDay: false),
                DayPlan(dayNumber: 3, trainingFocus: .endurance,   nutritionFocus: "Carb-focused for Zone 2 session",                     isRecoveryDay: false),
                DayPlan(dayNumber: 4, trainingFocus: .mobility,    nutritionFocus: "Anti-inflammatory foods, omega-3 emphasis",           isRecoveryDay: true),
                DayPlan(dayNumber: 5, trainingFocus: .endurance,   nutritionFocus: "Higher carbs, electrolyte focus",                     isRecoveryDay: false),
                DayPlan(dayNumber: 6, trainingFocus: .strength,    nutritionFocus: "Balanced macros, adequate protein",                   isRecoveryDay: false),
                DayPlan(dayNumber: 7, trainingFocus: .rest,        nutritionFocus: "Maintenance calories, micronutrient density",         isRecoveryDay: true),
            ]

        case .longevity:
            return [
                DayPlan(dayNumber: 1, trainingFocus: .strength,    nutritionFocus: "High protein for mTOR stimulus, whole foods",              isRecoveryDay: false),
                DayPlan(dayNumber: 2, trainingFocus: .endurance,   nutritionFocus: "Zone 2 fuel — moderate carbs, polyphenol-rich foods",      isRecoveryDay: false),
                DayPlan(dayNumber: 3, trainingFocus: .hypertrophy, nutritionFocus: "High protein, colorful vegetables, anti-inflammatory",     isRecoveryDay: false),
                DayPlan(dayNumber: 4, trainingFocus: .mobility,    nutritionFocus: "Lighter intake, emphasize autophagy-supporting nutrients", isRecoveryDay: true),
                DayPlan(dayNumber: 5, trainingFocus: .endurance,   nutritionFocus: "Zone 2 session, Mediterranean-style meals",                isRecoveryDay: false),
                DayPlan(dayNumber: 6, trainingFocus: .strength,    nutritionFocus: "High protein, cruciferous vegetables, healthy fats",       isRecoveryDay: false),
                DayPlan(dayNumber: 7, trainingFocus: .rest,        nutritionFocus: "Maintenance calories, focus on sleep-supporting foods",    isRecoveryDay: true),
            ]

        case .cognitive:
            return [
                DayPlan(dayNumber: 1, trainingFocus: .endurance,   nutritionFocus: "Omega-3 rich, blueberries, dark chocolate, Zone 2 fuel",  isRecoveryDay: false),
                DayPlan(dayNumber: 2, trainingFocus: .strength,    nutritionFocus: "High protein, BDNF-supporting nutrients",                  isRecoveryDay: false),
                DayPlan(dayNumber: 3, trainingFocus: .endurance,   nutritionFocus: "Complex carbs for brain fuel, polyphenols",                isRecoveryDay: false),
                DayPlan(dayNumber: 4, trainingFocus: .mobility,    nutritionFocus: "Anti-inflammatory focus, turmeric, green tea",             isRecoveryDay: true),
                DayPlan(dayNumber: 5, trainingFocus: .strength,    nutritionFocus: "High protein, choline-rich foods (eggs, liver)",            isRecoveryDay: false),
                DayPlan(dayNumber: 6, trainingFocus: .endurance,   nutritionFocus: "Mediterranean-style, fermented foods for gut-brain axis",  isRecoveryDay: false),
                DayPlan(dayNumber: 7, trainingFocus: .rest,        nutritionFocus: "Light eating, sleep-optimizing foods, magnesium",          isRecoveryDay: true),
            ]

        case .metabolic:
            return [
                DayPlan(dayNumber: 1, trainingFocus: .strength,    nutritionFocus: "High protein, low glycemic carbs, insulin sensitivity focus", isRecoveryDay: false),
                DayPlan(dayNumber: 2, trainingFocus: .endurance,   nutritionFocus: "Zone 2 for mitochondrial health, moderate carbs",              isRecoveryDay: false),
                DayPlan(dayNumber: 3, trainingFocus: .hypertrophy, nutritionFocus: "High protein, timed carbs around training",                    isRecoveryDay: false),
                DayPlan(dayNumber: 4, trainingFocus: .mobility,    nutritionFocus: "Lower carb, anti-inflammatory, berberine-friendly timing",     isRecoveryDay: true),
                DayPlan(dayNumber: 5, trainingFocus: .endurance,   nutritionFocus: "Zone 2 session, emphasis on fiber and complex carbs",           isRecoveryDay: false),
                DayPlan(dayNumber: 6, trainingFocus: .strength,    nutritionFocus: "High protein, chromium and magnesium-rich foods",               isRecoveryDay: false),
                DayPlan(dayNumber: 7, trainingFocus: .rest,        nutritionFocus: "Maintenance, blood sugar-stabilizing meals",                   isRecoveryDay: true),
            ]

        case .hormonal:
            return [
                DayPlan(dayNumber: 1, trainingFocus: .strength,    nutritionFocus: "High protein, zinc-rich foods, healthy fats",             isRecoveryDay: false),
                DayPlan(dayNumber: 2, trainingFocus: .endurance,   nutritionFocus: "Moderate intensity, avoid overtraining, balanced macros",  isRecoveryDay: false),
                DayPlan(dayNumber: 3, trainingFocus: .hypertrophy, nutritionFocus: "Caloric surplus, emphasize cholesterol precursors",        isRecoveryDay: false),
                DayPlan(dayNumber: 4, trainingFocus: .mobility,    nutritionFocus: "Stress-reducing foods, adaptogens, magnesium",            isRecoveryDay: true),
                DayPlan(dayNumber: 5, trainingFocus: .strength,    nutritionFocus: "High protein, adequate dietary fat for hormone synthesis", isRecoveryDay: false),
                DayPlan(dayNumber: 6, trainingFocus: .mobility,    nutritionFocus: "Active recovery, anti-inflammatory, sleep focus",          isRecoveryDay: true),
                DayPlan(dayNumber: 7, trainingFocus: .rest,        nutritionFocus: "Rest and hormonal recovery, nutrient-dense meals",        isRecoveryDay: true),
            ]

        case .sleep:
            return [
                DayPlan(dayNumber: 1, trainingFocus: .strength,    nutritionFocus: "Morning training preferred, avoid late caffeine",              isRecoveryDay: false),
                DayPlan(dayNumber: 2, trainingFocus: .endurance,   nutritionFocus: "Zone 2 morning session, tryptophan-rich dinner",               isRecoveryDay: false),
                DayPlan(dayNumber: 3, trainingFocus: .hypertrophy, nutritionFocus: "Moderate volume, magnesium-rich foods at dinner",              isRecoveryDay: false),
                DayPlan(dayNumber: 4, trainingFocus: .mobility,    nutritionFocus: "Gentle yoga/stretching, chamomile, glycine-rich foods",        isRecoveryDay: true),
                DayPlan(dayNumber: 5, trainingFocus: .strength,    nutritionFocus: "Morning training, tart cherry juice in evening",               isRecoveryDay: false),
                DayPlan(dayNumber: 6, trainingFocus: .endurance,   nutritionFocus: "Light cardio, avoid heavy meals 3h before bed",                isRecoveryDay: false),
                DayPlan(dayNumber: 7, trainingFocus: .rest,        nutritionFocus: "Complete rest, sleep hygiene focus, no screens after sunset",   isRecoveryDay: true),
            ]

        case .gutHealth:
            return [
                DayPlan(dayNumber: 1, trainingFocus: .strength,    nutritionFocus: "High fiber, fermented foods, bone broth",                 isRecoveryDay: false),
                DayPlan(dayNumber: 2, trainingFocus: .endurance,   nutritionFocus: "Zone 2 supports gut motility, prebiotic-rich meals",       isRecoveryDay: false),
                DayPlan(dayNumber: 3, trainingFocus: .hypertrophy, nutritionFocus: "Diverse plant fibers, probiotic foods, adequate protein",  isRecoveryDay: false),
                DayPlan(dayNumber: 4, trainingFocus: .mobility,    nutritionFocus: "Gut-rest day, simple foods, bone broth, slippery elm",    isRecoveryDay: true),
                DayPlan(dayNumber: 5, trainingFocus: .strength,    nutritionFocus: "Polyphenol-rich foods, fermented vegetables",              isRecoveryDay: false),
                DayPlan(dayNumber: 6, trainingFocus: .endurance,   nutritionFocus: "Diverse fiber sources, resistant starch",                  isRecoveryDay: false),
                DayPlan(dayNumber: 7, trainingFocus: .rest,        nutritionFocus: "Digestive rest, simple meals, herbal teas",               isRecoveryDay: true),
            ]

        case .stressResilience:
            return [
                DayPlan(dayNumber: 1, trainingFocus: .strength,    nutritionFocus: "Balanced macros, adaptogenic herbs, adequate calories",    isRecoveryDay: false),
                DayPlan(dayNumber: 2, trainingFocus: .endurance,   nutritionFocus: "Zone 2 for vagal tone, magnesium and B-vitamin focus",     isRecoveryDay: false),
                DayPlan(dayNumber: 3, trainingFocus: .mobility,    nutritionFocus: "Yoga/breathwork day, calming foods, ashwagandha timing",  isRecoveryDay: true),
                DayPlan(dayNumber: 4, trainingFocus: .strength,    nutritionFocus: "Moderate intensity, omega-3 emphasis",                     isRecoveryDay: false),
                DayPlan(dayNumber: 5, trainingFocus: .endurance,   nutritionFocus: "Zone 2, phosphatidylserine timing, anti-stress nutrients", isRecoveryDay: false),
                DayPlan(dayNumber: 6, trainingFocus: .mobility,    nutritionFocus: "Active recovery, social meals, mindful eating",            isRecoveryDay: true),
                DayPlan(dayNumber: 7, trainingFocus: .rest,        nutritionFocus: "Complete rest, nature exposure, nourishing comfort meals", isRecoveryDay: true),
            ]
        }
    }

    // MARK: - Recovery Overrides

    /// Applies recovery-based overrides to the weekly plan. If recovery is
    /// degraded on the current day, that day (and possibly adjacent days)
    /// shift to recovery.
    private func applyRecoveryOverrides(
        _ baseDays: [DayPlan],
        currentDay: Int,
        zone: RecoveryZone
    ) -> [DayPlan] {
        let clampedDay = max(1, min(currentDay, 7))

        switch zone {
        case .green:
            // No modifications — execute plan as designed
            return baseDays

        case .yellow:
            // Downgrade current day if it's a hard session
            return baseDays.map { day in
                guard day.dayNumber == clampedDay, !day.isRecoveryDay else { return day }
                return downgradeDay(day)
            }

        case .red:
            // Current day becomes rest, next day becomes mobility
            return baseDays.map { day in
                if day.dayNumber == clampedDay {
                    return DayPlan(
                        dayNumber: day.dayNumber,
                        trainingFocus: .rest,
                        nutritionFocus: "Recovery nutrition: anti-inflammatory, adequate protein, extra hydration",
                        isRecoveryDay: true
                    )
                }
                let nextDay = clampedDay < 7 ? clampedDay + 1 : 1
                if day.dayNumber == nextDay && !day.isRecoveryDay {
                    return DayPlan(
                        dayNumber: day.dayNumber,
                        trainingFocus: .mobility,
                        nutritionFocus: "Gentle recovery nutrition, focus on sleep-supporting foods",
                        isRecoveryDay: true
                    )
                }
                return day
            }
        }
    }

    /// Downgrades a training day to a lighter version for yellow-zone recovery.
    private func downgradeDay(_ day: DayPlan) -> DayPlan {
        let downgradedType: TrainingType
        switch day.trainingFocus {
        case .strength:
            downgradedType = .deload
        case .hypertrophy:
            downgradedType = .deload
        case .endurance:
            downgradedType = .endurance // Keep Zone 2 but lighter
        case .mobility, .deload, .rest:
            downgradedType = day.trainingFocus
        }
        return DayPlan(
            dayNumber: day.dayNumber,
            trainingFocus: downgradedType,
            nutritionFocus: "Recovery-adjusted: maintain protein, reduce surplus, anti-inflammatory focus",
            isRecoveryDay: downgradedType == .rest || downgradedType == .mobility
        )
    }
}
