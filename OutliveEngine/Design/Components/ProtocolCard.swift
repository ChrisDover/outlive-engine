// ProtocolCard.swift
// OutliveEngine
//
// Expandable card used to present a protocol summary with domain-colored accent.

import SwiftUI

struct ProtocolCard<Detail: View>: View {

    let icon: String
    let title: String
    let accentColor: Color
    let summary: String
    @ViewBuilder let detail: () -> Detail

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if isExpanded {
                Divider()
                    .padding(.leading, OutliveSpacing.md)

                detail()
                    .padding(OutliveSpacing.md)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.medium, style: .continuous))
        .overlay(alignment: .leading) {
            accentStrip
        }
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
    }

    // MARK: - Subviews

    private var header: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: OutliveSpacing.sm) {
                Image(systemName: icon)
                    .font(.outliveTitle3)
                    .foregroundStyle(accentColor)
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: OutliveSpacing.xxs) {
                    Text(title)
                        .font(.outliveHeadline)
                        .foregroundStyle(Color.textPrimary)

                    Text(summary)
                        .font(.outliveSubheadline)
                        .foregroundStyle(Color.textSecondary)
                        .lineLimit(isExpanded ? nil : 2)
                }

                Spacer()

                Image(systemName: "chevron.down")
                    .font(.outliveFootnote)
                    .foregroundStyle(Color.textTertiary)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
            .padding(OutliveSpacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var accentStrip: some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(accentColor)
            .frame(width: 4)
            .padding(.vertical, OutliveSpacing.xs)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: OutliveSpacing.md) {
        ProtocolCard(
            icon: "dumbbell.fill",
            title: "Strength Protocol",
            accentColor: .domainTraining,
            summary: "Upper-body push focus — bench, OHP, dips"
        ) {
            Text("Detailed program content goes here.")
                .font(.outliveBody)
                .foregroundStyle(Color.textSecondary)
        }

        ProtocolCard(
            icon: "pill.fill",
            title: "Morning Stack",
            accentColor: .domainSupplements,
            summary: "Creatine 5g, Vitamin D3 5000 IU, Omega-3 2g"
        ) {
            Text("Full supplement breakdown here.")
                .font(.outliveBody)
                .foregroundStyle(Color.textSecondary)
        }
    }
    .padding()
    .background(Color.surfaceBackground)
}
