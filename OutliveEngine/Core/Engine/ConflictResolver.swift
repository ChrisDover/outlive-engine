// ConflictResolver.swift
// OutliveEngine
//
// Resolves conflicts between protocol recommendations using a strict
// priority hierarchy. Deterministic — same inputs always yield same outputs.
//
// Priority (highest to lowest):
//   1. Medical contraindications
//   2. Recovery status
//   3. Genetic risks
//   4. Bloodwork insights
//   5. User goals / preferences

import Foundation

// MARK: - Output Types

struct ResolvedProtocol: Sendable, Codable, Hashable {
    let training: TrainingBlock?
    let nutrition: NutritionPlan?
    let supplements: [SupplementDose]
    let conflicts: [ConflictNote]
}

struct ConflictNote: Sendable, Codable, Hashable {
    let description: String
    let resolution: String
    let priority: Int // 1 = highest
}

// MARK: - Engine

struct ConflictResolver: Sendable {

    // MARK: - Public API

    func resolve(
        training: TrainingBlock?,
        nutrition: NutritionPlan?,
        supplements: [SupplementDose],
        geneticRisks: [RiskCategory: GeneticRiskAssessment],
        recoveryZone: RecoveryZone,
        allergies: [String]
    ) -> ResolvedProtocol {

        var resolvedTraining = training
        var resolvedNutrition = nutrition
        var resolvedSupplements = supplements
        var conflicts: [ConflictNote] = []

        // ── Priority 1: Medical Contraindications (Allergies) ────
        resolvedSupplements = filterAllergenicSupplements(
            resolvedSupplements, allergies: allergies, conflicts: &conflicts
        )

        // ── Priority 2: Recovery Status ──────────────────────────
        resolvedTraining = applyRecoveryOverrides(
            resolvedTraining, zone: recoveryZone, conflicts: &conflicts
        )

        // ── Priority 3: Genetic Risk Adjustments ─────────────────
        resolvedSupplements = applyGeneticSupplementAdjustments(
            resolvedSupplements, risks: geneticRisks, conflicts: &conflicts
        )
        resolvedTraining = applyGeneticTrainingAdjustments(
            resolvedTraining, risks: geneticRisks, conflicts: &conflicts
        )

        // ── Priority 4: Supplement Interaction Checks ────────────
        resolvedSupplements = resolveSupplementInteractions(
            resolvedSupplements, conflicts: &conflicts
        )

        // ── Deduplicate supplements by name ──────────────────────
        resolvedSupplements = deduplicateSupplements(resolvedSupplements)

        // Sort conflicts by priority (most important first)
        conflicts.sort { $0.priority < $1.priority }

        return ResolvedProtocol(
            training: resolvedTraining,
            nutrition: resolvedNutrition,
            supplements: resolvedSupplements,
            conflicts: conflicts
        )
    }

    // MARK: - Priority 1: Allergy Filtering

    private func filterAllergenicSupplements(
        _ supplements: [SupplementDose],
        allergies: [String],
        conflicts: inout [ConflictNote]
    ) -> [SupplementDose] {
        let lowerAllergies = Set(allergies.map { $0.lowercased() })
        guard !lowerAllergies.isEmpty else { return supplements }

        return supplements.filter { supplement in
            let nameLower = supplement.name.lowercased()
            let rationaleLower = supplement.rationale.lowercased()

            for allergen in lowerAllergies {
                if nameLower.contains(allergen) || rationaleLower.contains(allergen) {
                    conflicts.append(ConflictNote(
                        description: "Supplement '\(supplement.name)' may contain allergen: \(allergen)",
                        resolution: "Removed \(supplement.name) from protocol due to allergy contraindication",
                        priority: 1
                    ))
                    return false
                }
            }

            // Common allergen-supplement associations
            if lowerAllergies.contains("fish") || lowerAllergies.contains("shellfish") {
                if nameLower.contains("omega") || nameLower.contains("fish oil") || nameLower.contains("krill") {
                    conflicts.append(ConflictNote(
                        description: "Fish/shellfish allergy conflicts with \(supplement.name)",
                        resolution: "Replaced with algae-based omega-3 recommendation",
                        priority: 1
                    ))
                    return false
                }
            }

            if lowerAllergies.contains("soy") {
                if nameLower.contains("phosphatidyl") || nameLower.contains("lecithin") {
                    conflicts.append(ConflictNote(
                        description: "Soy allergy may conflict with \(supplement.name)",
                        resolution: "Removed \(supplement.name) — source sunflower-derived alternative",
                        priority: 1
                    ))
                    return false
                }
            }

            return true
        }
    }

