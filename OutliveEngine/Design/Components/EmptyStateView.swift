// EmptyStateView.swift
// OutliveEngine
//
// Centered empty-state placeholder with icon, messaging, and optional CTA.

import SwiftUI

struct EmptyStateView: View {

    let icon: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: OutliveSpacing.md) {
            Spacer()

            Image(systemName: icon)
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(Color.textTertiary)
                .padding(.bottom, OutliveSpacing.xs)

            Text(title)
                .font(.outliveTitle3)
                .foregroundStyle(Color.textPrimary)
                .multilineTextAlignment(.center)

            Text(message)
                .font(.outliveBody)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, OutliveSpacing.xl)

            if let actionTitle, let action {
                OutliveButton(title: actionTitle, style: .primary, action: action)
                    .padding(.horizontal, OutliveSpacing.xxl)
                    .padding(.top, OutliveSpacing.xs)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview

#Preview("No Data") {
    EmptyStateView(
        icon: "chart.line.downtrend.xyaxis",
        title: "No Bloodwork Yet",
        message: "Import your latest lab results to see biomarker trends and personalized insights.",
        actionTitle: "Import Labs"
    ) { }
}

#Preview("Empty List") {
    EmptyStateView(
        icon: "pill",
        title: "No Supplements",
        message: "Add supplements to build your daily stack."
    )
}
