// ProtocolSynthesizer.swift
// OutliveEngine
//
// The main orchestrator that synthesizes a complete daily protocol by
// coordinating all engine components. Fully deterministic — same inputs
// always produce the same output.
//
// Pipeline: GeneticRiskMapper → BiomarkerAnalyzer → RecoveryAdaptor
//         → CircaseptanEngine → MealPlanner → ConflictResolver

import Foundation

// MARK: - Input Types (SwiftData-free mirrors)

struct UserProfileInput: Sendable, Codable, Hashable {
    let goals: [HealthGoal]
    let allergies: [String]
    let dietaryRestrictions: [String]
    let biologicalSex: String?
    let birthDate: Date?
    let heightCm: Double?
}

struct GenomicsInput: Sendable, Codable, Hashable {
    let risks: [GeneticRisk]
}

struct BloodworkInput: Sendable, Codable, Hashable {
    let markers: [BloodworkMarker]
    let labDate: Date
    let previousMarkers: [BloodworkMarker]?
}

struct WearableInput: Sendable, Codable, Hashable {
    let hrvMs: Double?
    let restingHR: Int?
    let sleepHours: Double?
    let deepSleepMinutes: Int?
    let remSleepMinutes: Int?
    let recoveryScore: Double?
    let strain: Double?
}

struct BodyCompInput: Sendable, Codable, Hashable {
    let weightKg: Double
    let bodyFatPercent: Double?
    let muscleMassKg: Double?
}

// MARK: - Output Type

struct SynthesizedProtocol: Sendable, Codable, Hashable {
    let recoveryZone: RecoveryZone
    let training: TrainingBlock?
    let nutrition: NutritionPlan?
    let supplements: [SupplementDose]
    let interventions: [InterventionBlock]
    let sleep: SleepProtocol?
    let insights: [String]
}

// MARK: - Engine

struct ProtocolSynthesizer: Sendable {

    // Sub-engines
    private let geneticMapper = GeneticRiskMapper()
    private let biomarkerAnalyzer = BiomarkerAnalyzer()
    private let recoveryAdaptor = RecoveryAdaptor()
    private let circaseptanEngine = CircaseptanEngine()
    private let mealPlanner = MealPlanner()
    private let conflictResolver = ConflictResolver()

    // MARK: - Public API

