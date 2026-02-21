// BiomarkerAnalyzer.swift
// OutliveEngine
//
// Analyzes bloodwork markers against optimal ranges and tracks trends
// over time to generate actionable insights.

import Foundation

// MARK: - Output Types

struct BiomarkerInsight: Sendable, Codable, Hashable {
    let markerName: String
    let status: MarkerStatus
    let recommendation: String
    let priority: Int // 1 (highest) to 5 (lowest)
}

enum TrendDirection: String, Sendable, Codable, Hashable {
    case improving
    case stable
    case declining
}

struct BiomarkerTrend: Sendable, Codable, Hashable {
    let markerName: String
    let direction: TrendDirection
    let percentChange: Double
}

// MARK: - Engine

struct BiomarkerAnalyzer: Sendable {

    // MARK: - Public API

    /// Analyzes a set of bloodwork markers and returns prioritized insights.
    func analyze(_ markers: [BloodworkMarker]) -> [BiomarkerInsight] {
        markers
            .compactMap { insightFor($0) }
            .sorted { $0.priority < $1.priority }
    }

    /// Compares current vs. previous panels and returns directional trends.
    func trends(current: [BloodworkMarker], previous: [BloodworkMarker]) -> [BiomarkerTrend] {
        let previousByName = Dictionary(previous.map { ($0.name.lowercased(), $0) },
                                        uniquingKeysWith: { _, last in last })
        return current.compactMap { marker in
            guard let prev = previousByName[marker.name.lowercased()],
                  prev.value != 0.0 else { return nil }
            let pctChange = ((marker.value - prev.value) / prev.value) * 100.0
            let direction = trendDirection(for: marker, percentChange: pctChange)
            return BiomarkerTrend(
                markerName: marker.name,
                direction: direction,
                percentChange: (pctChange * 10).rounded() / 10 // round to 1 decimal
            )
        }
    }

    // MARK: - Trend Direction

    /// Determines whether a change is improving, stable, or declining based on
    /// where the current value sits relative to optimal range.
    private func trendDirection(for marker: BloodworkMarker, percentChange: Double) -> TrendDirection {
        let absChange = abs(percentChange)
        guard absChange > 3.0 else { return .stable }

        let midOptimal = (marker.optimalLow + marker.optimalHigh) / 2.0
        let movingTowardOptimal: Bool

        if marker.value < midOptimal {
            movingTowardOptimal = percentChange > 0
        } else {
            movingTowardOptimal = percentChange < 0
        }

        // If already optimal, any significant change away is declining
        if marker.status == .optimal {
            return absChange <= 5.0 ? .stable : .declining
        }

        return movingTowardOptimal ? .improving : .declining
    }

    // MARK: - Marker-Specific Insights

    private func insightFor(_ marker: BloodworkMarker) -> BiomarkerInsight? {
        let key = marker.name.lowercased()
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")

        if let specific = specificInsight(key: key, marker: marker) {
            return specific
        }

        // Fallback for unknown markers — still report if non-optimal
        guard marker.status != .optimal else { return nil }
        return BiomarkerInsight(
            markerName: marker.name,
            status: marker.status,
            recommendation: defaultRecommendation(for: marker),
            priority: defaultPriority(for: marker.status)
        )
    }

    // MARK: - Known Biomarker Recommendations

