// SectionHeader.swift
// OutliveEngine
//
// Reusable section header with title and optional trailing action button.

import SwiftUI

struct SectionHeader: View {

    let title: String
    var action: String? = nil
    var onAction: () -> Void = {}

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.outliveTitle3)
                .foregroundStyle(Color.textPrimary)

            Spacer()

            if let actionTitle = action {
                Button(action: onAction) {
                    Text(actionTitle)
                        .font(.outliveSubheadline)
                        .foregroundStyle(Color.domainTraining)
                }
            }
        }
        .padding(.horizontal, OutliveSpacing.md)
        .padding(.vertical, OutliveSpacing.xs)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: OutliveSpacing.lg) {
        SectionHeader(title: "Today's Protocols")
        SectionHeader(title: "Bloodwork", action: "View All") { }
        SectionHeader(title: "Supplements", action: "Edit Stack") { }
    }
    .padding()
}
