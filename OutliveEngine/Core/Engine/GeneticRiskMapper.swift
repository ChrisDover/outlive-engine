// GeneticRiskMapper.swift
// OutliveEngine
//
// Maps raw SNP genotypes to actionable risk assessments with dietary,
// supplement, and training modifications.

import Foundation

// MARK: - Output Types

struct GeneticRiskAssessment: Sendable, Codable, Hashable {
    let category: RiskCategory
    let riskLevel: Double
    let dietaryAdjustments: [String]
    let supplementRecommendations: [String]
    let trainingModifications: [String]
}

// MARK: - Engine

struct GeneticRiskMapper: Sendable {

    // MARK: - Public API

    /// Maps an array of raw genetic risks to a dictionary keyed by risk category.
    /// Each entry contains an actionable assessment derived from the SNP genotype.
    func mapRisks(_ risks: [GeneticRisk]) -> [RiskCategory: GeneticRiskAssessment] {
        var assessments: [RiskCategory: GeneticRiskAssessment] = [:]
        for risk in risks {
            assessments[risk.category] = assess(risk)
        }
        return assessments
    }

    // MARK: - Internal Mapping

    private func assess(_ risk: GeneticRisk) -> GeneticRiskAssessment {
        switch risk.category {
        case .apoe:
            return assessAPOE(risk)
        case .mthfr:
            return assessMTHFR(risk)
        case .cyp1a2:
            return assessCYP1A2(risk)
        case .actn3:
            return assessACTN3(risk)
        case .fto:
            return assessFTO(risk)
        case .vdr:
            return assessVDR(risk)
        case .comt:
            return assessCOMT(risk)
        case .gstm1:
            return assessGSTM1(risk)
        case .bcmo1:
            return assessBCMO1(risk)
        case .slc23a1:
            return assessSLC23A1(risk)
        }
    }

    // MARK: - APOE (rs429358 / rs7412)
    // epsilon-4 allele: elevated cardiovascular and Alzheimer's risk

    private func assessAPOE(_ risk: GeneticRisk) -> GeneticRiskAssessment {
        let genotype = risk.genotype.lowercased()
        let hasE4 = genotype.contains("e4") || genotype.contains("ε4")
            || genotype.contains("4/4") || genotype.contains("3/4")
        let homozygousE4 = genotype.contains("4/4") || genotype.contains("ε4/ε4")
            || genotype.contains("e4/e4")

        if homozygousE4 {
            return GeneticRiskAssessment(
                category: .apoe,
                riskLevel: min(risk.riskLevel, 1.0),
                dietaryAdjustments: [
                    "Limit saturated fat to <7% of total calories",
                    "Prioritize omega-3 fatty acids (EPA/DHA 2-3g/day)",
                    "Increase monounsaturated fat sources (olive oil, avocado)",
                    "Emphasize Mediterranean-style eating pattern",
                    "Include regular cruciferous vegetable intake",
                ],
                supplementRecommendations: [
                    "Omega-3 (EPA/DHA) 2-3g/day",
                    "Phosphatidylcholine 500mg/day",
                    "Curcumin 500mg/day with piperine",
                    "CoQ10 200mg/day",
                ],
                trainingModifications: [
                    "Prioritize Zone 2 cardiovascular training (150+ min/week)",
                    "Include regular cognitive challenge exercises",
                    "Maintain consistent sleep schedule for amyloid clearance",
                ]
            )
        } else if hasE4 {
            return GeneticRiskAssessment(
                category: .apoe,
                riskLevel: min(risk.riskLevel, 1.0),
                dietaryAdjustments: [
                    "Limit saturated fat to <10% of total calories",
                    "Prioritize omega-3 fatty acids (EPA/DHA 1-2g/day)",
                    "Increase monounsaturated fat sources",
                    "Emphasize Mediterranean-style eating pattern",
                ],
                supplementRecommendations: [
                    "Omega-3 (EPA/DHA) 1-2g/day",
                    "Curcumin 500mg/day with piperine",
                ],
                trainingModifications: [
                    "Include Zone 2 cardiovascular training (120+ min/week)",
                    "Regular cognitive challenge exercises recommended",
                ]
            )
        } else {
            return GeneticRiskAssessment(
                category: .apoe,
                riskLevel: min(risk.riskLevel, 1.0),
                dietaryAdjustments: [
                    "Standard healthy fat distribution",
                ],
                supplementRecommendations: [
                    "Omega-3 (EPA/DHA) 1g/day for general health",
                ],
                trainingModifications: []
            )
        }
    }