    /// Synthesizes a complete daily protocol from all available user data.
    func synthesize(
        profile: UserProfileInput,
        genomics: GenomicsInput?,
        bloodwork: BloodworkInput?,
        wearable: WearableInput?,
        bodyComp: BodyCompInput?,
        date: Date
    ) -> SynthesizedProtocol {

        var insights: [String] = []

        // ── Step 1: Map Genetic Risks ────────────────────────────
        let geneticRisks: [RiskCategory: GeneticRiskAssessment]
        if let genomics, !genomics.risks.isEmpty {
            geneticRisks = geneticMapper.mapRisks(genomics.risks)
            let highRiskCategories = geneticRisks.filter { $0.value.riskLevel >= 0.6 }
            if !highRiskCategories.isEmpty {
                let names = highRiskCategories.keys.map { $0.rawValue.uppercased() }.sorted()
                insights.append("Elevated genetic risk factors active: \(names.joined(separator: ", "))")
            }
        } else {
            geneticRisks = [:]
            insights.append("No genomic data available — using population-level defaults")
        }

        // ── Step 2: Analyze Bloodwork ────────────────────────────
        var bloodworkInsights: [BiomarkerInsight] = []
        var bloodworkTrends: [BiomarkerTrend] = []
        if let bloodwork, !bloodwork.markers.isEmpty {
            bloodworkInsights = biomarkerAnalyzer.analyze(bloodwork.markers)
            if let previous = bloodwork.previousMarkers, !previous.isEmpty {
                bloodworkTrends = biomarkerAnalyzer.trends(
                    current: bloodwork.markers, previous: previous
                )
            }
            let criticalMarkers = bloodworkInsights.filter { $0.status == .critical }
            if !criticalMarkers.isEmpty {
                let names = criticalMarkers.map { $0.markerName }.joined(separator: ", ")
                insights.append("CRITICAL biomarkers requiring attention: \(names)")
            }
            let suboptimalCount = bloodworkInsights.filter { $0.status == .suboptimal }.count
            if suboptimalCount > 0 {
                insights.append("\(suboptimalCount) biomarker(s) in suboptimal range")
            }
            let improvingCount = bloodworkTrends.filter { $0.direction == .improving }.count
            let decliningCount = bloodworkTrends.filter { $0.direction == .declining }.count
            if improvingCount > 0 || decliningCount > 0 {
                insights.append("Trends: \(improvingCount) improving, \(decliningCount) declining since last panel")
            }
        } else {
            insights.append("No bloodwork data — supplement recommendations based on goals and genetics only")
        }

        // ── Step 3: Assess Recovery ──────────────────────────────
        let recoveryAssessment: RecoveryAssessment
        if let wearable {
            recoveryAssessment = recoveryAdaptor.assessRecovery(
                hrv: wearable.hrvMs,
                restingHR: wearable.restingHR,
                sleepHours: wearable.sleepHours,
                deepSleep: wearable.deepSleepMinutes,
                recoveryScore: wearable.recoveryScore,
                strain: wearable.strain
            )
            insights.append("Recovery: \(recoveryAssessment.zone.rawValue.uppercased()) zone (confidence: \(Int(recoveryAssessment.confidence * 100))%)")
            insights.append(contentsOf: recoveryAssessment.recommendations)
        } else {
            recoveryAssessment = RecoveryAssessment(
                zone: .yellow,
                confidence: 0.0,
                trainingIntensityModifier: 0.7,
                recommendations: ["No wearable data — defaulting to moderate intensity"]
            )
            insights.append("No wearable data — defaulting to YELLOW recovery zone")
        }

        // ── Step 4: Plan Weekly Cycle ────────────────────────────
        let dayOfWeek = dayNumber(from: date)
        let weeklyPlan = circaseptanEngine.planWeek(
            goals: profile.goals,
            currentDay: dayOfWeek,
            recoveryZone: recoveryAssessment.zone
        )
        let todayPlan = weeklyPlan.days.first { $0.dayNumber == dayOfWeek }
            ?? weeklyPlan.days.first
            ?? DayPlan(dayNumber: dayOfWeek, trainingFocus: .rest, nutritionFocus: "Maintenance", isRecoveryDay: true)

        insights.append("Day \(dayOfWeek)/7: \(todayPlan.trainingFocus.rawValue) — \(todayPlan.nutritionFocus)")

        // ── Step 5: Build Training Block ─────────────────────────
        let trainingBlock = buildTrainingBlock(
            focus: todayPlan.trainingFocus,
            intensityModifier: recoveryAssessment.trainingIntensityModifier,
            isRecoveryDay: todayPlan.isRecoveryDay
        )

        // ── Step 6: Plan Nutrition ───────────────────────────────
        let weight = bodyComp?.weightKg ?? 75.0 // fallback
        let bf = bodyComp?.bodyFatPercent
        let geneticDietaryAdjustments = geneticRisks.values.flatMap { $0.dietaryAdjustments }

        let nutritionPlan = mealPlanner.plan(
            weightKg: weight,
            bodyFatPercent: bf,
            goals: profile.goals,
            trainingType: todayPlan.trainingFocus,
            allergies: profile.allergies,
            dietaryRestrictions: profile.dietaryRestrictions,
            geneticAdjustments: geneticDietaryAdjustments
        )

        // ── Step 7: Build Supplement Stack ───────────────────────
        var supplements = buildSupplementStack(
            goals: profile.goals,
            geneticRisks: geneticRisks,
            bloodworkInsights: bloodworkInsights
        )

        // ── Step 8: Build Interventions ──────────────────────────
        let interventions = buildInterventions(
            recoveryZone: recoveryAssessment.zone,
            goals: profile.goals
        )

        // ── Step 9: Build Sleep Protocol ─────────────────────────
        let sleepProtocol = buildSleepProtocol(
            recoveryZone: recoveryAssessment.zone,
            wearable: wearable
        )

        // ── Step 10: Resolve Conflicts ───────────────────────────
        let resolved = conflictResolver.resolve(
            training: trainingBlock,
            nutrition: nutritionPlan,
            supplements: supplements,
            geneticRisks: geneticRisks,
            recoveryZone: recoveryAssessment.zone,
            allergies: profile.allergies
        )

        // Add conflict notes to insights
        for conflict in resolved.conflicts {
            insights.append("Conflict resolved (P\(conflict.priority)): \(conflict.resolution)")
        }

        return SynthesizedProtocol(
            recoveryZone: recoveryAssessment.zone,
            training: resolved.training,
            nutrition: resolved.nutrition,
            supplements: resolved.supplements,
            interventions: interventions,
            sleep: sleepProtocol,
            insights: insights
        )
    }

