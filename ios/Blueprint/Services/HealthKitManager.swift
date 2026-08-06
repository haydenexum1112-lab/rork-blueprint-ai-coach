import Foundation
import HealthKit
import SwiftUI

/// Error thrown by HealthKit operations.
nonisolated enum HealthKitError: LocalizedError {
    case unavailable
    case notAuthorized
    case noData
    case queryFailed(String)

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Apple Health isn't available on this device."
        case .notAuthorized:
            return "Blueprint doesn't have permission to read that data from Apple Health."
        case .noData:
            return "No data found in Apple Health for that category."
        case .queryFailed(let message):
            return "Apple Health request failed: \(message)"
        }
    }
}

/// A summary of health data pulled from Apple Health for a given day.
nonisolated struct HealthDaySummary: Hashable {
    let date: Date
    let steps: Int
    let activeCalories: Int
    /// Body mass in kg (most recent sample on or before `date`), if any.
    let bodyMassKg: Double?
}

/// Manages the Apple Health (HealthKit) connection: authorization, reading
/// body weight / workouts / steps / active energy, and writing nutrition data.
@Observable
final class HealthKitManager {
    /// Whether the user has granted HealthKit authorization.
    var isAuthorized: Bool = false
    /// Whether a request is in flight.
    var isRequesting: Bool = false
    /// Last error message shown to the user, if any.
    var lastError: String?

    /// Lazily-created HealthKit store. Only instantiated when HealthKit is
    /// available on this device. Creating HKHealthStore when HealthKit is
    /// unavailable triggers a runtime crash.
    private var _store: HKHealthStore?
    private var store: HKHealthStore {
        if let s = _store { return s }
        let s = HKHealthStore()
        _store = s
        return s
    }

    /// True if HealthKit is available on this device (simulator may return false).
    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    // MARK: - Authorization