    private func specificInsight(key: String, marker: BloodworkMarker) -> BiomarkerInsight? {
        switch key {

        // ── Hormones ──────────────────────────────────────────────

        case "testosterone", "totaltestosterone", "freetestosterone":
            return insightForTestosterone(marker)

        case "cortisol", "amcortisol", "morningcortisol":
            return insightForCortisol(marker)

        case "dheas", "dhea", "dheasulfate":
            return insightForDHEAS(marker)

        // ── Vitamins & Minerals ───────────────────────────────────

        case "vitamind", "25ohvitamind", "vitd", "25hydroxyvitamind":
            return insightForVitaminD(marker)

        case "vitaminb12", "b12", "cobalamin":
            return insightForB12(marker)

        case "ferritin":
            return insightForFerritin(marker)

        case "iron", "serumiron":
            return insightForIron(marker)

        // ── Metabolic ─────────────────────────────────────────────

        case "fastingglucose", "glucose", "fastinginsulin":
            return insightForGlucose(marker)

        case "hba1c", "hemoglobina1c", "a1c":
            return insightForHbA1c(marker)

        // ── Inflammatory ──────────────────────────────────────────

        case "hscrp", "crp", "creactiveprotein", "highsensitivitycrp":
            return insightForHsCRP(marker)

        case "homocysteine":
            return insightForHomocysteine(marker)

        // ── Cardiovascular ────────────────────────────────────────

        case "apob", "apolipoproteinb":
            return insightForApoB(marker)

        case "lpa", "lipoprotein(a)", "lipoproteina":
            return insightForLpa(marker)

        // ── Thyroid ───────────────────────────────────────────────

        case "tsh", "thyroidstimulatinghormone":
            return insightForTSH(marker)

        case "freet3", "t3", "triiodothyronine":
            return insightForT3(marker)

        case "freet4", "t4", "thyroxine":
            return insightForT4(marker)

        default:
            return nil
        }
    }

    // MARK: - Individual Marker Logic

    private func insightForTestosterone(_ m: BloodworkMarker) -> BiomarkerInsight {
        let rec: String
        switch m.status {
        case .critical:
            rec = "Testosterone critically out of range. Consult endocrinologist. Review sleep, stress, and body composition."
        case .suboptimal where m.value < m.optimalLow:
            rec = "Optimize sleep (7-9h), manage stress, ensure zinc/magnesium intake, resistance train 3-4x/week, minimize alcohol."
        case .suboptimal:
            rec = "Mildly elevated — monitor. Review supplementation and training intensity."
        case .normal:
            rec = "Within normal range. Maintain current lifestyle factors to push toward optimal."
        case .optimal:
            rec = "Testosterone in optimal range. Maintain current protocol."
        }
        return BiomarkerInsight(markerName: m.name, status: m.status, recommendation: rec,
                                priority: m.status == .critical ? 1 : (m.status == .optimal ? 5 : 3))
    }

    private func insightForCortisol(_ m: BloodworkMarker) -> BiomarkerInsight {
        let rec: String
        switch m.status {
        case .critical:
            rec = "Cortisol critically abnormal — rule out Cushing's or adrenal insufficiency with endocrinologist."
        case .suboptimal where m.value > m.optimalHigh:
            rec = "Elevated cortisol suggests chronic stress. Prioritize sleep, reduce training volume, add breathwork/meditation, consider ashwagandha."
        case .suboptimal:
            rec = "Low cortisol — assess adrenal fatigue. Reduce training intensity, improve sleep, consider adaptogens."
        case .normal, .optimal:
            rec = "Cortisol within healthy range. Maintain stress management practices."
        }
        return BiomarkerInsight(markerName: m.name, status: m.status, recommendation: rec,
                                priority: m.status == .critical ? 1 : (m.status == .optimal ? 5 : 2))
    }

    private func insightForDHEAS(_ m: BloodworkMarker) -> BiomarkerInsight {
        let rec: String
        if m.status == .optimal {
            rec = "DHEA-S optimal. Maintain current protocol."
        } else if m.value < m.optimalLow {
            rec = "Low DHEA-S may indicate adrenal fatigue. Consider DHEA supplementation (25-50mg) under medical guidance."
        } else {
            rec = "Monitor DHEA-S levels. Ensure stress management and adequate sleep."
        }
        return BiomarkerInsight(markerName: m.name, status: m.status, recommendation: rec,
                                priority: m.status == .optimal ? 5 : 3)
    }