    // MARK: - Day of Week

    /// Returns 1–7 (Monday=1, Sunday=7) from a date.
    private func dayNumber(from date: Date) -> Int {
        let calendar = Calendar(identifier: .iso8601)
        let weekday = calendar.component(.weekday, from: date)
        // Calendar.weekday: 1=Sunday, 2=Monday, ..., 7=Saturday
        // Convert to: 1=Monday, ..., 7=Sunday
        return weekday == 1 ? 7 : weekday - 1
    }

    // MARK: - Training Block Builder

    private func buildTrainingBlock(
        focus: TrainingType,
        intensityModifier: Double,
        isRecoveryDay: Bool
    ) -> TrainingBlock {
        let baseRPE: Double
        let exercises: [Exercise]
        let duration: Int

        switch focus {
        case .strength:
            baseRPE = 8.0
            duration = 60
            exercises = [
                Exercise(name: "Barbell Back Squat", sets: 4, reps: "5", weight: nil, notes: "Compound lower body strength"),
                Exercise(name: "Bench Press", sets: 4, reps: "5", weight: nil, notes: "Horizontal press"),
                Exercise(name: "Barbell Row", sets: 4, reps: "5", weight: nil, notes: "Horizontal pull"),
                Exercise(name: "Overhead Press", sets: 3, reps: "6", weight: nil, notes: "Vertical press"),
                Exercise(name: "Weighted Pull-ups", sets: 3, reps: "5", weight: nil, notes: "Vertical pull"),
            ]

        case .hypertrophy:
            baseRPE = 7.5
            duration = 55
            exercises = [
                Exercise(name: "Dumbbell Bulgarian Split Squat", sets: 3, reps: "10-12", weight: nil, notes: "Unilateral leg work"),
                Exercise(name: "Incline Dumbbell Press", sets: 3, reps: "10-12", weight: nil, notes: "Upper chest emphasis"),
                Exercise(name: "Cable Row", sets: 3, reps: "10-12", weight: nil, notes: "Back thickness"),
                Exercise(name: "Lateral Raises", sets: 3, reps: "12-15", weight: nil, notes: "Shoulder width"),
                Exercise(name: "Bicep Curls", sets: 2, reps: "12-15", weight: nil, notes: "Arm isolation"),
                Exercise(name: "Tricep Pushdowns", sets: 2, reps: "12-15", weight: nil, notes: "Arm isolation"),
            ]

        case .endurance:
            baseRPE = 5.0
            duration = 45
            exercises = [
                Exercise(name: "Zone 2 Cardio (run, bike, row, or swim)", sets: 1, reps: "30-45 min", weight: nil, notes: "Nasal breathing, conversational pace, HR 60-70% max"),
                Exercise(name: "Core Circuit", sets: 2, reps: "10 min", weight: nil, notes: "Planks, dead bugs, bird dogs"),
            ]

        case .mobility:
            baseRPE = 3.0
            duration = 40
            exercises = [
                Exercise(name: "Foam Rolling", sets: 1, reps: "10 min", weight: nil, notes: "Full body, focus on tight areas"),
                Exercise(name: "Hip 90/90 Stretch", sets: 2, reps: "60s each side", weight: nil, notes: nil),
                Exercise(name: "Thoracic Spine Extension", sets: 2, reps: "60s", weight: nil, notes: nil),
                Exercise(name: "World's Greatest Stretch", sets: 2, reps: "5 each side", weight: nil, notes: nil),
                Exercise(name: "Controlled Articular Rotations", sets: 1, reps: "5 each joint", weight: nil, notes: "Shoulders, hips, ankles"),
            ]

        case .deload:
            baseRPE = 5.0
            duration = 40
            exercises = [
                Exercise(name: "Goblet Squat", sets: 3, reps: "8", weight: nil, notes: "50-60% normal load"),
                Exercise(name: "Push-ups", sets: 3, reps: "10", weight: nil, notes: "Bodyweight only"),
                Exercise(name: "Band Pull-aparts", sets: 3, reps: "15", weight: nil, notes: "Light resistance"),
                Exercise(name: "Walking Lunges", sets: 2, reps: "10 each leg", weight: nil, notes: "Bodyweight"),
            ]

        case .rest:
            baseRPE = 2.0
            duration = 30
            exercises = [
                Exercise(name: "Gentle Walking", sets: 1, reps: "20 min", weight: nil, notes: "Outdoor if possible, easy pace"),
                Exercise(name: "Light Stretching", sets: 1, reps: "10 min", weight: nil, notes: "Full body, no forcing range of motion"),
            ]
        }

        let adjustedRPE = (baseRPE * intensityModifier * 10).rounded() / 10

        return TrainingBlock(
            type: focus,
            exercises: exercises,
            duration: duration,
            rpeTarget: adjustedRPE,
            notes: isRecoveryDay ? "Recovery day — focus on movement quality over intensity" : nil
        )
    }

