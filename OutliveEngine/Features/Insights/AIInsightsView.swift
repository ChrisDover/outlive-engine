// AIInsightsView.swift
// OutliveEngine
//
// Placeholder for AI-generated insights with card-based layout.

import SwiftUI

struct AIInsightsView: View {

    @State private var isGenerating = false
    @State private var insights: [InsightDisplayItem] = InsightDisplayItem.placeholders

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: OutliveSpacing.lg) {
                    headerSection
                    insightCards
                    generateButton
                }
                .padding(.horizontal, OutliveSpacing.md)
                .padding(.bottom, OutliveSpacing.xl)
            }
            .navigationTitle("AI Insights")
            .background(Color.surfaceBackground)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: OutliveSpacing.xs) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.outliveTitle2)
                    .foregroundStyle(Color.domainSupplements)

                VStack(alignment: .leading, spacing: OutliveSpacing.xxs) {
                    Text("Personalized Analysis")
                        .font(.outliveTitle3)
                        .foregroundStyle(Color.textPrimary)

                    Text("Insights generated from your genomic, bloodwork, wearable, and protocol data.")
                        .font(.outliveSubheadline)
                        .foregroundStyle(Color.textSecondary)
                }
            }
        }
        .padding(OutliveSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.medium, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
    }

    // MARK: - Insight Cards

    private var insightCards: some View {
        ForEach(insights) { insight in
            InsightCard(insight: insight)
        }
    }

    // MARK: - Generate Button

    private var generateButton: some View {
        OutliveButton(
            title: isGenerating ? "Generating..." : "Generate Insights",
            style: .primary,
            isLoading: isGenerating
        ) {
            generateInsights()
        }
        .padding(.horizontal, OutliveSpacing.md)
    }

    // MARK: - Actions

    private func generateInsights() {
        isGenerating = true
        // Placeholder: In production, this would call the AI engine
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isGenerating = false
        }
    }
}

// MARK: - Insight Card

private struct InsightCard: View {

    let insight: InsightDisplayItem

    var body: some View {
        VStack(alignment: .leading, spacing: OutliveSpacing.sm) {
            HStack {
                Image(systemName: insight.icon)
                    .font(.outliveTitle3)
                    .foregroundStyle(insight.color)
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: OutliveSpacing.xxs) {
                    Text(insight.category)
                        .font(.outliveCaption)
                        .foregroundStyle(insight.color)

                    Text(insight.title)
                        .font(.outliveHeadline)
                        .foregroundStyle(Color.textPrimary)
                }

                Spacer()
            }

            Text(insight.summary)
                .font(.outliveBody)
                .foregroundStyle(Color.textSecondary)

            HStack(spacing: OutliveSpacing.xs) {
                Image(systemName: "chart.bar.doc.horizontal")
                    .font(.outliveCaption)
                    .foregroundStyle(Color.textTertiary)

                Text("Based on: \(insight.sourceData)")
                    .font(.outliveCaption)
                    .foregroundStyle(Color.textTertiary)
            }
        }
        .padding(OutliveSpacing.md)
        .background(Color.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.medium, style: .continuous))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(insight.color)
                .frame(width: 4)
                .padding(.vertical, OutliveSpacing.xs)
        }
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
    }
}

// MARK: - AI Insight Model

private struct InsightDisplayItem: Identifiable {
    let id = UUID()
    let category: String
    let title: String
    let summary: String
    let sourceData: String
    let icon: String
    let color: Color

    static let placeholders: [InsightDisplayItem] = [
        InsightDisplayItem(
            category: "Recovery",
            title: "Sleep Quality Declining",
            summary: "Your deep sleep has decreased 18% over the past two weeks. This correlates with increased evening screen time. Consider enforcing your digital sunset protocol.",
            sourceData: "Wearable sleep data, 14-day trend",
            icon: "bed.double.fill",
            color: .domainSleep
        ),
        InsightDisplayItem(
            category: "Nutrition",
            title: "Vitamin D Optimization Needed",
            summary: "Based on your VDR gene variant and last bloodwork panel showing 38 ng/mL, increasing D3 supplementation to 5000 IU/day with K2 is recommended to reach your 60-80 ng/mL target.",
            sourceData: "Genomic profile (VDR), Bloodwork panel",
            icon: "sun.max.fill",
            color: .domainNutrition
        ),
        InsightDisplayItem(
            category: "Training",
            title: "Strength Plateau Detected",
            summary: "Your grip strength metrics have been flat for 3 weeks. Given your ACTN3 RX genotype, consider adding dedicated power work and increasing training variety.",
            sourceData: "Experiment data, Genomic profile (ACTN3)",
            icon: "dumbbell.fill",
            color: .domainTraining
        ),
        InsightDisplayItem(
            category: "Metabolic",
            title: "Glucose Response Improving",
            summary: "Post-meal glucose spikes have decreased 12% since adding post-meal walks. Your fasting glucose trend is moving toward optimal. Maintain current protocol.",
            sourceData: "Bloodwork trend, Activity data",
            icon: "chart.line.downtrend.xyaxis",
            color: .recoveryGreen
        ),
    ]
}

// MARK: - Preview

#Preview {
    AIInsightsView()
}
