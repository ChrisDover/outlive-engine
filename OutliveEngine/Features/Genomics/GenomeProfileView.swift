// GenomeProfileView.swift
// OutliveEngine
//
// Overview of the user's genomic profile with risk category cards.

import SwiftUI
import SwiftData

struct GenomeProfileView: View {

    @Query private var profiles: [GenomicProfile]
    @Environment(\.modelContext) private var modelContext

    private var profile: GenomicProfile? {
        profiles.first
    }

    private let riskMapper = GeneticRiskMapper()

    var body: some View {
        NavigationStack {
            Group {
                if let profile, !profile.risks.isEmpty {
                    riskListContent(profile)
                } else {
                    EmptyStateView(
                        icon: "dna",
                        title: "No Genome Data",
                        message: "Upload your raw SNP file to unlock personalized genetic insights for training, nutrition, and supplementation.",
                        actionTitle: "Upload Genome"
                    ) {
                        // Placeholder: navigate to genome upload
                    }
                }
            }
            .navigationTitle("Genomics")
            .background(Color.surfaceBackground)
        }
    }

    // MARK: - Risk List

    @ViewBuilder
    private func riskListContent(_ profile: GenomicProfile) -> some View {
        let assessments = riskMapper.mapRisks(profile.risks)

        ScrollView {
            LazyVStack(spacing: OutliveSpacing.md) {
                processedDateHeader(profile.processedDate)

                ForEach(profile.risks, id: \.category) { risk in
                    NavigationLink {
                        GeneticDetailView(
                            risk: risk,
                            assessment: assessments[risk.category]
                        )
                    } label: {
                        GeneRiskCard(risk: risk)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, OutliveSpacing.md)
            .padding(.bottom, OutliveSpacing.xl)
        }
    }

    private func processedDateHeader(_ date: Date) -> some View {
        HStack {
            Image(systemName: "calendar")
                .foregroundStyle(Color.textTertiary)

            Text("Processed \(date.formatted(date: .abbreviated, time: .omitted))")
                .font(.outliveFootnote)
                .foregroundStyle(Color.textSecondary)

            Spacer()
        }
        .padding(.vertical, OutliveSpacing.xs)
    }
}

// MARK: - Gene Risk Card

private struct GeneRiskCard: View {

    let risk: GeneticRisk

    var body: some View {
        HStack(spacing: OutliveSpacing.sm) {
            riskIndicator

            VStack(alignment: .leading, spacing: OutliveSpacing.xxs) {
                HStack(alignment: .firstTextBaseline) {
                    Text(risk.category.displayName)
                        .font(.outliveHeadline)
                        .foregroundStyle(Color.textPrimary)

                    Spacer()

                    Text(risk.genotype)
                        .font(.outliveMonoSmall)
                        .foregroundStyle(Color.textSecondary)
                        .padding(.horizontal, OutliveSpacing.xs)
                        .padding(.vertical, OutliveSpacing.xxs)
                        .background(Color.surfaceSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.small, style: .continuous))
                }

                Text(risk.snpId)
                    .font(.outliveCaption)
                    .foregroundStyle(Color.textTertiary)

                if let firstImplication = risk.implications.first {
                    Text(firstImplication)
                        .font(.outliveSubheadline)
                        .foregroundStyle(Color.textSecondary)
                        .lineLimit(2)
                }
            }

            Image(systemName: "chevron.right")
                .font(.outliveCaption)
                .foregroundStyle(Color.textTertiary)
        }
        .padding(OutliveSpacing.md)
        .background(Color.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.medium, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
    }

    private var riskIndicator: some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(riskColor)
            .frame(width: 4, height: 48)
    }

    private var riskColor: Color {
        switch risk.riskLevel {
        case 0..<0.33:  return .recoveryGreen
        case 0.33..<0.66: return .recoveryYellow
        default:         return .recoveryRed
        }
    }
}

// MARK: - RiskCategory Display Name

extension RiskCategory {

    var displayName: String {
        switch self {
        case .apoe:    return "APOE"
        case .mthfr:   return "MTHFR"
        case .cyp1a2:  return "CYP1A2"
        case .actn3:   return "ACTN3"
        case .fto:     return "FTO"
        case .vdr:     return "VDR"
        case .comt:    return "COMT"
        case .gstm1:   return "GSTM1"
        case .bcmo1:   return "BCMO1"
        case .slc23a1: return "SLC23A1"
        }
    }

    var subtitle: String {
        switch self {
        case .apoe:    return "Cardiovascular & Alzheimer's Risk"
        case .mthfr:   return "Methylation Capacity"
        case .cyp1a2:  return "Caffeine Metabolism"
        case .actn3:   return "Muscle Fiber Type"
        case .fto:     return "Appetite & Obesity Risk"
        case .vdr:     return "Vitamin D Receptor"
        case .comt:    return "Dopamine & Stress Response"
        case .gstm1:   return "Detoxification Capacity"
        case .bcmo1:   return "Beta-Carotene Conversion"
        case .slc23a1: return "Vitamin C Transport"
        }
    }
}

// MARK: - Preview

#Preview {
    GenomeProfileView()
        .modelContainer(for: GenomicProfile.self, inMemory: true)
}