    // MARK: - Priority 2: Recovery Overrides

    private func applyRecoveryOverrides(
        _ training: TrainingBlock?,
        zone: RecoveryZone,
        conflicts: inout [ConflictNote]
    ) -> TrainingBlock? {
        guard let training else { return nil }

        switch zone {
        case .green:
            return training

        case .yellow:
            let isHighIntensity = training.type == .strength || training.type == .hypertrophy
            if isHighIntensity && training.rpeTarget > 7.0 {
                conflicts.append(ConflictNote(
                    description: "Yellow recovery zone conflicts with RPE \(training.rpeTarget) \(training.type.rawValue) session",
                    resolution: "Reduced RPE target to 6.0 and shifted to deload intensity",
                    priority: 2
                ))
                return TrainingBlock(
                    type: .deload,
                    exercises: training.exercises,
                    duration: training.duration,
                    rpeTarget: min(training.rpeTarget, 6.0),
                    notes: "Deloaded due to yellow recovery zone"
                )
            }
            return training

        case .red:
            let originalType = training.type
            if originalType != .rest && originalType != .mobility {
                conflicts.append(ConflictNote(
                    description: "Red recovery zone overrides \(originalType.rawValue) session",
                    resolution: "Replaced with rest/mobility day — recovery is critical",
                    priority: 2
                ))
                return TrainingBlock(
                    type: .rest,
                    exercises: [
                        Exercise(name: "Gentle walking", sets: 1, reps: "20 min"),
                        Exercise(name: "Foam rolling", sets: 1, reps: "10 min"),
                        Exercise(name: "Light stretching", sets: 1, reps: "10 min"),
                    ],
                    duration: 40,
                    rpeTarget: 2.0,
                    notes: "Mandatory rest day — red recovery zone detected"
                )
            }
            return training
        }
    }

    // MARK: - Priority 3: Genetic Adjustments

    private func applyGeneticSupplementAdjustments(
        _ supplements: [SupplementDose],
        risks: [RiskCategory: GeneticRiskAssessment],
        conflicts: inout [ConflictNote]
    ) -> [SupplementDose] {
        var result = supplements

        // CYP1A2 slow metabolizer — remove caffeine-containing supplements
        if let cyp = risks[.cyp1a2], cyp.riskLevel >= 0.5 {
            let before = result.count
            result = result.filter { supplement in
                let name = supplement.name.lowercased()
                let hasCaffeine = name.contains("caffeine") || name.contains("pre-workout")
                    || name.contains("preworkout")
                return !hasCaffeine
            }
            if result.count < before {
                conflicts.append(ConflictNote(
                    description: "CYP1A2 slow metabolizer genotype conflicts with caffeine supplementation",
                    resolution: "Removed caffeine-containing supplements per genetic risk profile",
                    priority: 3
                ))
            }
        }

        // MTHFR — replace folic acid with methylfolate
        if let mthfr = risks[.mthfr], mthfr.riskLevel >= 0.4 {
            result = result.map { supplement in
                let name = supplement.name.lowercased()
                if name.contains("folic acid") {
                    conflicts.append(ConflictNote(
                        description: "MTHFR variant conflicts with synthetic folic acid",
                        resolution: "Replaced folic acid with methylfolate (5-MTHF)",
                        priority: 3
                    ))
                    return SupplementDose(
                        name: "Methylfolate (5-MTHF)",
                        dose: "800mcg",
                        timing: supplement.timing,
                        rationale: "MTHFR variant requires methylated folate form"
                    )
                }
                return supplement
            }
        }

        // COMT Met/Met — reduce or remove stimulant supplements
        if let comt = risks[.comt], comt.riskLevel >= 0.6 {
            let before = result.count
            result = result.filter { supplement in
                let name = supplement.name.lowercased()
                let isStimulant = name.contains("tyrosine") || name.contains("caffeine")
                    || name.contains("yohimbine")
                return !isStimulant
            }
            if result.count < before {
                conflicts.append(ConflictNote(
                    description: "COMT Met/Met genotype indicates high catecholamine levels — stimulant supplements contraindicated",
                    resolution: "Removed stimulant supplements to prevent catecholamine excess",
                    priority: 3
                ))
            }
        }

        return result
    }