    // MARK: - Supplement Stack Builder

    private func buildSupplementStack(
        goals: [HealthGoal],
        geneticRisks: [RiskCategory: GeneticRiskAssessment],
        bloodworkInsights: [BiomarkerInsight]
    ) -> [SupplementDose] {
        var stack: [SupplementDose] = []

        // ── Universal Foundation Stack ────────────────────────────
        stack.append(SupplementDose(
            name: "Vitamin D3", dose: "2000 IU", timing: .withBreakfast,
            rationale: "Baseline vitamin D support for immune and bone health"
        ))
        stack.append(SupplementDose(
            name: "Magnesium Glycinate", dose: "200mg", timing: .preBed,
            rationale: "Sleep quality, muscle recovery, 300+ enzymatic reactions"
        ))

        // ── Goal-Specific Supplements ─────────────────────────────
        let goalSet = Set(goals)

        if goalSet.contains(.longevity) {
            stack.append(SupplementDose(
                name: "Omega-3 (EPA/DHA)", dose: "2g", timing: .withBreakfast,
                rationale: "Anti-inflammatory, cardiovascular, cognitive support"
            ))
            stack.append(SupplementDose(
                name: "Vitamin K2 (MK-7)", dose: "200mcg", timing: .withBreakfast,
                rationale: "Calcium metabolism, works synergistically with vitamin D"
            ))
            stack.append(SupplementDose(
                name: "Magnesium Glycinate", dose: "200mg", timing: .withDinner,
                rationale: "Additional magnesium for longevity protocol (total 400mg/day)"
            ))
        }

        if goalSet.contains(.muscleGain) {
            stack.append(SupplementDose(
                name: "Creatine Monohydrate", dose: "5g", timing: .withBreakfast,
                rationale: "Muscle strength, power output, cellular energy"
            ))
            stack.append(SupplementDose(
                name: "Whey Protein", dose: "25g", timing: .afternoon,
                rationale: "Post-training protein synthesis support"
            ))
        }

        if goalSet.contains(.fatLoss) {
            stack.append(SupplementDose(
                name: "Omega-3 (EPA/DHA)", dose: "2g", timing: .withBreakfast,
                rationale: "Anti-inflammatory support during caloric deficit"
            ))
        }

        if goalSet.contains(.cardiovascular) {
            stack.append(SupplementDose(
                name: "Omega-3 (EPA/DHA)", dose: "2g", timing: .withBreakfast,
                rationale: "Cardiovascular protection, triglyceride management"
            ))
            stack.append(SupplementDose(
                name: "CoQ10", dose: "200mg", timing: .withBreakfast,
                rationale: "Mitochondrial energy, cardiovascular support"
            ))
        }

        if goalSet.contains(.cognitive) {
            stack.append(SupplementDose(
                name: "Omega-3 (EPA/DHA)", dose: "2g", timing: .withBreakfast,
                rationale: "DHA for neuronal membrane integrity"
            ))
            stack.append(SupplementDose(
                name: "Lions Mane", dose: "1000mg", timing: .withBreakfast,
                rationale: "Nerve growth factor support, cognitive function"
            ))
            stack.append(SupplementDose(
                name: "Phosphatidylserine", dose: "100mg", timing: .withDinner,
                rationale: "Cognitive support and cortisol modulation"
            ))
        }

        if goalSet.contains(.sleep) {
            stack.append(SupplementDose(
                name: "Magnesium Glycinate", dose: "200mg", timing: .preBed,
                rationale: "Additional magnesium for sleep protocol"
            ))
            stack.append(SupplementDose(
                name: "L-Theanine", dose: "200mg", timing: .preBed,
                rationale: "Promotes relaxation without sedation, improves sleep quality"
            ))
            stack.append(SupplementDose(
                name: "Glycine", dose: "3g", timing: .preBed,
                rationale: "Lowers core body temperature, improves sleep onset"
            ))
        }

        if goalSet.contains(.metabolic) {
            stack.append(SupplementDose(
                name: "Berberine", dose: "500mg", timing: .withDinner,
                rationale: "Glucose metabolism and insulin sensitivity support"
            ))
            stack.append(SupplementDose(
                name: "Chromium Picolinate", dose: "200mcg", timing: .withLunch,
                rationale: "Insulin signaling support"
            ))
        }

        if goalSet.contains(.hormonal) {
            stack.append(SupplementDose(
                name: "Zinc Picolinate", dose: "30mg", timing: .withDinner,
                rationale: "Testosterone and hormone synthesis support"
            ))
            stack.append(SupplementDose(
                name: "Ashwagandha (KSM-66)", dose: "600mg", timing: .withDinner,
                rationale: "Cortisol modulation, testosterone support"
            ))
            stack.append(SupplementDose(
                name: "Boron", dose: "6mg", timing: .withBreakfast,
                rationale: "Free testosterone support, reduces SHBG"
            ))
        }

        if goalSet.contains(.gutHealth) {
            stack.append(SupplementDose(
                name: "Probiotic (Multi-strain)", dose: "50 billion CFU", timing: .waking,
                rationale: "Gut microbiome diversity and barrier function"
            ))
            stack.append(SupplementDose(
                name: "L-Glutamine", dose: "5g", timing: .waking,
                rationale: "Intestinal lining repair and gut barrier support"
            ))
        }

        if goalSet.contains(.stressResilience) {
            stack.append(SupplementDose(
                name: "Ashwagandha (KSM-66)", dose: "600mg", timing: .withDinner,
                rationale: "Adaptogenic stress response modulation"
            ))
            stack.append(SupplementDose(
                name: "L-Theanine", dose: "200mg", timing: .midMorning,
                rationale: "Promotes calm alertness, reduces stress reactivity"
            ))
        }

        // ── Genetic-Specific Additions ────────────────────────────
        for (_, assessment) in geneticRisks where assessment.riskLevel >= 0.5 {
            for rec in assessment.supplementRecommendations {
                // Only add if not already covered
                let recLower = rec.lowercased()
                let alreadyHas = stack.contains { $0.name.lowercased().contains(recLower.prefix(10)) }
                if !alreadyHas {
                    // Extract dose and name from recommendation string
                    let parts = rec.components(separatedBy: " ")
                    let name = parts.prefix(while: { !$0.contains("mg") && !$0.contains("mcg")
                        && !$0.contains("IU") && !$0.contains("g/") }).joined(separator: " ")
                    let dose = parts.drop(while: { !$0.contains("mg") && !$0.contains("mcg")
                        && !$0.contains("IU") && !$0.contains("g/") }).prefix(1).joined(separator: " ")

                    if !name.isEmpty {
                        stack.append(SupplementDose(
                            name: name.isEmpty ? rec : name,
                            dose: dose.isEmpty ? "per genetic recommendation" : dose,
                            timing: .withBreakfast,
                            rationale: "Genetic risk profile recommendation"
                        ))
                    }
                }
            }
        }

        // ── Bloodwork-Driven Additions ────────────────────────────
        for insight in bloodworkInsights where insight.status == .critical || insight.status == .suboptimal {
            let name = insight.markerName.lowercased()
            if name.contains("vitamin d") && !stack.contains(where: { $0.name.lowercased().contains("vitamin d") && $0.dose.contains("5000") }) {
                // Upgrade vitamin D dose
                stack = stack.map { supplement in
                    if supplement.name.lowercased().contains("vitamin d") {
                        return SupplementDose(
                            name: "Vitamin D3", dose: "5000 IU", timing: .withBreakfast,
                            rationale: "Elevated dose — bloodwork shows suboptimal/critical levels"
                        )
                    }
                    return supplement
                }
            }
            if name.contains("b12") {
                stack.append(SupplementDose(
                    name: "Methylcobalamin (B12)", dose: "1000mcg", timing: .withBreakfast,
                    rationale: "Bloodwork indicates low B12 — supplementation recommended"
                ))
            }
            if name.contains("ferritin") && insight.status == .suboptimal {
                stack.append(SupplementDose(
                    name: "Iron Bisglycinate", dose: "25mg", timing: .withLunch,
                    rationale: "Bloodwork indicates low ferritin — take with vitamin C for absorption"
                ))
            }
        }

        return stack
    }

