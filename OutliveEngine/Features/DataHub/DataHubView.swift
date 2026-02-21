// DataHubView.swift
// OutliveEngine
//
// Central hub for all health data: genomics, bloodwork, body composition, and insights.

import SwiftUI

struct DataHubView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: OutliveSpacing.lg) {
                dataSection(
                    title: "Genomics",
                    icon: "dna",
                    color: .domainGenomics,
                    description: "Genetic risk analysis"
                ) {
                    GenomeProfileView()
                }

                dataSection(
                    title: "Bloodwork",
                    icon: "drop.fill",
                    color: .domainBloodwork,
                    description: "Lab panel history & trends"
                ) {
                    BloodworkHistoryView()
                }

                dataSection(
                    title: "Body Composition",
                    icon: "figure.stand",
                    color: .domainTraining,
                    description: "Weight, body fat, muscle mass"
                ) {
                    BodyCompositionView()
                }

                dataSection(
                    title: "Insights",
                    icon: "chart.line.uptrend.xyaxis",
                    color: .domainSleep,
                    description: "Trends & AI analysis"
                ) {
                    TrendsView()
                }
            }
            .padding(.horizontal, OutliveSpacing.md)
            .padding(.vertical, OutliveSpacing.sm)
        }
        .background(Color.surfaceBackground)
    }

    // MARK: - Section Builder

    private func dataSection<Destination: View>(
        title: String,
        icon: String,
        color: Color,
        description: String,
        @ViewBuilder destination: @escaping () -> Destination
    ) -> some View {
        NavigationLink {
            destination()
                .navigationTitle(title)
        } label: {
            HStack(spacing: OutliveSpacing.md) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                    .frame(width: 44, height: 44)
                    .background(color.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.small))

                VStack(alignment: .leading, spacing: OutliveSpacing.xxs) {
                    Text(title)
                        .font(.outliveHeadline)
                        .foregroundStyle(Color.textPrimary)
                    Text(description)
                        .font(.outliveCaption)
                        .foregroundStyle(Color.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.outliveCaption)
                    .foregroundStyle(Color.textTertiary)
            }
            .padding(OutliveSpacing.md)
            .background(Color.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.medium))
        }
    }
}

#Preview {
    NavigationStack {
        DataHubView()
            .navigationTitle("Data")
    }
    .modelContainer(try! DataStore.previewContainer())
}
