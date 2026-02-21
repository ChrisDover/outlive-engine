// ProtocolSelectionView.swift
// OutliveEngine
//
// Final onboarding step. Users enable/disable protocol sources and drag
// to reorder priority. At least one source must be enabled to complete setup.

import SwiftUI

struct ProtocolSelectionView: View {
    @Bindable var viewModel: OnboardingViewModel
    let onComplete: () -> Void

    @State private var editMode: EditMode = .active

    var body: some View {
        VStack(spacing: 0) {
            OnboardingStepHeader(step: .protocolSelection, progress: viewModel.progress)

            Text("Choose the protocol sources that will power your daily stack. Drag to set priority order.")
                .font(.outliveCallout)
                .foregroundStyle(Color.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, OutliveSpacing.md)
                .padding(.top, OutliveSpacing.xs)

            protocolList

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
        .environment(\.editMode, $editMode)
        .onAppear { viewModel.currentStep = .protocolSelection }
    }

    // MARK: - Protocol List

    private var protocolList: some View {
        List {
            ForEach($viewModel.protocolSources) { $source in
                ProtocolSourceRow(source: $source)
                    .listRowBackground(Color.surfaceCard)
                    .listRowSeparatorTint(Color.textTertiary.opacity(0.3))
            }
            .onMove { indices, destination in
                viewModel.protocolSources.move(fromOffsets: indices, toOffset: destination)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Buttons

    private var buttonSection: some View {
        VStack(spacing: OutliveSpacing.sm) {
            let enabledCount = viewModel.protocolSources.filter(\.isEnabled).count

            OutliveButton(title: "Complete Setup", style: .primary) {
                onComplete()
            }
            .disabled(enabledCount == 0)
            .opacity(enabledCount > 0 ? 1.0 : 0.5)

            Text("\(enabledCount) source\(enabledCount == 1 ? "" : "s") enabled")
                .font(.outliveFootnote)
                .foregroundStyle(Color.textSecondary)
        }
        .padding(.horizontal, OutliveSpacing.md)
        .padding(.bottom, OutliveSpacing.lg)
    }
}

// MARK: - Protocol Source Row

private struct ProtocolSourceRow: View {
    @Binding var source: OnboardingProtocolEntry

    var body: some View {
        HStack(spacing: OutliveSpacing.md) {
            VStack(alignment: .leading, spacing: OutliveSpacing.xxs) {
                Text("\(source.author) - \(source.name)")
                    .font(.outliveHeadline)
                    .foregroundStyle(source.isEnabled ? Color.textPrimary : Color.textTertiary)

                Text(categoryDescription(for: source.name))
                    .font(.outliveCaption)
                    .foregroundStyle(Color.textSecondary)
            }

            Spacer()

            Toggle(isOn: $source.isEnabled) {
                EmptyView()
            }
            .labelsHidden()
            .tint(.domainTraining)
        }
        .padding(.vertical, OutliveSpacing.xxs)
        .contentShape(Rectangle())
    }

    private func categoryDescription(for name: String) -> String {
        switch name {
        case "Longevity":    "Lifespan, healthspan, disease prevention"
        case "Training":     "Strength, hypertrophy, endurance programming"
        case "Neuroscience": "Sleep, focus, dopamine, stress protocols"
        case "Nutrition":    "Micronutrients, gut health, metabolic optimization"
        case "Blueprint":    "Comprehensive age-reversal protocol stack"
        default:             "Evidence-based health protocols"
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ProtocolSelectionView(viewModel: OnboardingViewModel()) { }
            .environment(AppState())
    }
}