    // MARK: - Interventions Builder

    private func buildInterventions(
        recoveryZone: RecoveryZone,
        goals: [HealthGoal]
    ) -> [InterventionBlock] {
        var interventions: [InterventionBlock] = []
        let goalSet = Set(goals)

        switch recoveryZone {
        case .green:
            // Full intervention menu available
            if goalSet.contains(.longevity) || goalSet.contains(.cardiovascular) {
                interventions.append(InterventionBlock(
                    type: .sauna, duration: 20, temperature: "180-200°F",
                    notes: "Deliberate heat exposure for cardiovascular and longevity benefits"
                ))
                interventions.append(InterventionBlock(
                    type: .coldPlunge, duration: 3, temperature: "38-45°F",
                    notes: "Cold exposure post-sauna for norepinephrine and resilience"
                ))
            }
            if goalSet.contains(.stressResilience) || goalSet.contains(.cognitive) {
                interventions.append(InterventionBlock(
                    type: .breathwork, duration: 10, temperature: nil,
                    notes: "Box breathing or Wim Hof method for autonomic regulation"
                ))
            }
            if goalSet.contains(.sleep) {
                interventions.append(InterventionBlock(
                    type: .redLight, duration: 15, temperature: nil,
                    notes: "Red/near-infrared light therapy for circadian support"
                ))
            }
            if goalSet.contains(.cognitive) {
                interventions.append(InterventionBlock(
                    type: .meditation, duration: 15, temperature: nil,
                    notes: "Focused attention meditation for cognitive clarity"
                ))
            }

            // Default if no specific interventions yet
            if interventions.isEmpty {
                interventions.append(InterventionBlock(
                    type: .sauna, duration: 15, temperature: "170-180°F",
                    notes: "General heat exposure for recovery and health"
                ))
            }

        case .yellow:
            // Moderate interventions — no extreme cold
            interventions.append(InterventionBlock(
                type: .breathwork, duration: 10, temperature: nil,
                notes: "Gentle breathwork for parasympathetic activation (4-7-8 or box breathing)"
            ))
            if goalSet.contains(.longevity) || goalSet.contains(.cardiovascular) {
                interventions.append(InterventionBlock(
                    type: .sauna, duration: 15, temperature: "160-170°F",
                    notes: "Moderate heat exposure — shorter duration due to yellow recovery"
                ))
            }
            interventions.append(InterventionBlock(
                type: .grounding, duration: 15, temperature: nil,
                notes: "Barefoot outdoor time for circadian and nervous system regulation"
            ))

        case .red:
            // Gentle only — prioritize parasympathetic activation
            interventions.append(InterventionBlock(
                type: .breathwork, duration: 10, temperature: nil,
                notes: "Gentle diaphragmatic breathing only — no intense protocols (physiological sigh, 4-7-8)"
            ))
            interventions.append(InterventionBlock(
                type: .meditation, duration: 10, temperature: nil,
                notes: "Body scan or yoga nidra for deep recovery"
            ))
            interventions.append(InterventionBlock(
                type: .grounding, duration: 10, temperature: nil,
                notes: "Light outdoor walking, barefoot if possible"
            ))
        }

        return interventions
    }

