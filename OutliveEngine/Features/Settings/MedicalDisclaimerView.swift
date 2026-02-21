// MedicalDisclaimerView.swift
// OutliveEngine
//
// Medical disclaimer text with acknowledgment toggle.

import SwiftUI

struct MedicalDisclaimerView: View {

    @State private var hasAcknowledged = false
    @AppStorage("medicalDisclaimerAcknowledged") private var disclaimerAcknowledged = false

    var body: some View {
        ScrollView {
            VStack(spacing: OutliveSpacing.lg) {
                warningBanner
                disclaimerText
                consultSection
                acknowledgmentSection
            }
            .padding(.horizontal, OutliveSpacing.md)
            .padding(.bottom, OutliveSpacing.xl)
        }
        .background(Color.surfaceBackground)
        .navigationTitle("Medical Disclaimer")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            hasAcknowledged = disclaimerAcknowledged
        }
    }

    // MARK: - Warning Banner

    private var warningBanner: some View {
        HStack(spacing: OutliveSpacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.outliveTitle2)
                .foregroundStyle(Color.recoveryYellow)

            Text("This app does not provide medical advice.")
                .font(.outliveHeadline)
                .foregroundStyle(Color.textPrimary)
        }
        .padding(OutliveSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.recoveryYellow.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.medium, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.medium, style: .continuous)
                .strokeBorder(Color.recoveryYellow.opacity(0.3), lineWidth: 1)
        }
    }

    // MARK: - Disclaimer Text

    private var disclaimerText: some View {
        VStack(alignment: .leading, spacing: OutliveSpacing.md) {
            disclaimerParagraph(
                title: "General Information Only",
                text: "Outlive Engine is designed for informational and educational purposes only. The content provided by this application, including but not limited to genetic risk assessments, bloodwork analysis, supplement recommendations, training protocols, and AI-generated insights, is not intended to be a substitute for professional medical advice, diagnosis, or treatment."
            )

            disclaimerParagraph(
                title: "No Doctor-Patient Relationship",
                text: "Use of this application does not create a doctor-patient relationship. The information presented is based on published research and general health optimization principles but has not been evaluated for your specific medical situation."
            )

            disclaimerParagraph(
                title: "Genetic Information",
                text: "Genetic risk assessments provided by this app are based on known research associations and may not reflect the full complexity of gene-gene and gene-environment interactions. Genetic information should not be used as the sole basis for making health decisions."
            )

            disclaimerParagraph(
                title: "Supplement Recommendations",
                text: "Supplement suggestions are based on general research and your genomic profile. Supplements can interact with medications and medical conditions. Always consult your healthcare provider before starting any new supplement regimen."
            )

            disclaimerParagraph(
                title: "Bloodwork Interpretation",
                text: "Biomarker analysis uses optimal ranges derived from longevity-focused research, which may differ from standard laboratory reference ranges. Your healthcare provider should interpret your lab results in the context of your complete medical history."
            )

            disclaimerParagraph(
                title: "Limitation of Liability",
                text: "The developers and contributors of Outlive Engine shall not be held liable for any health outcomes resulting from the use of information provided by this application. You assume full responsibility for how you use the information presented."
            )
        }
        .padding(OutliveSpacing.md)
        .background(Color.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.medium, style: .continuous))
    }

    private func disclaimerParagraph(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: OutliveSpacing.xs) {
            Text(title)
                .font(.outliveHeadline)
                .foregroundStyle(Color.textPrimary)

            Text(text)
                .font(.outliveBody)
                .foregroundStyle(Color.textSecondary)
        }
    }

    // MARK: - Consult Section

    private var consultSection: some View {
        VStack(alignment: .leading, spacing: OutliveSpacing.sm) {
            SectionHeader(title: "Always Consult Your Provider")

            VStack(alignment: .leading, spacing: OutliveSpacing.xs) {
                consultItem(icon: "stethoscope", text: "Before making changes to your diet, supplement, or exercise routine")
                consultItem(icon: "pills.fill", text: "Before starting or stopping any medication or supplement")
                consultItem(icon: "waveform.path.ecg", text: "If you experience any unusual symptoms or health concerns")
                consultItem(icon: "cross.case.fill", text: "For interpretation of lab results and genetic data")
                consultItem(icon: "person.2.fill", text: "For personalized medical advice specific to your health history")
            }
            .padding(OutliveSpacing.md)
            .background(Color.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.medium, style: .continuous))
        }
    }

    private func consultItem(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: OutliveSpacing.xs) {
            Image(systemName: icon)
                .font(.outliveFootnote)
                .foregroundStyle(Color.domainBloodwork)
                .frame(width: 20)
                .padding(.top, 2)

            Text(text)
                .font(.outliveBody)
                .foregroundStyle(Color.textPrimary)
        }
    }

    // MARK: - Acknowledgment

    private var acknowledgmentSection: some View {
        VStack(spacing: OutliveSpacing.sm) {
            Toggle(isOn: $hasAcknowledged) {
                Text("I understand that Outlive Engine does not provide medical advice and I will consult a qualified healthcare provider for medical decisions.")
                    .font(.outliveSubheadline)
                    .foregroundStyle(Color.textPrimary)
            }
            .tint(Color.recoveryGreen)
            .onChange(of: hasAcknowledged) { _, newValue in
                disclaimerAcknowledged = newValue
            }
        }
        .padding(OutliveSpacing.md)
        .background(Color.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.medium, style: .continuous))
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        MedicalDisclaimerView()
    }
}
