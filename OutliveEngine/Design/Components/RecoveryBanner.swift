// RecoveryBanner.swift
// OutliveEngine
//
// Full-width banner displaying the current recovery zone with key biometrics.

import SwiftUI

struct RecoveryBanner: View {

    let recoveryZone: RecoveryZone
    let hrvMs: Double?
    let restingHR: Int?
    let sleepHours: Double?

    var body: some View {
        HStack(spacing: OutliveSpacing.md) {
            zoneLabel
            Spacer()
            metricsRow
        }
        .padding(OutliveSpacing.md)
        .background(zoneBackground)
        .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.medium, style: .continuous))
        .shadow(color: zoneColor.opacity(0.3), radius: 8, x: 0, y: 4)
    }

    // MARK: - Subviews

    private var zoneLabel: some View {
        VStack(alignment: .leading, spacing: OutliveSpacing.xxs) {
            Text("Recovery Zone")
                .font(.outliveCaption)
                .foregroundStyle(.white.opacity(0.8))

            Text(zoneName)
                .font(.outliveTitle3)
                .fontWeight(.bold)
                .foregroundStyle(.white)
        }
    }

    private var metricsRow: some View {
        HStack(spacing: OutliveSpacing.sm) {
            if let hrv = hrvMs {
                metricPill(value: String(format: "%.0f", hrv), unit: "ms", label: "HRV")
            }
            if let rhr = restingHR {
                metricPill(value: "\(rhr)", unit: "bpm", label: "RHR")
            }
            if let sleep = sleepHours {
                metricPill(value: String(format: "%.1f", sleep), unit: "hr", label: "Sleep")
            }
        }
    }

    private func metricPill(value: String, unit: String, label: String) -> some View {
        VStack(spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.outliveMonoData)
                    .foregroundStyle(.white)
                Text(unit)
                    .font(.outliveMonoSmall)
                    .foregroundStyle(.white.opacity(0.7))
            }
            Text(label)
                .font(.outliveCaption)
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.horizontal, OutliveSpacing.xs)
        .padding(.vertical, OutliveSpacing.xxs)
        .background(.white.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.small, style: .continuous))
    }

    // MARK: - Helpers

    private var zoneColor: Color {
        switch recoveryZone {
        case .green:  return .recoveryGreen
        case .yellow: return .recoveryYellow
        case .red:    return .recoveryRed
        }
    }

    private var zoneBackground: some ShapeStyle {
        zoneColor.gradient
    }

    private var zoneName: String {
        switch recoveryZone {
        case .green:  return "Green — Go"
        case .yellow: return "Yellow — Moderate"
        case .red:    return "Red — Recover"
        }
    }
}

// MARK: - Preview

#Preview("Green Zone") {
    RecoveryBanner(
        recoveryZone: .green,
        hrvMs: 62,
        restingHR: 54,
        sleepHours: 7.8
    )
    .padding()
}

#Preview("Red Zone") {
    RecoveryBanner(
        recoveryZone: .red,
        hrvMs: 28,
        restingHR: 72,
        sleepHours: 4.5
    )
    .padding()
}
