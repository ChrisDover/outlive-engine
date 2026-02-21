// RecoveryAdaptor.swift
// OutliveEngine
//
// Determines recovery zone from wearable data using a weighted,
// multi-signal approach. Fully deterministic — no randomness.

import Foundation

// MARK: - Output Types

struct RecoveryAssessment: Sendable, Codable, Hashable {
    let zone: RecoveryZone
    let confidence: Double       // 0.0–1.0
    let trainingIntensityModifier: Double  // 0.0–1.0 (1.0 = full intensity)
    let recommendations: [String]
}

// MARK: - Engine

struct RecoveryAdaptor: Sendable {

    // MARK: - Default Baselines

    // Population-level defaults used when personal baselines are unavailable.
    // In a production system these would be replaced by rolling averages.
    private let defaultHRVBaseline: Double = 55.0
    private let defaultRHRBaseline: Int = 62

    // MARK: - Public API

    /// Assesses recovery state from wearable signals and returns a zone with
    /// a training intensity modifier.
    func assessRecovery(
        hrv: Double?,
        restingHR: Int?,
        sleepHours: Double?,
        deepSleep: Int?,
        recoveryScore: Double?,
        strain: Double?
    ) -> RecoveryAssessment {

        var signals: [RecoverySignal] = []

        // ── HRV Signal ───────────────────────────────────────────
        if let hrv {
            let ratio = hrv / defaultHRVBaseline
            let score: Double
            if ratio >= 1.05 {
                score = 1.0
            } else if ratio >= 0.85 {
                score = 0.5 + (ratio - 0.85) / (1.05 - 0.85) * 0.5
            } else if ratio >= 0.65 {
                score = (ratio - 0.65) / (0.85 - 0.65) * 0.5
            } else {
                score = 0.0
            }
            signals.append(RecoverySignal(name: "hrv", score: score, weight: 0.30))
        }

        // ── Resting Heart Rate Signal ────────────────────────────
        if let restingHR {
            let baselineDouble = Double(defaultRHRBaseline)
            let deviation = Double(restingHR) - baselineDouble
            let score: Double
            if deviation <= -3 {
                score = 1.0
            } else if deviation <= 2 {
                score = 0.7
            } else if deviation <= 6 {
                score = 0.3
            } else {
                score = 0.0
            }
            signals.append(RecoverySignal(name: "rhr", score: score, weight: 0.15))
        }

        // ── Sleep Duration Signal ────────────────────────────────
        if let sleepHours {
            let score: Double
            if sleepHours >= 7.5 {
                score = 1.0
            } else if sleepHours >= 7.0 {
                score = 0.8
            } else if sleepHours >= 6.0 {
                score = 0.5
            } else if sleepHours >= 5.0 {
                score = 0.2
            } else {
                score = 0.0
            }
            signals.append(RecoverySignal(name: "sleepDuration", score: score, weight: 0.20))
        }

        // ── Deep Sleep Signal ────────────────────────────────────
        if let deepSleep {
            let score: Double
            if deepSleep >= 90 {
                score = 1.0
            } else if deepSleep >= 60 {
                score = 0.7
            } else if deepSleep >= 40 {
                score = 0.4
            } else {
                score = 0.1
            }
            signals.append(RecoverySignal(name: "deepSleep", score: score, weight: 0.10))
        }

        // ── External Recovery Score (Whoop/Oura/etc.) ────────────
        if let recoveryScore {
            // Normalize 0–100 → 0–1
            let normalized = min(max(recoveryScore / 100.0, 0.0), 1.0)
            signals.append(RecoverySignal(name: "recoveryScore", score: normalized, weight: 0.15))
        }

        // ── Strain Signal ────────────────────────────────────────
        if let strain {
            // Higher strain → lower recovery. Normalize assuming 0–21 scale (Whoop-style).
            let normalized = min(max(strain / 21.0, 0.0), 1.0)
            let score = max(1.0 - normalized, 0.0)
            signals.append(RecoverySignal(name: "strain", score: score, weight: 0.10))
        }

        // ── Compute Composite ────────────────────────────────────
        return computeAssessment(from: signals)
    }

    // MARK: - Composite Calculation

    private struct RecoverySignal {
        let name: String
        let score: Double  // 0–1
        let weight: Double // relative importance
    }

    private func computeAssessment(from signals: [RecoverySignal]) -> RecoveryAssessment {
        guard !signals.isEmpty else {
            // No data at all — default to yellow (cautious)
            return RecoveryAssessment(
                zone: .yellow,
                confidence: 0.0,
                trainingIntensityModifier: 0.7,
                recommendations: [
                    "No wearable data available — defaulting to moderate intensity",
                    "Connect a wearable device for personalized recovery assessment",
                ]
            )
        }

        let totalWeight = signals.reduce(0.0) { $0 + $1.weight }
        let weightedSum = signals.reduce(0.0) { $0 + $1.score * $1.weight }
        let compositeScore = weightedSum / totalWeight

        // Confidence based on how many signal types we have (max 6)
        let signalCoverage = Double(signals.count) / 6.0
        let confidence = min(signalCoverage, 1.0)

        let zone: RecoveryZone
        let intensityModifier: Double
        var recommendations: [String] = []

        if compositeScore >= 0.65 {
            zone = .green
            intensityModifier = 1.0
            recommendations.append("Recovery is strong — train at full programmed intensity")
            if signalHasLowScore(signals, named: "sleepDuration") {
                recommendations.append("Sleep was below ideal despite good overall recovery — prioritize tonight")
            }
        } else if compositeScore >= 0.35 {
            zone = .yellow
            let reduction = 0.2 + (0.65 - compositeScore) / (0.65 - 0.35) * 0.2
            intensityModifier = max(1.0 - reduction, 0.6)
            recommendations.append("Recovery is moderate — reduce intensity by \(Int(reduction * 100))%")
            if signalHasLowScore(signals, named: "hrv") {
                recommendations.append("HRV below baseline — autonomic nervous system under stress")
            }
            if signalHasLowScore(signals, named: "sleepDuration") {
                recommendations.append("Insufficient sleep — consider a nap or earlier bedtime tonight")
            }
            if signalHasLowScore(signals, named: "strain") {
                recommendations.append("Previous day strain was high — allow for accumulated fatigue")
            }
        } else {
            zone = .red
            intensityModifier = max(compositeScore, 0.0)
            recommendations.append("Recovery is poor — switch to rest or gentle mobility work only")
            recommendations.append("Avoid high-intensity or heavy resistance training today")
            if signalHasLowScore(signals, named: "hrv") {
                recommendations.append("HRV significantly below baseline — parasympathetic system suppressed")
            }
            if signalHasLowScore(signals, named: "sleepDuration") {
                recommendations.append("Critical sleep deficit — prioritize 8+ hours tonight")
            }
            recommendations.append("Focus on recovery interventions: gentle breathwork, light walking, hydration")
        }

        if signals.count < 3 {
            recommendations.append("Limited data signals — assessment confidence is low")
        }

        return RecoveryAssessment(
            zone: zone,
            confidence: (confidence * 100).rounded() / 100,
            trainingIntensityModifier: (intensityModifier * 100).rounded() / 100,
            recommendations: recommendations
        )
    }

    private func signalHasLowScore(_ signals: [RecoverySignal], named name: String) -> Bool {
        guard let signal = signals.first(where: { $0.name == name }) else { return false }
        return signal.score < 0.4
    }
}