    // MARK: - Sleep Protocol Builder

    private func buildSleepProtocol(
        recoveryZone: RecoveryZone,
        wearable: WearableInput?
    ) -> SleepProtocol {
        var checklist: [String] = [
            "Dim lights 2 hours before bed",
            "No screens 1 hour before bed (or use blue-light blockers)",
            "Bedroom temperature 65-68°F (18-20°C)",
            "No caffeine after 12:00 PM",
            "No alcohol within 3 hours of bedtime",
        ]

        var notes = ""
        let targetBedtime: String
        let targetWakeTime: String

        switch recoveryZone {
        case .green:
            targetBedtime = "22:00"
            targetWakeTime = "06:00"
            checklist.append("Consistent wake time even on weekends")
            notes = "Standard sleep protocol. Aim for 7-8 hours."

        case .yellow:
            targetBedtime = "21:30"
            targetWakeTime = "06:00"
            checklist.append("Consider 10-20min afternoon nap if needed")
            checklist.append("Extra magnesium glycinate before bed")
            notes = "Extended sleep window recommended. Aim for 8+ hours to support recovery."

        case .red:
            targetBedtime = "21:00"
            targetWakeTime = "06:30"
            checklist.append("Prioritize sleep above all else tonight")
            checklist.append("Take magnesium glycinate + glycine before bed")
            checklist.append("Use sleep mask and white noise if needed")
            checklist.append("No alarm if schedule permits — let body wake naturally")
            notes = "Critical recovery needed. Aim for 9+ hours. Sleep is the priority."
        }

        // Adjust based on wearable data
        if let wearable {
            if let sleepHours = wearable.sleepHours, sleepHours < 6.0 {
                checklist.append("ALERT: Previous night sleep was under 6 hours — tonight is crucial")
            }
            if let deepSleep = wearable.deepSleepMinutes, deepSleep < 40 {
                checklist.append("Deep sleep was low — avoid alcohol and late exercise to improve")
            }
        }

        return SleepProtocol(
            targetBedtime: targetBedtime,
            targetWakeTime: targetWakeTime,
            eveningChecklist: checklist,
            notes: notes
        )
    }
}
