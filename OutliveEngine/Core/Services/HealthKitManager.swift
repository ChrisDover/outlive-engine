// HealthKitManager.swift
// OutliveEngine
//
// Reads heart rate, HRV, sleep, steps, body composition, and other key metrics
// from HealthKit and converts them to Outlive Engine model types.

import Foundation
import HealthKit
import Observation

// MARK: - HealthKit Errors

enum HealthKitManagerError: Error, Sendable, LocalizedError {
    case notAvailable
    case authorizationDenied
    case queryFailed(underlying: String)
    case noData

    var errorDescription: String? {
        switch self {
        case .notAvailable:         "HealthKit is not available on this device."
        case .authorizationDenied:  "HealthKit authorization was denied."
        case .queryFailed(let msg): "HealthKit query failed: \(msg)"
        case .noData:               "No HealthKit data found for the requested period."
        }
    }
}

// MARK: - HealthKit Manager

@Observable
final class HealthKitManager: @unchecked Sendable {

    // MARK: - State

    private(set) var isAuthorized: Bool = false

    // MARK: - HealthKit Store

    private let healthStore: HKHealthStore?

    // MARK: - Requested Types

    /// Quantity types the app reads from HealthKit.
    private static let readQuantityTypes: Set<HKQuantityType> = [
        HKQuantityType(.heartRate),
        HKQuantityType(.restingHeartRate),
        HKQuantityType(.heartRateVariabilitySDNN),
        HKQuantityType(.stepCount),
        HKQuantityType(.activeEnergyBurned),
        HKQuantityType(.bodyMass),
        HKQuantityType(.bodyFatPercentage),
        HKQuantityType(.leanBodyMass),
    ]

    /// Category types the app reads from HealthKit.
    private static let readCategoryTypes: Set<HKCategoryType> = [
        HKCategoryType(.sleepAnalysis),
    ]

    /// Combined set of all types to request read access for.
    private static var allReadTypes: Set<HKSampleType> {
        var types = Set<HKSampleType>()
        for qt in readQuantityTypes { types.insert(qt) }
        for ct in readCategoryTypes { types.insert(ct) }
        return types
    }

    // MARK: - Initialization

    init() {
        self.healthStore = HKHealthStore.isHealthDataAvailable() ? HKHealthStore() : nil
    }

    // MARK: - Authorization

    /// Requests read-only authorization for all configured HealthKit data types.
    func requestAuthorization() async throws {
        guard let store = healthStore else {
            throw HealthKitManagerError.notAvailable
        }

        try await store.requestAuthorization(toShare: [], read: Self.allReadTypes)
        isAuthorized = true
    }

    // MARK: - Daily Wearable Data

    /// Fetches aggregated daily metrics from HealthKit for a specific date and
    /// converts them into a `DailyWearableData` model instance.
    ///
    /// - Parameters:
    ///   - date: The calendar date to query.
    ///   - userId: The user ID to stamp on the record.
    /// - Returns: A populated `DailyWearableData` for the given date.
    func fetchDailyData(for date: Date, userId: String) async throws -> DailyWearableData {
        guard let store = healthStore else {
            throw HealthKitManagerError.notAvailable
        }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            throw HealthKitManagerError.queryFailed(underlying: "Could not compute end of day.")
        }

