// ProtocolEngineTests.swift
// OutliveEngineTests
//
// Core protocol engine unit tests.

import Testing
@testable import OutliveEngine

@Suite("Protocol Engine")
struct ProtocolEngineTests {

    // MARK: - Recovery Adaptor

    @Test("Green zone when HRV high and sleep good")
    func greenZoneRecovery() {
        let adaptor = RecoveryAdaptor()
        let result = adaptor.assessRecovery(
            hrv: 65,
            restingHR: 58,
            sleepHours: 7.8,
            deepSleep: 95,
            recoveryScore: 85,
            strain: 8
        )
        #expect(result.zone == .green)
        #expect(result.trainingIntensityModifier == 1.0)
        #expect(result.confidence > 0.5)
    }

    @Test("Red zone when all signals poor")
    func redZoneRecovery() {
        let adaptor = RecoveryAdaptor()
        let result = adaptor.assessRecovery(
            hrv: 25,
            restingHR: 75,
            sleepHours: 4.2,
            deepSleep: 20,
            recoveryScore: 15,
            strain: 19
        )
        #expect(result.zone == .red)
        #expect(result.trainingIntensityModifier < 0.4)
    }

    @Test("Yellow zone with no data defaults cautious")
    func noDataRecovery() {
        let adaptor = RecoveryAdaptor()
        let result = adaptor.assessRecovery(
            hrv: nil,
            restingHR: nil,
            sleepHours: nil,
            deepSleep: nil,
            recoveryScore: nil,
            strain: nil
        )
        #expect(result.zone == .yellow)
        #expect(result.confidence == 0.0)
    }

    // MARK: - Biomarker Analyzer

    @Test("Optimal marker returns optimal status")
    func optimalMarker() {
        let marker = BloodworkMarker(
            name: "Vitamin D",
            value: 55,
            unit: "ng/mL",
            optimalLow: 40,
            optimalHigh: 60,
            normalLow: 30,
            normalHigh: 100
        )
        #expect(marker.status == .optimal)
    }

    @Test("Critical marker returns critical status")
    func criticalMarker() {
        let marker = BloodworkMarker(
            name: "Vitamin D",
            value: 8,
            unit: "ng/mL",
            optimalLow: 40,
            optimalHigh: 60,
            normalLow: 30,
            normalHigh: 100
        )
        #expect(marker.status == .critical)
    }

    // MARK: - Circaseptan Engine

    @Test("Week plan has 7 days")
    func weekPlanLength() {
        let engine = CircaseptanEngine()
        let plan = engine.planWeek(goals: [.longevity], currentDay: 1, recoveryZone: .green)
        #expect(plan.days.count == 7)
    }

    @Test("Red zone overrides current day to rest")
    func redZoneOverride() {
        let engine = CircaseptanEngine()
        let plan = engine.planWeek(goals: [.muscleGain], currentDay: 1, recoveryZone: .red)
        let today = plan.days.first { $0.dayNumber == 1 }
        #expect(today?.trainingFocus == .rest)
        #expect(today?.isRecoveryDay == true)
    }

    // MARK: - Meal Planner

    @Test("Meal plan produces 4 meals")
    func mealPlanMealCount() {
        let planner = MealPlanner()
        let plan = planner.plan(
            weightKg: 80,
            bodyFatPercent: 15,
            goals: [.muscleGain],
            trainingType: .strength,
            allergies: [],
            dietaryRestrictions: [],
            geneticAdjustments: []
        )
        #expect(plan.meals.count >= 3)
        #expect(plan.protein > 0)
        #expect(plan.tdee > 0)
    }

    // MARK: - Conflict Resolver

    @Test("Allergen supplements removed")
    func allergenConflict() {
        let resolver = ConflictResolver()
        let supplements = [
            SupplementDose(name: "Omega-3 Fish Oil", dose: "2g", timing: .withBreakfast, rationale: "EPA/DHA"),
            SupplementDose(name: "Vitamin D3", dose: "5000 IU", timing: .withBreakfast, rationale: "Bone health"),
        ]
        let result = resolver.resolve(
            training: nil,
            nutrition: nil,
            supplements: supplements,
            geneticRisks: [:],
            recoveryZone: .green,
            allergies: ["fish"]
        )
        let names = result.supplements.map(\.name.lowercased())
        #expect(!names.contains(where: { $0.contains("fish") }))
        #expect(result.conflicts.count > 0)
    }

    // MARK: - Genetic Risk Mapper

    @Test("Maps MTHFR risk correctly")
    func mthfrMapping() {
        let mapper = GeneticRiskMapper()
        let risks = [
            GeneticRisk(category: .mthfr, snpId: "rs1801133", genotype: "TT", riskLevel: 0.7, implications: ["Reduced folate metabolism"])
        ]
        let assessments = mapper.mapRisks(risks)
        #expect(assessments[.mthfr] != nil)
        #expect(assessments[.mthfr]!.supplementRecommendations.count > 0)
    }
}