    private func insightForVitaminD(_ m: BloodworkMarker) -> BiomarkerInsight {
        let rec: String
        switch m.status {
        case .critical:
            rec = "Vitamin D critically low. Supplement D3 5000-10000 IU/day with K2 and retest in 8 weeks."
        case .suboptimal where m.value < m.optimalLow:
            rec = "Vitamin D suboptimal. Supplement D3 4000-5000 IU/day with K2 (MK-7 200mcg). Target 60-80 ng/mL. Increase sun exposure."
        case .suboptimal:
            rec = "Vitamin D slightly high. Reduce supplementation and retest."
        case .normal:
            rec = "Vitamin D in normal range. Consider increasing to reach optimal 60-80 ng/mL."
        case .optimal:
            rec = "Vitamin D optimal. Maintain current supplementation."
        }
        return BiomarkerInsight(markerName: m.name, status: m.status, recommendation: rec,
                                priority: m.status == .critical ? 1 : (m.status == .optimal ? 5 : 2))
    }

    private func insightForB12(_ m: BloodworkMarker) -> BiomarkerInsight {
        let rec: String
        if m.status == .optimal {
            rec = "B12 optimal. Maintain current intake."
        } else if m.value < m.optimalLow {
            rec = "B12 low — supplement methylcobalamin 1000mcg/day. Include animal proteins or fortified foods. Check for absorption issues."
        } else {
            rec = "B12 elevated — usually benign. Monitor and reduce supplementation if applicable."
        }
        return BiomarkerInsight(markerName: m.name, status: m.status, recommendation: rec,
                                priority: m.status == .optimal ? 5 : 3)
    }

    private func insightForFerritin(_ m: BloodworkMarker) -> BiomarkerInsight {
        let rec: String
        switch m.status {
        case .critical where m.value < m.normalLow:
            rec = "Ferritin critically low — possible iron deficiency anemia. Consult physician. Consider iron supplementation with vitamin C for absorption."
        case .critical:
            rec = "Ferritin critically high — possible iron overload or inflammation. Rule out hemochromatosis. Consult physician."
        case .suboptimal where m.value < m.optimalLow:
            rec = "Ferritin suboptimal. Increase iron-rich foods (red meat, dark greens). Consider iron bisglycinate 25mg with vitamin C."
        case .suboptimal:
            rec = "Ferritin mildly elevated. May indicate inflammation. Check hsCRP. Consider blood donation."
        case .normal, .optimal:
            rec = "Ferritin within healthy range. Maintain current iron intake."
        }
        return BiomarkerInsight(markerName: m.name, status: m.status, recommendation: rec,
                                priority: m.status == .critical ? 1 : (m.status == .optimal ? 5 : 3))
    }

    private func insightForIron(_ m: BloodworkMarker) -> BiomarkerInsight {
        let rec: String
        if m.status == .optimal {
            rec = "Serum iron optimal."
        } else if m.value < m.optimalLow {
            rec = "Low serum iron. Pair iron-rich foods with vitamin C. Avoid tea/coffee with meals. Check ferritin and TIBC."
        } else {
            rec = "Elevated iron. Check ferritin and transferrin saturation."
        }
        return BiomarkerInsight(markerName: m.name, status: m.status, recommendation: rec,
                                priority: m.status == .critical ? 2 : (m.status == .optimal ? 5 : 3))
    }

    private func insightForGlucose(_ m: BloodworkMarker) -> BiomarkerInsight {
        let rec: String
        switch m.status {
        case .critical:
            rec = "Fasting glucose critically abnormal. Urgent medical evaluation for diabetes. Begin glucose monitoring."
        case .suboptimal where m.value > m.optimalHigh:
            rec = "Elevated fasting glucose — early insulin resistance risk. Increase Zone 2 cardio, reduce refined carbs, add post-meal walks, consider berberine or CGM monitoring."
        case .suboptimal:
            rec = "Low fasting glucose. Ensure adequate carbohydrate intake and evaluate for reactive hypoglycemia."
        case .normal:
            rec = "Glucose normal. Maintain balanced carb intake and regular exercise."
        case .optimal:
            rec = "Fasting glucose optimal. Maintain current metabolic health practices."
        }
        return BiomarkerInsight(markerName: m.name, status: m.status, recommendation: rec,
                                priority: m.status == .critical ? 1 : (m.status == .optimal ? 5 : 2))
    }