    private func applyGeneticTrainingAdjustments(
        _ training: TrainingBlock?,
        risks: [RiskCategory: GeneticRiskAssessment],
        conflicts: inout [ConflictNote]
    ) -> TrainingBlock? {
        guard var training else { return nil }

        // ACTN3 XX (endurance type) with heavy strength session — add note
        if let actn3 = risks[.actn3], actn3.riskLevel >= 0.5 {
            if training.type == .strength && training.rpeTarget >= 8.0 {
                conflicts.append(ConflictNote(
                    description: "ACTN3 XX genotype (endurance-favored) scheduled for heavy strength session",
                    resolution: "Extended warm-up recommended. Consider slightly higher rep ranges (6-8 vs 3-5)",
                    priority: 3
                ))
                training = TrainingBlock(
                    type: training.type,
                    exercises: training.exercises,
                    duration: training.duration,
                    rpeTarget: training.rpeTarget,
                    notes: (training.notes ?? "") + " Extended warm-up for ACTN3 XX genotype."
                )
            }
        }

        return training
    }

    // MARK: - Priority 4: Supplement Interactions

    private func resolveSupplementInteractions(
        _ supplements: [SupplementDose],
        conflicts: inout [ConflictNote]
    ) -> [SupplementDose] {
        var result = supplements

        let names = Set(result.map { $0.name.lowercased() })

        // Iron + Calcium at same timing — calcium inhibits iron absorption
        let hasIron = result.first { $0.name.lowercased().contains("iron") }
        let hasCalcium = result.first { $0.name.lowercased().contains("calcium") }
        if let iron = hasIron, let calcium = hasCalcium, iron.timing == calcium.timing {
            conflicts.append(ConflictNote(
                description: "Iron and calcium taken at same time — calcium inhibits iron absorption",
                resolution: "Separated iron and calcium timing by at least 2 hours",
                priority: 4
            ))
            result = result.map { supplement in
                if supplement.name.lowercased().contains("calcium") && supplement.timing == iron.timing {
                    // Move calcium to a different timing
                    let newTiming: SupplementTiming = iron.timing == .withBreakfast ? .withDinner : .withBreakfast
                    return SupplementDose(
                        name: supplement.name,
                        dose: supplement.dose,
                        timing: newTiming,
                        rationale: supplement.rationale
                    )
                }
                return supplement
            }
        }

        // Zinc + Copper — high zinc can deplete copper
        if names.contains("zinc") && !names.contains("copper") {
            let zincDose = result.first { $0.name.lowercased().contains("zinc") }
            if let zinc = zincDose {
                conflicts.append(ConflictNote(
                    description: "Zinc supplementation without copper may cause copper depletion",
                    resolution: "Added copper 1-2mg to balance zinc intake",
                    priority: 4
                ))
                result.append(SupplementDose(
                    name: "Copper",
                    dose: "2mg",
                    timing: zinc.timing,
                    rationale: "Balances zinc supplementation to prevent copper depletion"
                ))
            }
        }

        // Magnesium — avoid taking with antibiotics timing note
        // (no action needed in supplement form, just informational)

        return result
    }

    // MARK: - Deduplication

    private func deduplicateSupplements(_ supplements: [SupplementDose]) -> [SupplementDose] {
        var seen: Set<String> = []
        return supplements.filter { supplement in
            let key = supplement.name.lowercased()
            guard !seen.contains(key) else { return false }
            seen.insert(key)
            return true
        }
    }
}