    /// The types we want to READ from Apple Health.
    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .bodyMass)!,
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .height)!,
        ]
        types.insert(HKObjectType.workoutType())
        return types
    }

    /// The types we want to WRITE to Apple Health.
    private var shareTypes: Set<HKSampleType> {
        var types: Set<HKSampleType> = [
            HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed)!,
            HKObjectType.quantityType(forIdentifier: .dietaryProtein)!,
            HKObjectType.quantityType(forIdentifier: .dietaryCarbohydrates)!,
            HKObjectType.quantityType(forIdentifier: .dietaryFatTotal)!,
        ]
        if let nutritionType = HKObjectType.correlationType(forIdentifier: .food) {
            types.insert(nutritionType)
        }
        return types
    }

    /// Requests HealthKit authorization from the user. Presents the system
    /// Health permission sheet. Safe to call multiple times.
    func requestAuthorization() async {
        guard isAvailable else {
            lastError = HealthKitError.unavailable.errorDescription
            return
        }
        isRequesting = true
        lastError = nil
        do {
            try await store.requestAuthorization(toShare: shareTypes, read: readTypes)
            isAuthorized = true
            persistConnectionState(true)
        } catch {
            lastError = error.localizedDescription
            isAuthorized = false
        }
        isRequesting = false
    }

    /// Disconnects from HealthKit (revokes our local flag — the system permission
    /// sheet itself can only be toggled in the iOS Health app > Sources).
    func disconnect() {
        isAuthorized = false
        persistConnectionState(false)
    }

    /// Loads the saved connection state at launch so the UI reflects reality.
    func loadConnectionState() {
        isAuthorized = UserDefaults.standard.bool(forKey: healthConnectedKey)
    }

    private let healthConnectedKey = "blueprint.healthkit.connected"

    private func persistConnectionState(_ connected: Bool) {
        UserDefaults.standard.set(connected, forKey: healthConnectedKey)
    }

    // MARK: - Read body weight (most recent sample)

    /// Fetches the most recent body mass sample, optionally as of a given date.
    /// Returns the weight in kilograms, or nil if no data.
    func fetchLatestBodyMass(asOf date: Date = .distantFuture) async throws -> Double? {
        guard isAvailable else { throw HealthKitError.unavailable }
        guard let bodyMassType = HKObjectType.quantityType(forIdentifier: .bodyMass) else {
            throw HealthKitError.queryFailed("body mass type unavailable")
        }

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let predicate = HKQuery.predicateForSamples(withStart: nil, end: date, options: .strictStartDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: bodyMassType,
                predicate: predicate,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, results, error in
                if let error {
                    continuation.resume(throwing: HealthKitError.queryFailed(error.localizedDescription))
                    return
                }
                guard let sample = results?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }
                let kg = sample.quantity.doubleValue(for: .gramUnit(with: .kilo))
                continuation.resume(returning: kg)
            }
            store.execute(query)
        }
    }

    // MARK: - Read steps for a day

    /// Fetches total step count for a given calendar day.
    func fetchSteps(on date: Date) async throws -> Int {
        guard isAvailable else { throw HealthKitError.unavailable }
        guard let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) else {
            throw HealthKitError.queryFailed("step type unavailable")
        }

        let dayInterval = Calendar.current.dateInterval(of: .day, for: date) ?? DateInterval(start: date, duration: 86400)
        let predicate = HKQuery.predicateForSamples(withStart: dayInterval.start, end: dayInterval.end, options: .strictStartDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                if let error {
                    continuation.resume(throwing: HealthKitError.queryFailed(error.localizedDescription))
                    return
                }
                let steps = Int(statistics?.sumQuantity()?.doubleValue(for: .count()) ?? 0)
                continuation.resume(returning: steps)
            }
            store.execute(query)
        }
    }

    // MARK: - Read active energy for a day

    /// Fetches total active energy burned (kcal) for a given calendar day.
    func fetchActiveEnergy(on date: Date) async throws -> Int {
        guard isAvailable else { throw HealthKitError.unavailable }
        guard let energyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) else {
            throw HealthKitError.queryFailed("energy type unavailable")
        }

        let dayInterval = Calendar.current.dateInterval(of: .day, for: date) ?? DateInterval(start: date, duration: 86400)
        let predicate = HKQuery.predicateForSamples(withStart: dayInterval.start, end: dayInterval.end, options: .strictStartDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: energyType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                if let error {
                    continuation.resume(throwing: HealthKitError.queryFailed(error.localizedDescription))
                    return
                }
                let kcal = Int(statistics?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0)
                continuation.resume(returning: kcal)
            }
            store.execute(query)
        }
    }

    // MARK: - Read workouts in a date range

    /// Fetches workout samples in the given date range.
    func fetchWorkouts(from start: Date, to end: Date) async throws -> [HKWorkout] {
        guard isAvailable else { throw HealthKitError.unavailable }
        let workoutType = HKObjectType.workoutType()

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: workoutType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, results, error in
                if let error {
                    continuation.resume(throwing: HealthKitError.queryFailed(error.localizedDescription))
                    return
                }
                let workouts = (results as? [HKWorkout]) ?? []
                continuation.resume(returning: workouts)
            }
            store.execute(query)
        }
    }

    // MARK: - Combined day summary

    /// Convenience: fetch a combined summary for a given day.
    func fetchDaySummary(on date: Date) async throws -> HealthDaySummary {
        async let stepsTask = fetchSteps(on: date)
        async let energyTask = fetchActiveEnergy(on: date)
        async let weightTask = fetchLatestBodyMass(asOf: Calendar.current.dateInterval(of: .day, for: date)?.end ?? date)

        let steps = (try? await stepsTask) ?? 0
        let energy = (try? await energyTask) ?? 0
        let weight = try? await weightTask

        return HealthDaySummary(date: date, steps: steps, activeCalories: energy, bodyMassKg: weight)
    }

    // MARK: - Write nutrition data

    /// Writes a single food entry's macros to Apple Health as a nutrition correlation.
    /// Silent no-op if HealthKit isn't authorized or available.
    func writeNutritionEntry(
        name: String,
        calories: Int,
        proteinGrams: Int,
        carbsGrams: Int,
        fatGrams: Int,
        date: Date
    ) async {
        guard isAvailable, isAuthorized else { return }
        guard let nutritionType = HKObjectType.correlationType(forIdentifier: .food) else { return }

        var samples: [HKQuantitySample] = []

        if let energyType = HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed),
           calories > 0 {
            samples.append(HKQuantitySample(
                type: energyType,
                quantity: HKQuantity(unit: .kilocalorie(), doubleValue: Double(calories)),
                start: date,
                end: date,
                metadata: [HKMetadataKeyFoodType: name]
            ))
        }

        if let proteinType = HKObjectType.quantityType(forIdentifier: .dietaryProtein),
           proteinGrams > 0 {
            samples.append(HKQuantitySample(
                type: proteinType,
                quantity: HKQuantity(unit: .gram(), doubleValue: Double(proteinGrams)),
                start: date,
                end: date
            ))
        }

        if let carbsType = HKObjectType.quantityType(forIdentifier: .dietaryCarbohydrates),
           carbsGrams > 0 {
            samples.append(HKQuantitySample(
                type: carbsType,
                quantity: HKQuantity(unit: .gram(), doubleValue: Double(carbsGrams)),
                start: date,
                end: date
            ))
        }

        if let fatType = HKObjectType.quantityType(forIdentifier: .dietaryFatTotal),
           fatGrams > 0 {
            samples.append(HKQuantitySample(
                type: fatType,
                quantity: HKQuantity(unit: .gram(), doubleValue: Double(fatGrams)),
                start: date,
                end: date
            ))
        }

        guard !samples.isEmpty else { return }

        let correlation = HKCorrelation(
            type: nutritionType,
            start: date,
            end: date,
            objects: Set(samples),
            metadata: [HKMetadataKeyFoodType: name]
        )

        do {
            try await store.save(correlation)
        } catch {
            // Non-fatal — we don't want logging to fail if HealthKit write fails.
            print("[HealthKitManager] Nutrition write failed: \(error.localizedDescription)")
        }
    }
}