    private func insightForHbA1c(_ m: BloodworkMarker) -> BiomarkerInsight {
        let rec: String
        switch m.status {
        case .critical:
            rec = "HbA1c critically elevated — indicates poor glycemic control over 3 months. Immediate medical consultation required."
        case .suboptimal where m.value > m.optimalHigh:
            rec = "HbA1c elevated — metabolic dysfunction. Prioritize Zone 2 cardio (150+ min/week), reduce processed carbs, add post-meal walks, consider CGM."
        case .suboptimal:
            rec = "HbA1c slightly low. Unusual — evaluate for hemolytic conditions or lab error."
        case .normal, .optimal:
            rec = "HbA1c in healthy range, indicating good 3-month glucose control."
        }
        return BiomarkerInsight(markerName: m.name, status: m.status, recommendation: rec,
                                priority: m.status == .critical ? 1 : (m.status == .optimal ? 5 : 2))
    }

    private func insightForHsCRP(_ m: BloodworkMarker) -> BiomarkerInsight {
        let rec: String
        switch m.status {
        case .critical:
            rec = "hsCRP critically elevated — significant systemic inflammation. Rule out infection or autoimmune condition. Consult physician."
        case .suboptimal:
            rec = "Elevated hsCRP — chronic inflammation. Increase omega-3 intake (2-3g EPA/DHA), reduce refined sugars, prioritize sleep, consider curcumin supplementation."
        case .normal:
            rec = "hsCRP normal. Maintain anti-inflammatory diet and lifestyle."
        case .optimal:
            rec = "hsCRP optimal — low systemic inflammation. Maintain current protocol."
        }
        return BiomarkerInsight(markerName: m.name, status: m.status, recommendation: rec,
                                priority: m.status == .critical ? 1 : (m.status == .optimal ? 5 : 2))
    }

    private func insightForHomocysteine(_ m: BloodworkMarker) -> BiomarkerInsight {
        let rec: String
        switch m.status {
        case .critical:
            rec = "Homocysteine critically elevated — cardiovascular and neurological risk. Check MTHFR status. Supplement methylfolate, B12, B6 immediately."
        case .suboptimal:
            rec = "Elevated homocysteine. Supplement methylfolate 800mcg, methylcobalamin 1000mcg, P5P (B6) 50mg. Increase leafy greens."
        case .normal, .optimal:
            rec = "Homocysteine in healthy range. Maintain B-vitamin intake."
        }
        return BiomarkerInsight(markerName: m.name, status: m.status, recommendation: rec,
                                priority: m.status == .critical ? 1 : (m.status == .optimal ? 5 : 2))
    }

    private func insightForApoB(_ m: BloodworkMarker) -> BiomarkerInsight {
        let rec: String
        switch m.status {
        case .critical:
            rec = "ApoB critically elevated — high atherogenic particle count. Consult cardiologist. Dietary intervention plus possible pharmacotherapy."
        case .suboptimal:
            rec = "ApoB elevated — primary driver of atherosclerosis. Reduce saturated fat, increase soluble fiber (10g+/day), consider plant sterols, increase Zone 2 cardio."
        case .normal:
            rec = "ApoB in normal range. Target optimal (<80 mg/dL) for longevity-focused protocol."
        case .optimal:
            rec = "ApoB optimal — low atherogenic risk. Maintain current cardiovascular protocol."
        }
        return BiomarkerInsight(markerName: m.name, status: m.status, recommendation: rec,
                                priority: m.status == .critical ? 1 : (m.status == .optimal ? 5 : 2))
    }