        nonisolated(unsafe) let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: endOfDay,
            options: .strictStartDate
        )

        // Fetch all metrics concurrently.
        async let hrvMs = queryAverage(
            store: store,
            type: HKQuantityType(.heartRateVariabilitySDNN),
            unit: HKUnit.secondUnit(with: .milli),
            predicate: predicate
        )
        async let restingHR = queryAverage(
            store: store,
            type: HKQuantityType(.restingHeartRate),
            unit: HKUnit.count().unitDivided(by: .minute()),
            predicate: predicate
        )
        async let steps = queryCumulativeSum(
            store: store,
            type: HKQuantityType(.stepCount),
            unit: .count(),
            predicate: predicate
        )
        async let activeCalories = queryCumulativeSum(
            store: store,
            type: HKQuantityType(.activeEnergyBurned),
            unit: .kilocalorie(),
            predicate: predicate
        )
        async let sleepHours = querySleepDuration(store: store, predicate: predicate)

        let hrvResult = try? await hrvMs
        let restingHRResult = try? await restingHR
        let stepsResult = try? await steps
        let caloriesResult = try? await activeCalories
        let sleepResult = try? await sleepHours

        return DailyWearableData(
            userId: userId,
            date: startOfDay,
            source: .appleWatch,
            hrvMs: hrvResult,
            restingHR: restingHRResult.map { Int($0) },
            sleepHours: sleepResult,
            recoveryScore: nil, // Computed by the engine, not sourced from HealthKit.
            steps: stepsResult.map { Int($0) },
            activeCalories: caloriesResult.map { Int($0) }
        )
    }

    // MARK: - Body Composition

    /// Fetches the most recent body composition measurements from HealthKit.
    ///
    /// - Parameter userId: The user ID to stamp on the record.
    /// - Returns: A `BodyComposition` model if weight data exists, or `nil`.
    func fetchBodyComposition(userId: String) async throws -> BodyComposition? {
        guard let store = healthStore else {
            throw HealthKitManagerError.notAvailable
        }

        let weight = try? await queryMostRecent(
            store: store,
            type: HKQuantityType(.bodyMass),
            unit: .gramUnit(with: .kilo)
        )

        guard let weightKg = weight else { return nil }

        let bodyFat = try? await queryMostRecent(
            store: store,
            type: HKQuantityType(.bodyFatPercentage),
            unit: .percent()
        )

        let leanMass = try? await queryMostRecent(
            store: store,
            type: HKQuantityType(.leanBodyMass),
            unit: .gramUnit(with: .kilo)
        )

        return BodyComposition(
            userId: userId,
            date: .now,
            weightKg: weightKg,
            bodyFatPercent: bodyFat.map { $0 * 100 }, // Convert from 0.xx to percentage.
            muscleMassKg: leanMass,
            source: .appleWatch
        )
    }

    // MARK: - Background Delivery

    /// Registers background delivery for key metrics so the app receives updates
    /// even when not in the foreground.
    func enableBackgroundDelivery() {
        guard let store = healthStore else { return }

        let criticalTypes: [HKQuantityType] = [
            HKQuantityType(.heartRateVariabilitySDNN),
            HKQuantityType(.restingHeartRate),
            HKQuantityType(.stepCount),
        ]

        for type in criticalTypes {
            store.enableBackgroundDelivery(for: type, frequency: .hourly) { success, error in
                if let error {
                    print("[HealthKitManager] Background delivery registration failed for \(type.identifier): \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Query Helpers

    /// Queries the average value of a quantity type for a given predicate.
    private func queryAverage(
        store: HKHealthStore,
        type: HKQuantityType,
        unit: HKUnit,
        predicate: NSPredicate
    ) async throws -> Double {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .discreteAverage
            ) { _, result, error in
                if let error {
                    continuation.resume(throwing: HealthKitManagerError.queryFailed(underlying: error.localizedDescription))
                    return
                }
                guard let average = result?.averageQuantity() else {
                    continuation.resume(throwing: HealthKitManagerError.noData)
                    return
                }
                continuation.resume(returning: average.doubleValue(for: unit))
            }
            store.execute(query)
        }
    }

    /// Queries the cumulative sum of a quantity type for a given predicate.
    private func queryCumulativeSum(
        store: HKHealthStore,
        type: HKQuantityType,
        unit: HKUnit,
        predicate: NSPredicate
    ) async throws -> Double {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                if let error {
                    continuation.resume(throwing: HealthKitManagerError.queryFailed(underlying: error.localizedDescription))
                    return
                }
                guard let sum = result?.sumQuantity() else {
                    continuation.resume(throwing: HealthKitManagerError.noData)
                    return
                }
                continuation.resume(returning: sum.doubleValue(for: unit))
            }
            store.execute(query)
        }
    }

    /// Queries total sleep duration (in-bed or asleep) for a given predicate.
    private func querySleepDuration(
        store: HKHealthStore,
        predicate: NSPredicate
    ) async throws -> Double {
        try await withCheckedThrowingContinuation { continuation in
            let sleepType = HKCategoryType(.sleepAnalysis)

            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: HealthKitManagerError.queryFailed(underlying: error.localizedDescription))
                    return
                }

                guard let categorySamples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: 0)
                    return
                }

                // Sum all asleep and in-bed intervals.
                let totalSeconds = categorySamples.reduce(0.0) { total, sample in
                    let value = HKCategoryValueSleepAnalysis(rawValue: sample.value)
                    switch value {
                    case .asleepCore, .asleepDeep, .asleepREM, .asleepUnspecified:
                        return total + sample.endDate.timeIntervalSince(sample.startDate)
                    default:
                        return total
                    }
                }

                continuation.resume(returning: totalSeconds / 3600.0)
            }
            store.execute(query)
        }
    }

    /// Queries the most recent sample value for a quantity type.
    private func queryMostRecent(
        store: HKHealthStore,
        type: HKQuantityType,
        unit: HKUnit
    ) async throws -> Double {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: nil,
                limit: 1,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: HealthKitManagerError.queryFailed(underlying: error.localizedDescription))
                    return
                }

                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(throwing: HealthKitManagerError.noData)
                    return
                }

                continuation.resume(returning: sample.quantity.doubleValue(for: unit))
            }
            store.execute(query)
        }
    }
}
