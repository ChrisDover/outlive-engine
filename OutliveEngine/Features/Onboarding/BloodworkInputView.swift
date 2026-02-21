// BloodworkInputView.swift
// OutliveEngine
//
// Allows manual entry of key biomarkers or camera-based OCR (placeholder).
// This step is optional and can be skipped.

import SwiftUI

struct BloodworkInputView: View {
    @Bindable var viewModel: OnboardingViewModel
    @State private var inputMode: BloodworkInputMode = .manual

    var body: some View {
        VStack(spacing: 0) {
            OnboardingStepHeader(step: .bloodwork, progress: viewModel.progress)

            Text("Enter your most recent lab results for personalized protocols.")
                .font(.outliveCallout)
                .foregroundStyle(Color.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, OutliveSpacing.md)
                .padding(.top, OutliveSpacing.xs)

            modePicker

            switch inputMode {
            case .camera:
                cameraPlaceholder
            case .manual:
                manualEntryList
            }

            Spacer()

            buttonSection
        }
        .background(Color.surfaceBackground)
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { viewModel.previous() } label: {
                    Image(systemName: "chevron.left")
                        .font(.outliveHeadline)
                }
            }
        }
        .onAppear { viewModel.currentStep = .bloodwork }
    }

    // MARK: - Mode Picker

    private var modePicker: some View {
        Picker("Input Mode", selection: $inputMode) {
            Text("Manual Entry").tag(BloodworkInputMode.manual)
            Text("Camera OCR").tag(BloodworkInputMode.camera)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, OutliveSpacing.md)
        .padding(.top, OutliveSpacing.md)
    }

    // MARK: - Camera Placeholder

    private var cameraPlaceholder: some View {
        VStack(spacing: OutliveSpacing.md) {
            Spacer()

            Image(systemName: "doc.text.viewfinder")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(Color.textTertiary)

            Text("Camera OCR Coming Soon")
                .font(.outliveTitle3)
                .foregroundStyle(Color.textPrimary)

            Text("Point your camera at your lab results and we will extract the values automatically.")
                .font(.outliveCallout)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, OutliveSpacing.xl)

            Spacer()
        }
    }

    // MARK: - Manual Entry

    private var manualEntryList: some View {
        ScrollView {
            VStack(spacing: OutliveSpacing.sm) {
                ForEach(BiomarkerField.allCases) { field in
                    BiomarkerInputRow(
                        field: field,
                        value: Binding(
                            get: { viewModel.bloodworkValues[field.id] ?? "" },
                            set: { viewModel.bloodworkValues[field.id] = $0 }
                        )
                    )
                }
            }
            .padding(.horizontal, OutliveSpacing.md)
            .padding(.top, OutliveSpacing.md)
            .padding(.bottom, OutliveSpacing.xl)
        }
    }

    // MARK: - Buttons

    private var buttonSection: some View {
        VStack(spacing: OutliveSpacing.sm) {
            OutliveButton(title: "Continue", style: .primary) {
                viewModel.next()
            }

            Button("Skip for Now") {
                viewModel.skipStep()
            }
            .font(.outliveSubheadline)
            .foregroundStyle(Color.textSecondary)
        }
        .padding(.horizontal, OutliveSpacing.md)
        .padding(.bottom, OutliveSpacing.lg)
    }
}

// MARK: - Input Mode

private enum BloodworkInputMode: String, CaseIterable, Sendable {
    case manual
    case camera
}

// MARK: - Biomarker Field

private enum BiomarkerField: String, CaseIterable, Identifiable, Sendable {
    case testosterone
    case vitaminD
    case b12
    case ferritin
    case fastingGlucose
    case hba1c
    case hsCRP
    case apoB

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .testosterone:   "Testosterone"
        case .vitaminD:       "Vitamin D"
        case .b12:            "Vitamin B12"
        case .ferritin:       "Ferritin"
        case .fastingGlucose: "Fasting Glucose"
        case .hba1c:          "HbA1c"
        case .hsCRP:          "hsCRP"
        case .apoB:           "ApoB"
        }
    }

    var unit: String {
        switch self {
        case .testosterone:   "ng/dL"
        case .vitaminD:       "ng/mL"
        case .b12:            "pg/mL"
        case .ferritin:       "ng/mL"
        case .fastingGlucose: "mg/dL"
        case .hba1c:          "%"
        case .hsCRP:          "mg/L"
        case .apoB:           "mg/dL"
        }
    }
}

// MARK: - Biomarker Input Row

private struct BiomarkerInputRow: View {
    let field: BiomarkerField
    @Binding var value: String

    var body: some View {
        HStack(spacing: OutliveSpacing.sm) {
            Text(field.displayName)
                .font(.outliveBody)
                .foregroundStyle(Color.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            TextField("--", text: $value)
                .font(.outliveMonoData)
                .foregroundStyle(Color.textPrimary)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)

            Text(field.unit)
                .font(.outliveMonoSmall)
                .foregroundStyle(Color.textSecondary)
                .frame(width: 52, alignment: .leading)
        }
        .padding(OutliveSpacing.sm)
        .background(Color.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.small, style: .continuous))
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        BloodworkInputView(viewModel: OnboardingViewModel())
            .environment(AppState())
    }
}