    private func insightForLpa(_ m: BloodworkMarker) -> BiomarkerInsight {
        let rec: String
        if m.status == .optimal || m.status == .normal {
            rec = "Lp(a) in acceptable range. This is largely genetically determined — no action needed."
        } else {
            rec = "Elevated Lp(a) — genetically determined cardiovascular risk factor. Aggressive ApoB lowering recommended. Consult cardiologist. Niacin or PCSK9 inhibitors may help."
        }
        return BiomarkerInsight(markerName: m.name, status: m.status, recommendation: rec,
                                priority: m.status == .critical ? 1 : (m.status == .optimal ? 5 : 2))
    }

    private func insightForTSH(_ m: BloodworkMarker) -> BiomarkerInsight {
        let rec: String
        switch m.status {
        case .critical:
            rec = "TSH critically abnormal — possible hypo/hyperthyroidism. Urgent endocrinology evaluation needed."
        case .suboptimal where m.value > m.optimalHigh:
            rec = "TSH elevated — subclinical hypothyroidism possible. Check Free T3/T4, thyroid antibodies. Ensure adequate selenium and iodine."
        case .suboptimal:
            rec = "TSH low — possible hyperthyroidism or over-supplementation. Check Free T3/T4."
        case .normal, .optimal:
            rec = "Thyroid function appears normal based on TSH."
        }
        return BiomarkerInsight(markerName: m.name, status: m.status, recommendation: rec,
                                priority: m.status == .critical ? 1 : (m.status == .optimal ? 5 : 2))
    }

    private func insightForT3(_ m: BloodworkMarker) -> BiomarkerInsight {
        let rec: String
        if m.status == .optimal {
            rec = "Free T3 optimal — good active thyroid hormone levels."
        } else if m.value < m.optimalLow {
            rec = "Low Free T3 — may indicate poor T4-to-T3 conversion. Ensure adequate selenium (200mcg/day), zinc, and iron."
        } else {
            rec = "Free T3 elevated. Evaluate with TSH and T4 for complete thyroid picture."
        }
        return BiomarkerInsight(markerName: m.name, status: m.status, recommendation: rec,
                                priority: m.status == .critical ? 2 : (m.status == .optimal ? 5 : 3))
    }

    private func insightForT4(_ m: BloodworkMarker) -> BiomarkerInsight {
        let rec: String
        if m.status == .optimal {
            rec = "Free T4 optimal."
        } else if m.value < m.optimalLow {
            rec = "Low Free T4 — possible hypothyroidism. Check TSH and thyroid antibodies. Ensure adequate iodine intake."
        } else {
            rec = "Free T4 elevated — evaluate thyroid function comprehensively."
        }
        return BiomarkerInsight(markerName: m.name, status: m.status, recommendation: rec,
                                priority: m.status == .critical ? 2 : (m.status == .optimal ? 5 : 3))
    }

    // MARK: - Defaults

    private func defaultRecommendation(for marker: BloodworkMarker) -> String {
        switch marker.status {
        case .critical:
            return "\(marker.name) is critically out of range (\(marker.value) \(marker.unit)). Consult your physician."
        case .suboptimal:
            return "\(marker.name) is suboptimal (\(marker.value) \(marker.unit)). Optimal range: \(marker.optimalLow)-\(marker.optimalHigh) \(marker.unit)."
        case .normal:
            return "\(marker.name) is in normal range but could be optimized. Current: \(marker.value), optimal: \(marker.optimalLow)-\(marker.optimalHigh) \(marker.unit)."
        case .optimal:
            return "\(marker.name) is optimal."
        }
    }

    private func defaultPriority(for status: MarkerStatus) -> Int {
        switch status {
        case .critical:    return 1
        case .suboptimal:  return 3
        case .normal:      return 4
        case .optimal:     return 5
        }
    }
}
