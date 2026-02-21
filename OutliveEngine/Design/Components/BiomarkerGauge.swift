// BiomarkerGauge.swift
// OutliveEngine
//
// Horizontal gauge visualizing a biomarker value within optimal/normal/out-of-range bands.

import SwiftUI

struct BiomarkerGauge: View {

    let name: String
    let value: Double
    let unit: String
    let optimalLow: Double
    let optimalHigh: Double
    let normalLow: Double
    let normalHigh: Double

    var body: some View {
        VStack(alignment: .leading, spacing: OutliveSpacing.xs) {
            headerRow
            gaugeBar
            rangeLabels
        }
        .padding(OutliveSpacing.md)
        .background(Color.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.medium, style: .continuous))
    }

    // MARK: - Subviews

    private var headerRow: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(name)
                .font(.outliveHeadline)
                .foregroundStyle(Color.textPrimary)

            Spacer()

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(formattedValue)
                    .font(.outliveMonoData)
                    .foregroundStyle(statusColor)

                Text(unit)
                    .font(.outliveMonoSmall)
                    .foregroundStyle(Color.textSecondary)
            }
        }
    }

    private var gaugeBar: some View {
        GeometryReader { geometry in
            let width = geometry.size.width

            ZStack(alignment: .leading) {
                // Background zones
                HStack(spacing: 0) {
                    // Out-of-range low (red)
                    Rectangle()
                        .fill(Color.recoveryRed.opacity(0.3))
                        .frame(width: zoneFraction(from: displayLow, to: normalLow) * width)

                    // Normal low (yellow)
                    Rectangle()
                        .fill(Color.recoveryYellow.opacity(0.3))
                        .frame(width: zoneFraction(from: normalLow, to: optimalLow) * width)

                    // Optimal (green)
                    Rectangle()
                        .fill(Color.recoveryGreen.opacity(0.3))
                        .frame(width: zoneFraction(from: optimalLow, to: optimalHigh) * width)

                    // Normal high (yellow)
                    Rectangle()
                        .fill(Color.recoveryYellow.opacity(0.3))
                        .frame(width: zoneFraction(from: optimalHigh, to: normalHigh) * width)

                    // Out-of-range high (red)
                    Rectangle()
                        .fill(Color.recoveryRed.opacity(0.3))
                        .frame(width: zoneFraction(from: normalHigh, to: displayHigh) * width)
                }

                // Value marker
                marker(in: width)
            }
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
        .frame(height: 12)
    }

    private func marker(in totalWidth: CGFloat) -> some View {
        let fraction = markerFraction
        let xOffset = fraction * totalWidth

        return Circle()
            .fill(statusColor)
            .frame(width: 14, height: 14)
            .shadow(color: statusColor.opacity(0.4), radius: 3, x: 0, y: 1)
            .offset(x: xOffset - 7) // center the 14pt circle
    }

    private var rangeLabels: some View {
        HStack {
            Text(formatNumber(normalLow))
                .font(.outliveCaption)
                .foregroundStyle(Color.textTertiary)

            Spacer()

            Text("Optimal: \(formatNumber(optimalLow))–\(formatNumber(optimalHigh))")
                .font(.outliveCaption)
                .foregroundStyle(Color.recoveryGreen)

            Spacer()

            Text(formatNumber(normalHigh))
                .font(.outliveCaption)
                .foregroundStyle(Color.textTertiary)
        }
    }

    // MARK: - Calculations

    /// Padded lower display bound (20% below normal low).
    private var displayLow: Double {
        normalLow - (normalHigh - normalLow) * 0.2
    }

    /// Padded upper display bound (20% above normal high).
    private var displayHigh: Double {
        normalHigh + (normalHigh - normalLow) * 0.2
    }

    private var displayRange: Double {
        displayHigh - displayLow
    }

    private func zoneFraction(from lower: Double, to upper: Double) -> CGFloat {
        guard displayRange > 0 else { return 0 }
        return max(0, (upper - lower) / displayRange)
    }

    private var markerFraction: CGFloat {
        guard displayRange > 0 else { return 0.5 }
        let clamped = min(max(value, displayLow), displayHigh)
        return (clamped - displayLow) / displayRange
    }

    private var statusColor: Color {
        if value >= optimalLow && value <= optimalHigh {
            return .recoveryGreen
        } else if value >= normalLow && value <= normalHigh {
            return .recoveryYellow
        } else {
            return .recoveryRed
        }
    }

    // MARK: - Formatting

    private var formattedValue: String {
        formatNumber(value)
    }

    private func formatNumber(_ n: Double) -> String {
        if n == n.rounded() && abs(n) < 10_000 {
            return String(format: "%.0f", n)
        }
        return String(format: "%.1f", n)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: OutliveSpacing.md) {
        BiomarkerGauge(
            name: "Testosterone",
            value: 680,
            unit: "ng/dL",
            optimalLow: 600,
            optimalHigh: 900,
            normalLow: 300,
            normalHigh: 1000
        )

        BiomarkerGauge(
            name: "Vitamin D",
            value: 38,
            unit: "ng/mL",
            optimalLow: 50,
            optimalHigh: 80,
            normalLow: 30,
            normalHigh: 100
        )

        BiomarkerGauge(
            name: "hsCRP",
            value: 3.2,
            unit: "mg/L",
            optimalLow: 0,
            optimalHigh: 1,
            normalLow: 0,
            normalHigh: 3
        )
    }
    .padding()
    .background(Color.surfaceBackground)
}
