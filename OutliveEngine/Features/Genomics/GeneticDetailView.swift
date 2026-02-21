// GeneticDetailView.swift
// OutliveEngine
//
// Detail view for a single genetic risk with actionable recommendations.

import SwiftUI

struct GeneticDetailView: View {

    let risk: GeneticRisk
    let assessment: GeneticRiskAssessment?

    var body: some View {
        ScrollView {
            VStack(spacing: OutliveSpacing.lg) {
                headerSection
                riskGaugeSection
                implicationsSection

                if let assessment {
                    dietarySection(assessment.dietaryAdjustments)
                    supplementSection(assessment.supplementRecommendations)
                    trainingSection(assessment.trainingModifications)
                }
            }
            .padding(.horizontal, OutliveSpacing.md)
            .padding(.bottom, OutliveSpacing.xl)
        }
        .background(Color.surfaceBackground)
        .navigationTitle(risk.category.displayName)
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: OutliveSpacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: OutliveSpacing.xxs) {
                    Text(risk.category.subtitle)
                        .font(.outliveSubheadline)
                        .foregroundStyle(Color.textSecondary)

                    HStack(spacing: OutliveSpacing.xs) {
                        snpBadge
                        genotypeBadge
                    }
                }

                Spacer()
            }
        }
        .padding(OutliveSpacing.md)
        .background(Color.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.medium, style: .continuous))
    }

    private var snpBadge: some View {
        Text(risk.snpId)
            .font(.outliveMonoSmall)
            .foregroundStyle(Color.domainGenomics)
            .padding(.horizontal, OutliveSpacing.xs)
            .padding(.vertical, OutliveSpacing.xxs)
            .background(Color.domainGenomics.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.small, style: .continuous))
    }

    private var genotypeBadge: some View {
        Text(risk.genotype)
            .font(.outliveMonoSmall)
            .foregroundStyle(Color.textPrimary)
            .padding(.horizontal, OutliveSpacing.xs)
            .padding(.vertical, OutliveSpacing.xxs)
            .background(Color.surfaceSecondary)
            .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.small, style: .continuous))
    }

    // MARK: - Risk Gauge

    private var riskGaugeSection: some View {
        VStack(spacing: OutliveSpacing.sm) {
            SectionHeader(title: "Risk Level")

            ZStack {
                // Track arc
                RiskArc(progress: 1.0)
                    .stroke(Color.textTertiary.opacity(0.2), style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .frame(width: 180, height: 100)

                // Value arc
                RiskArc(progress: risk.riskLevel)
                    .stroke(riskColor, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .frame(width: 180, height: 100)

                VStack(spacing: 2) {
                    Text(riskLevelLabel)
                        .font(.outliveTitle3)
                        .foregroundStyle(riskColor)

                    Text("\(Int(risk.riskLevel * 100))%")
                        .font(.outliveMonoData)
                        .foregroundStyle(Color.textPrimary)
                }
                .offset(y: 10)
            }
            .frame(height: 120)
            .padding(OutliveSpacing.md)
            .frame(maxWidth: .infinity)
            .background(Color.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.medium, style: .continuous))
        }
    }

    // MARK: - Implications

    private var implicationsSection: some View {
        VStack(spacing: OutliveSpacing.sm) {
            SectionHeader(title: "Implications")

            VStack(alignment: .leading, spacing: OutliveSpacing.xs) {
                ForEach(risk.implications, id: \.self) { implication in
                    HStack(alignment: .top, spacing: OutliveSpacing.xs) {
                        Image(systemName: "info.circle.fill")
                            .font(.outliveFootnote)
                            .foregroundStyle(Color.domainGenomics)
                            .padding(.top, 2)

                        Text(implication)
                            .font(.outliveBody)
                            .foregroundStyle(Color.textPrimary)
                    }
                }
            }
            .padding(OutliveSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.medium, style: .continuous))
        }
    }

    // MARK: - Recommendation Sections

    private func dietarySection(_ items: [String]) -> some View {
        recommendationSection(
            title: "Dietary Adjustments",
            icon: "leaf.fill",
            color: .domainNutrition,
            items: items
        )
    }

    private func supplementSection(_ items: [String]) -> some View {
        recommendationSection(
            title: "Supplement Recommendations",
            icon: "pill.fill",
            color: .domainSupplements,
            items: items
        )
    }

    private func trainingSection(_ items: [String]) -> some View {
        recommendationSection(
            title: "Training Modifications",
            icon: "figure.run",
            color: .domainTraining,
            items: items
        )
    }

    @ViewBuilder
    private func recommendationSection(
        title: String,
        icon: String,
        color: Color,
        items: [String]
    ) -> some View {
        if !items.isEmpty {
            VStack(spacing: OutliveSpacing.sm) {
                SectionHeader(title: title)

                VStack(alignment: .leading, spacing: OutliveSpacing.sm) {
                    ForEach(items, id: \.self) { item in
                        HStack(alignment: .top, spacing: OutliveSpacing.xs) {
                            Image(systemName: icon)
                                .font(.outliveFootnote)
                                .foregroundStyle(color)
                                .frame(width: 20)
                                .padding(.top, 2)

                            Text(item)
                                .font(.outliveBody)
                                .foregroundStyle(Color.textPrimary)
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

    // MARK: - Helpers

    private var riskColor: Color {
        switch risk.riskLevel {
        case 0..<0.33:  return .recoveryGreen
        case 0.33..<0.66: return .recoveryYellow
        default:         return .recoveryRed
        }
    }

    private var riskLevelLabel: String {
        switch risk.riskLevel {
        case 0..<0.33:  return "Low"
        case 0.33..<0.66: return "Moderate"
        default:         return "High"
        }
    }
}

// MARK: - Risk Arc Shape

private struct RiskArc: Shape {

    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.maxY)
        let radius = min(rect.width, rect.height * 2) / 2

        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(180),
            endAngle: .degrees(180 + (180 * progress)),
            clockwise: false
        )

        return path
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        GeneticDetailView(
            risk: GeneticRisk(
                category: .apoe,
                snpId: "rs429358",
                genotype: "E3/E4",
                riskLevel: 0.65,
                implications: [
                    "Elevated cardiovascular risk with one E4 allele",
                    "Increased Alzheimer's disease susceptibility",
                    "May benefit from aggressive lipid management"
                ]
            ),
            assessment: GeneticRiskAssessment(
                category: .apoe,
                riskLevel: 0.65,
                dietaryAdjustments: [
                    "Limit saturated fat to <10% of total calories",
                    "Prioritize omega-3 fatty acids (EPA/DHA 1-2g/day)"
                ],
                supplementRecommendations: [
                    "Omega-3 (EPA/DHA) 1-2g/day",
                    "Curcumin 500mg/day with piperine"
                ],
                trainingModifications: [
                    "Include Zone 2 cardiovascular training (120+ min/week)"
                ]
            )
        )
    }
}