    // MARK: - MTHFR (rs1801133 — C677T)
    // Reduced methylation capacity; use methylfolate over folic acid

    private func assessMTHFR(_ risk: GeneticRisk) -> GeneticRiskAssessment {
        let genotype = risk.genotype.uppercased()
        let isHomozygous = genotype.contains("TT") || genotype.contains("677TT")
        let isHeterozygous = genotype.contains("CT") || genotype.contains("677CT")

        if isHomozygous {
            return GeneticRiskAssessment(
                category: .mthfr,
                riskLevel: min(risk.riskLevel, 1.0),
                dietaryAdjustments: [
                    "Increase folate-rich foods (dark leafy greens, lentils, asparagus)",
                    "Avoid fortified foods with synthetic folic acid",
                    "Include betaine-rich foods (beets, spinach, quinoa)",
                ],
                supplementRecommendations: [
                    "Methylfolate (5-MTHF) 800-1000mcg/day — NOT folic acid",
                    "Methylcobalamin (B12) 1000mcg/day",
                    "Riboflavin (B2) 25-50mg/day as MTHFR cofactor",
                    "TMG (trimethylglycine) 500mg/day",
                ],
                trainingModifications: [
                    "Monitor recovery closely — impaired methylation may slow repair",
                    "Ensure adequate protein for methionine cycle support",
                ]
            )
        } else if isHeterozygous {
            return GeneticRiskAssessment(
                category: .mthfr,
                riskLevel: min(risk.riskLevel, 1.0),
                dietaryAdjustments: [
                    "Increase folate-rich foods (dark leafy greens, lentils)",
                    "Prefer methylfolate over folic acid in supplements",
                ],
                supplementRecommendations: [
                    "Methylfolate (5-MTHF) 400-800mcg/day",
                    "Methylcobalamin (B12) 500mcg/day",
                ],
                trainingModifications: []
            )
        } else {
            return GeneticRiskAssessment(
                category: .mthfr,
                riskLevel: min(risk.riskLevel, 1.0),
                dietaryAdjustments: [
                    "Standard folate intake adequate",
                ],
                supplementRecommendations: [],
                trainingModifications: []
            )
        }
    }

    // MARK: - CYP1A2 (rs762551)
    // Slow metabolizer: limit caffeine intake

    private func assessCYP1A2(_ risk: GeneticRisk) -> GeneticRiskAssessment {
        let genotype = risk.genotype.uppercased()
        let isSlowMetabolizer = genotype.contains("AC") || genotype.contains("CC")

        if isSlowMetabolizer {
            return GeneticRiskAssessment(
                category: .cyp1a2,
                riskLevel: min(risk.riskLevel, 1.0),
                dietaryAdjustments: [
                    "Limit caffeine to <200mg/day (roughly 1 cup of coffee)",
                    "No caffeine after 12:00 PM to protect sleep architecture",
                    "Consider green tea over coffee for slower caffeine release",
                ],
                supplementRecommendations: [
                    "Avoid caffeine-containing pre-workouts",
                    "Use non-stimulant alternatives (citrulline, beta-alanine)",
                ],
                trainingModifications: [
                    "Do not rely on caffeine for training performance",
                    "Schedule high-intensity sessions for natural cortisol peak (morning)",
                ]
            )
        } else {
            return GeneticRiskAssessment(
                category: .cyp1a2,
                riskLevel: min(risk.riskLevel, 1.0),
                dietaryAdjustments: [
                    "Moderate caffeine intake acceptable (up to 400mg/day)",
                    "Still avoid caffeine within 8 hours of bedtime",
                ],
                supplementRecommendations: [
                    "Caffeine 100-200mg pre-workout is well-tolerated",
                ],
                trainingModifications: []
            )
        }
    }

