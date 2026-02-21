// WearableConnectionView.swift
// OutliveEngine
//
// Presents available wearable data sources (Apple Watch, Whoop, Oura) and
// lets the user connect each one. Skippable — wearables can be added later.

import SwiftUI
import HealthKit

struct WearableConnectionView: View {
    @Bindable var viewModel: OnboardingViewModel
    @State private var healthKitAuthorized = false
    @State private var isRequestingHealthKit = false

    var body: some View {
        VStack(spacing: 0) {
            OnboardingStepHeader(step: .wearables, progress: viewModel.progress)

            Text("Connect your devices for real-time data integration.")
                .font(.outliveCallout)
                .foregroundStyle(Color.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, OutliveSpacing.md)
                .padding(.top, OutliveSpacing.xs)

            ScrollView {
                VStack(spacing: OutliveSpacing.sm) {
                    WearableRow(
                        icon: "applewatch",
                        name: "Apple Watch",
                        subtitle: "HealthKit integration",
                        isConnected: viewModel.connectedWearables.contains(.appleWatch),
                        isLoading: isRequestingHealthKit
                    ) {
                        requestHealthKitAccess()
                    }

                    WearableRow(
                        icon: "link.circle.fill",
                        name: "Whoop",
                        subtitle: "OAuth connection",
                        isConnected: viewModel.connectedWearables.contains(.whoop)
                    ) {
                        connectWhoop()
                    }

                    WearableRow(
                        icon: "circle.dotted.circle",
                        name: "Oura Ring",
                        subtitle: "OAuth connection",
                        isConnected: viewModel.connectedWearables.contains(.oura)
                    ) {
                        connectOura()
                    }
                }
                .padding(.horizontal, OutliveSpacing.md)
                .padding(.top, OutliveSpacing.lg)
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
        .onAppear { viewModel.currentStep = .wearables }
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

    // MARK: - Wearable Actions

    private func requestHealthKitAccess() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        isRequestingHealthKit = true

        let store = HKHealthStore()
        let readTypes: Set<HKSampleType> = [
            HKQuantityType(.heartRate),
            HKQuantityType(.restingHeartRate),
            HKQuantityType(.heartRateVariabilitySDNN),
            HKQuantityType(.stepCount),
            HKQuantityType(.activeEnergyBurned),
            HKCategoryType(.sleepAnalysis),
        ]

        store.requestAuthorization(toShare: [], read: readTypes) { success, _ in
            DispatchQueue.main.async {
                isRequestingHealthKit = false
                if success {
                    viewModel.connectedWearables.insert(.appleWatch)
                }
            }
        }
    }

    private func connectWhoop() {
        // Placeholder: would launch Whoop OAuth flow
        viewModel.connectedWearables.insert(.whoop)
    }

    private func connectOura() {
        // Placeholder: would launch Oura OAuth flow
        viewModel.connectedWearables.insert(.oura)
    }
}

// MARK: - Wearable Row

private struct WearableRow: View {
    let icon: String
    let name: String
    let subtitle: String
    let isConnected: Bool
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        HStack(spacing: OutliveSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(isConnected ? Color.recoveryGreen : Color.textSecondary)
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: OutliveSpacing.xxs) {
                Text(name)
                    .font(.outliveHeadline)
                    .foregroundStyle(Color.textPrimary)

                Text(subtitle)
                    .font(.outliveCaption)
                    .foregroundStyle(Color.textSecondary)
            }

            Spacer()

            if isLoading {
                ProgressView()
            } else if isConnected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Color.recoveryGreen)
            } else {
                Button("Connect", action: action)
                    .font(.outliveSubheadline)
                    .foregroundStyle(Color.domainTraining)
                    .padding(.horizontal, OutliveSpacing.sm)
                    .padding(.vertical, OutliveSpacing.xxs)
                    .background(
                        RoundedRectangle(cornerRadius: OutliveSpacing.CornerRadius.small, style: .continuous)
                            .strokeBorder(Color.domainTraining, lineWidth: 1)
                    )
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
        WearableConnectionView(viewModel: OnboardingViewModel())
            .environment(AppState())
    }
}
