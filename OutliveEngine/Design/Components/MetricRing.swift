// MetricRing.swift
// OutliveEngine
//
// Circular progress ring for displaying a single 0-1 metric.

import SwiftUI

struct MetricRing: View {

    let value: Double
    let label: String
    let color: Color
    var lineWidth: CGFloat = 8

    @State private var animatedValue: Double = 0

    var body: some View {
        VStack(spacing: OutliveSpacing.xs) {
            ZStack {
                // Track
                Circle()
                    .stroke(color.opacity(0.15), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))

                // Fill
                Circle()
                    .trim(from: 0, to: animatedValue)
                    .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                // Percentage label
                Text(percentageText)
                    .font(.outliveMonoData)
                    .foregroundStyle(Color.textPrimary)
            }

            Text(label)
                .font(.outliveCaption)
                .foregroundStyle(Color.textSecondary)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                animatedValue = clampedValue
            }
        }
        .onChange(of: value) { _, newValue in
            withAnimation(.easeOut(duration: 0.5)) {
                animatedValue = min(max(newValue, 0), 1)
            }
        }
    }

    // MARK: - Helpers

    private var clampedValue: Double {
        min(max(value, 0), 1)
    }

    private var percentageText: String {
        "\(Int(round(clampedValue * 100)))%"
    }
}

// MARK: - Preview

#Preview {
    HStack(spacing: OutliveSpacing.lg) {
        MetricRing(value: 0.82, label: "Recovery", color: .recoveryGreen)
            .frame(width: 90, height: 110)

        MetricRing(value: 0.55, label: "Readiness", color: .recoveryYellow)
            .frame(width: 90, height: 110)

        MetricRing(value: 0.25, label: "Strain", color: .recoveryRed)
            .frame(width: 90, height: 110)
    }
    .padding()
}