    // MARK: - ACTN3 (rs1815739 — R577X)
    // XX genotype: endurance advantage; RR: power/strength advantage

    private func assessACTN3(_ risk: GeneticRisk) -> GeneticRiskAssessment {
        let genotype = risk.genotype.uppercased()
        let isXX = genotype.contains("XX") || genotype.contains("TT")
        let isRR = genotype.contains("RR") || genotype.contains("CC")

        if isXX {
            return GeneticRiskAssessment(
                category: .actn3,
                riskLevel: min(risk.riskLevel, 1.0),
                dietaryAdjustments: [
                    "Higher carbohydrate intake for endurance fuel",
                    "Emphasize anti-inflammatory foods for recovery",
                ],
                supplementRecommendations: [
                    "Beta-alanine 3-5g/day for endurance buffering",
                    "Tart cherry extract for recovery",
                ],
                trainingModifications: [
                    "Natural endurance predisposition — favor higher volume, moderate load",
                    "Longer warm-ups needed for explosive movements",
                    "Include dedicated power/plyometric work to compensate for fiber type",
                    "May need longer rest periods for maximal strength work",
                ]
            )
        } else if isRR {
            return GeneticRiskAssessment(
                category: .actn3,
                riskLevel: min(risk.riskLevel, 1.0),
                dietaryAdjustments: [
                    "Higher protein for muscle protein synthesis support",
                    "Adequate creatine-rich foods (red meat, fish)",
                ],
                supplementRecommendations: [
                    "Creatine monohydrate 5g/day",
                ],
                trainingModifications: [
                    "Natural power/strength predisposition — responds well to heavy loads",
                    "Include dedicated Zone 2 endurance work for cardiovascular health",
                    "Explosive training (Olympic lifts, plyometrics) well-suited",
                ]
            )
        } else {
            // Heterozygous RX — balanced
            return GeneticRiskAssessment(
                category: .actn3,
                riskLevel: min(risk.riskLevel, 1.0),
                dietaryAdjustments: [
                    "Balanced macronutrient approach",
                ],
                supplementRecommendations: [
                    "Creatine monohydrate 3-5g/day",
                ],
                trainingModifications: [
                    "Balanced fiber type — responds to both strength and endurance training",
                    "Periodize between power and endurance phases",
                ]
            )
        }
    }

    // MARK: - FTO (rs9939609)
    // Risk allele (AA): increased appetite, benefit from higher protein

    private func assessFTO(_ risk: GeneticRisk) -> GeneticRiskAssessment {
        let genotype = risk.genotype.uppercased()
        let isHomozygousRisk = genotype.contains("AA")
        let isHeterozygous = genotype.contains("AT") || genotype.contains("TA")

        if isHomozygousRisk {
            return GeneticRiskAssessment(
                category: .fto,
                riskLevel: min(risk.riskLevel, 1.0),
                dietaryAdjustments: [
                    "Increase protein to 2.0-2.4g/kg to improve satiety",
                    "Prioritize whole foods over processed for satiety signaling",
                    "Include high-fiber foods at every meal (30g+/day target)",
                    "Front-load calories earlier in the day",
                    "Use structured meal timing to manage appetite",
                ],
                supplementRecommendations: [
                    "Fiber supplement if dietary intake insufficient",
                    "Consider glucomannan 1g before meals for satiety",
                ],
                trainingModifications: [
                    "Higher exercise volume recommended — FTO risk responds well to activity",
                    "Daily movement goal: 8,000+ steps beyond formal training",
                    "Include both resistance and cardio for body composition management",
                ]
            )
        } else if isHeterozygous {
            return GeneticRiskAssessment(
                category: .fto,
                riskLevel: min(risk.riskLevel, 1.0),
                dietaryAdjustments: [
                    "Moderate increase in protein intake (1.8-2.2g/kg)",
                    "Include high-fiber foods regularly",
                    "Mindful eating practices recommended",
                ],
                supplementRecommendations: [],
                trainingModifications: [
                    "Regular exercise effectively mitigates FTO variant risk",
                ]
            )
        } else {
            return GeneticRiskAssessment(
                category: .fto,
                riskLevel: min(risk.riskLevel, 1.0),
                dietaryAdjustments: [
                    "Standard macronutrient distribution adequate",
                ],
                supplementRecommendations: [],
                trainingModifications: []
            )
        }
    }

