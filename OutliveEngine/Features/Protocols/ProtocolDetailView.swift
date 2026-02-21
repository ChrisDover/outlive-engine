// ProtocolDetailView.swift
// OutliveEngine
//
// Detail view for a single ProtocolSource showing rules, evidence, and controls.

import SwiftUI

struct ProtocolDetailView: View {

    @Bindable var protocolSource: ProtocolSource

    var body: some View {
        ScrollView {
            VStack(spacing: OutliveSpacing.lg) {
                headerSection
                controlsSection
                rulesSection
            }
            .padding(.horizontal, OutliveSpacing.md)
            .padding(.bottom, OutliveSpacing.xl)
        }
        .background(Color.surfaceBackground)
        .navigationTitle(protocolSource.name)
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: OutliveSpacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: OutliveSpacing.xxs) {
                    Text("by \(protocolSource.author)")
                        .font(.outliveSubheadline)
                        .foregroundStyle(Color.textSecondary)

                    HStack(spacing: OutliveSpacing.xs) {
                        categoryBadge
                        evidenceBadge
                    }
                }

                Spacer()
            }
        }
        .padding(OutliveSpacing.md)
        .background(Color.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.medium, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
    }

    private var categoryBadge: some View {
        Text(protocolSource.category.capitalized)
            .font(.outliveCaption)
            .foregroundStyle(Color.domainTraining)
            .padding(.horizontal, OutliveSpacing.xs)
            .padding(.vertical, 2)
            .background(Color.domainTraining.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.small, style: .continuous))
    }

    private var evidenceBadge: some View {
        Text(protocolSource.evidenceLevel.displayLabel)
            .font(.outliveCaption)
            .foregroundStyle(protocolSource.evidenceLevel.color)
            .padding(.horizontal, OutliveSpacing.xs)
            .padding(.vertical, 2)
            .background(protocolSource.evidenceLevel.color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.small, style: .continuous))
    }

    // MARK: - Controls

    private var controlsSection: some View {
        VStack(spacing: OutliveSpacing.sm) {
            HStack {
                Text("Active")
                    .font(.outliveHeadline)
                    .foregroundStyle(Color.textPrimary)

                Spacer()

                Toggle("", isOn: $protocolSource.isActive)
                    .labelsHidden()
                    .tint(Color.recoveryGreen)
            }

            Divider()

            HStack {
                Text("Priority")
                    .font(.outliveHeadline)
                    .foregroundStyle(Color.textPrimary)

                Spacer()

                HStack(spacing: OutliveSpacing.sm) {
                    Button {
                        if protocolSource.priority > 0 {
                            protocolSource.priority -= 1
                        }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.outliveTitle3)
                            .foregroundStyle(Color.textSecondary)
                    }
                    .disabled(protocolSource.priority <= 0)

                    Text("\(protocolSource.priority)")
                        .font(.outliveMonoData)
                        .foregroundStyle(Color.textPrimary)
                        .frame(minWidth: 30)

                    Button {
                        protocolSource.priority += 1
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.outliveTitle3)
                            .foregroundStyle(Color.domainTraining)
                    }
                }
            }
        }
        .padding(OutliveSpacing.md)
        .background(Color.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.medium, style: .continuous))
    }

    // MARK: - Rules

    private var rulesSection: some View {
        VStack(spacing: OutliveSpacing.sm) {
            SectionHeader(title: "Rules")

            if protocolSource.rules.isEmpty {
                Text("No rules defined for this protocol.")
                    .font(.outliveBody)
                    .foregroundStyle(Color.textSecondary)
                    .padding(OutliveSpacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.surfaceCard)
                    .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.medium, style: .continuous))
            } else {
                VStack(alignment: .leading, spacing: OutliveSpacing.sm) {
                    ForEach(Array(protocolSource.rules.enumerated()), id: \.offset) { index, rule in
                        HStack(alignment: .top, spacing: OutliveSpacing.xs) {
                            Text("\(index + 1).")
                                .font(.outliveMonoSmall)
                                .foregroundStyle(Color.domainTraining)
                                .frame(width: 24, alignment: .trailing)

                            Text(rule)
                                .font(.outliveBody)
                                .foregroundStyle(Color.textPrimary)
                        }

                        if index < protocolSource.rules.count - 1 {
                            Divider().padding(.leading, 32)
                        }
                    }
                }
                .padding(OutliveSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.surfaceCard)
                .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.medium, style: .continuous))
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ProtocolDetailView(
            protocolSource: ProtocolSource(
                userId: "preview",
                name: "Attia Longevity Framework",
                author: "Peter Attia",
                category: "longevity",
                rules: [
                    "Zone 2 training 150-180 min/week",
                    "Strength training 3-4x/week emphasizing grip, hip hinge, carry",
                    "ApoB target < 60 mg/dL",
                    "Monitor and optimize sleep quality metrics",
                    "Maintain muscle mass as primary longevity lever"
                ],
                evidenceLevel: .rct,
                isActive: true,
                priority: 1
            )
        )
    }
}