    // MARK: - VDR (rs2228570 / rs1544410)
    // Reduced vitamin D receptor efficiency

    private func assessVDR(_ risk: GeneticRisk) -> GeneticRiskAssessment {
        let riskLevel = risk.riskLevel

        if riskLevel >= 0.6 {
            return GeneticRiskAssessment(
                category: .vdr,
                riskLevel: min(riskLevel, 1.0),
                dietaryAdjustments: [
                    "Increase vitamin D-rich foods (fatty fish, egg yolks, mushrooms)",
                    "Ensure adequate calcium and magnesium co-intake",
                    "Include vitamin K2-rich foods (natto, hard cheeses)",
                ],
                supplementRecommendations: [
                    "Vitamin D3 4000-5000 IU/day (titrate to 60-80 ng/mL serum level)",
                    "Vitamin K2 (MK-7) 200mcg/day",
                    "Magnesium glycinate 400mg/day (VDR cofactor)",
                ],
                trainingModifications: [
                    "Outdoor training preferred for UV-B exposure when possible",
                    "Monitor bone density — increased fracture risk with low vitamin D",
                ]
            )
        } else {
            return GeneticRiskAssessment(
                category: .vdr,
                riskLevel: min(riskLevel, 1.0),
                dietaryAdjustments: [
                    "Standard vitamin D-rich food intake",
                ],
                supplementRecommendations: [
                    "Vitamin D3 2000 IU/day maintenance dose",
                ],
                trainingModifications: []
            )
        }
    }

    // MARK: - COMT (rs4680 — Val158Met)
    // Val/Val (GG): faster dopamine clearance, better stress tolerance but lower baseline dopamine
    // Met/Met (AA): slower clearance, higher dopamine but more stress-sensitive

    private func assessCOMT(_ risk: GeneticRisk) -> GeneticRiskAssessment {
        let genotype = risk.genotype.uppercased()
        let isMetMet = genotype.contains("AA") || genotype.contains("MET/MET")
        let isValVal = genotype.contains("GG") || genotype.contains("VAL/VAL")

        if isMetMet {
            return GeneticRiskAssessment(
                category: .comt,
                riskLevel: min(risk.riskLevel, 1.0),
                dietaryAdjustments: [
                    "Limit caffeine — already high catecholamine levels",
                    "Increase magnesium-rich foods for stress buffering",
                    "Emphasize anti-inflammatory diet to reduce neuroinflammation",
                    "Avoid excessive tyramine-containing foods",
                ],
                supplementRecommendations: [
                    "Magnesium glycinate 400mg/day",
                    "L-theanine 200mg/day for calming without sedation",
                    "Phosphatidylserine 100mg/day for cortisol modulation",
                ],
                trainingModifications: [
                    "May be more stress-sensitive — manage training volume carefully",
                    "Prioritize recovery and parasympathetic activation post-training",
                    "Include daily breathwork or meditation for stress resilience",
                    "Avoid excessive high-intensity sessions in same week",
                ]
            )
        } else if isValVal {
            return GeneticRiskAssessment(
                category: .comt,
                riskLevel: min(risk.riskLevel, 1.0),
                dietaryAdjustments: [
                    "Caffeine is well-tolerated and may enhance performance",
                    "Tyrosine-rich foods may support dopamine levels",
                ],
                supplementRecommendations: [
                    "L-Tyrosine 500mg before demanding training sessions",
                ],
                trainingModifications: [
                    "Higher stress tolerance — can handle greater training volume",
                    "May benefit from higher-intensity protocols",
                    "Respond well to competition and high-pressure training",
                ]
            )
        } else {
            // Heterozygous Val/Met — balanced
            return GeneticRiskAssessment(
                category: .comt,
                riskLevel: min(risk.riskLevel, 1.0),
                dietaryAdjustments: [
                    "Moderate caffeine intake appropriate",
                    "Balanced approach to stimulating foods",
                ],
                supplementRecommendations: [
                    "Magnesium glycinate 200-400mg/day",
                ],
                trainingModifications: [
                    "Balanced stress response — standard periodization appropriate",
                ]
            )
        }
    }

    // MARK: - GSTM1 (deletion polymorphism)
    // Null genotype: reduced detoxification capacity

    private func assessGSTM1(_ risk: GeneticRisk) -> GeneticRiskAssessment {
        let genotype = risk.genotype.lowercased()
        let isNull = genotype.contains("null") || genotype.contains("del")
            || genotype.contains("0/0")

        if isNull {
            return GeneticRiskAssessment(
                category: .gstm1,
                riskLevel: min(risk.riskLevel, 1.0),
                dietaryAdjustments: [
                    "Increase cruciferous vegetable intake (broccoli, cauliflower, kale)",
                    "Include sulforaphane-rich foods (broccoli sprouts)",
                    "Support Phase II detoxification with allium vegetables (garlic, onions)",
                    "Emphasize antioxidant-rich berries and green tea",
                ],
                supplementRecommendations: [
                    "Sulforaphane 30-50mg/day (or broccoli sprout extract)",
                    "NAC (N-Acetyl Cysteine) 600mg/day for glutathione support",
                    "Alpha-lipoic acid 300mg/day",
                ],
                trainingModifications: [
                    "Avoid training in high-pollution environments",
                    "Consider indoor training on poor air quality days",
                ]
            )
        } else {
            return GeneticRiskAssessment(
                category: .gstm1,
                riskLevel: min(risk.riskLevel, 1.0),
                dietaryAdjustments: [
                    "Standard cruciferous vegetable intake beneficial",
                ],
                supplementRecommendations: [],
                trainingModifications: []
            )
        }
    }

    // MARK: - BCMO1 (rs12934922 / rs7501331)
    // Reduced beta-carotene to retinol conversion

    private func assessBCMO1(_ risk: GeneticRisk) -> GeneticRiskAssessment {
        let riskLevel = risk.riskLevel

        if riskLevel >= 0.5 {
            return GeneticRiskAssessment(
                category: .bcmo1,
                riskLevel: min(riskLevel, 1.0),
                dietaryAdjustments: [
                    "Prioritize preformed vitamin A (retinol) from animal sources",
                    "Include liver, egg yolks, and dairy for direct retinol",
                    "Do not rely solely on plant carotenoids for vitamin A needs",
                ],
                supplementRecommendations: [
                    "Retinol (preformed vitamin A) 2500-5000 IU/day",
                ],
                trainingModifications: []
            )
        } else {
            return GeneticRiskAssessment(
                category: .bcmo1,
                riskLevel: min(riskLevel, 1.0),
                dietaryAdjustments: [
                    "Standard beta-carotene conversion adequate",
                ],
                supplementRecommendations: [],
                trainingModifications: []
            )
        }
    }

    // MARK: - SLC23A1 (rs33972313)
    // Reduced vitamin C transporter efficiency

    private func assessSLC23A1(_ risk: GeneticRisk) -> GeneticRiskAssessment {
        let riskLevel = risk.riskLevel

        if riskLevel >= 0.5 {
            return GeneticRiskAssessment(
                category: .slc23a1,
                riskLevel: min(riskLevel, 1.0),
                dietaryAdjustments: [
                    "Increase vitamin C-rich foods throughout the day",
                    "Include citrus, bell peppers, strawberries, kiwi at multiple meals",
                    "Split vitamin C intake across meals for better absorption",
                ],
                supplementRecommendations: [
                    "Vitamin C 500-1000mg/day in divided doses",
                    "Consider liposomal vitamin C for enhanced absorption",
                ],
                trainingModifications: [
                    "Higher antioxidant needs post-training — include vitamin C-rich post-workout meal",
                ]
            )
        } else {
            return GeneticRiskAssessment(
                category: .slc23a1,
                riskLevel: min(riskLevel, 1.0),
                dietaryAdjustments: [
                    "Standard vitamin C intake from whole foods sufficient",
                ],
                supplementRecommendations: [],
                trainingModifications: []
            )
        }
    }
}
