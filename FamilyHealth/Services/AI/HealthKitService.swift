import Foundation
import HealthKit
import SwiftData

/// Service for syncing Apple Health data into local SwiftData store
final class HealthKitService {
    private let healthStore = HKHealthStore()
    private var context: ModelContext?

    static let shared = HealthKitService()

    /// Whether HealthKit is available on this device
    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    /// Whether user has enabled health sync
    var isSyncEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "healthkit_sync_enabled") }
        set { UserDefaults.standard.set(newValue, forKey: "healthkit_sync_enabled") }
    }

    /// Last sync timestamp
    var lastSyncDate: Date? {
        get { UserDefaults.standard.object(forKey: "healthkit_last_sync") as? Date }
        set { UserDefaults.standard.set(newValue, forKey: "healthkit_last_sync") }
    }

    func configure(modelContext: ModelContext) {
        self.context = modelContext
    }

    // MARK: - Authorization

    /// HealthKit data types we want to read
    private var readTypes: Set<HKObjectType> {
        var types = Set<HKObjectType>()
        let quantityTypes: [HKQuantityTypeIdentifier] = [
            .stepCount,
            .heartRate,
            .oxygenSaturation,
            .bloodPressureSystolic,
            .bloodPressureDiastolic,
            .bodyMass,
            .activeEnergyBurned,
        ]
        for id in quantityTypes {
            if let t = HKQuantityType.quantityType(forIdentifier: id) {
                types.insert(t)
            }
        }
        if let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleepType)
        }
        return types
    }

    /// Request HealthKit authorization
    func requestAuthorization() async throws {
        guard isAvailable else { return }
        try await healthStore.requestAuthorization(toShare: [], read: readTypes)
    }

    // MARK: - Sync

    /// Sync recent 7 days of health data into SwiftData
    func syncRecentData() async throws {
        guard isAvailable, isSyncEnabled, let context = context else { return }

        try await requestAuthorization()

        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -7, to: endDate)!

        // Clear old records
        let oldRecords = try context.fetch(FetchDescriptor<HealthKitRecord>())
        for record in oldRecords {
            context.delete(record)
        }

        // Fetch each data type
        try await syncQuantity(.stepCount, category: "steps", unit: HKUnit.count(), unitName: "步", start: startDate, end: endDate, context: context)
        try await syncQuantity(.heartRate, category: "heartRate", unit: HKUnit.count().unitDivided(by: .minute()), unitName: "bpm", start: startDate, end: endDate, context: context)
        try await syncQuantity(.oxygenSaturation, category: "bloodOxygen", unit: HKUnit.percent(), unitName: "%", start: startDate, end: endDate, context: context, multiplier: 100)
        try await syncQuantity(.bloodPressureSystolic, category: "bloodPressureSystolic", unit: HKUnit.millimeterOfMercury(), unitName: "mmHg", start: startDate, end: endDate, context: context)
        try await syncQuantity(.bloodPressureDiastolic, category: "bloodPressureDiastolic", unit: HKUnit.millimeterOfMercury(), unitName: "mmHg", start: startDate, end: endDate, context: context)
        try await syncQuantity(.bodyMass, category: "weight", unit: HKUnit.gramUnit(with: .kilo), unitName: "kg", start: startDate, end: endDate, context: context)
        try await syncQuantity(.activeEnergyBurned, category: "activeEnergy", unit: HKUnit.kilocalorie(), unitName: "kcal", start: startDate, end: endDate, context: context)
        try await syncSleep(start: startDate, end: endDate, context: context)

        try context.save()
        lastSyncDate = Date()
    }

    // MARK: - Private Helpers

    private func syncQuantity(
        _ identifier: HKQuantityTypeIdentifier,
        category: String,
        unit: HKUnit,
        unitName: String,
        start: Date,
        end: Date,
        context: ModelContext,
        multiplier: Double = 1.0
    ) async throws {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else { return }

        // Use daily statistics for cumulative types, individual samples for discrete types
        let isCumulative = (identifier == .stepCount || identifier == .activeEnergyBurned)

        if isCumulative {
            let samples = try await fetchDailyStatistics(type: quantityType, unit: unit, start: start, end: end)
            for (date, value) in samples {
                let v = value * multiplier
                let dateStr = date.formatted(date: .abbreviated, time: .omitted)
                let record = HealthKitRecord(
                    date: date,
                    category: category,
                    value: v,
                    unit: unitName,
                    summary: "\(dateStr) \(category == "steps" ? "步数" : "活动能量"): \(formatValue(v))\(unitName)"
                )
                context.insert(record)
            }
        } else {
            let samples = try await fetchSamples(type: quantityType, unit: unit, start: start, end: end)
            // Group by day and take average
            let grouped = Dictionary(grouping: samples) { sample in
                Calendar.current.startOfDay(for: sample.0)
            }
            for (date, daySamples) in grouped {
                let avg = daySamples.map(\.1).reduce(0, +) / Double(daySamples.count) * multiplier
                let dateStr = date.formatted(date: .abbreviated, time: .omitted)
                let displayName = HealthKitRecord(date: date, category: category, value: avg, unit: unitName, summary: "").categoryDisplayName
                let record = HealthKitRecord(
                    date: date,
                    category: category,
                    value: avg,
                    unit: unitName,
                    summary: "\(dateStr) \(displayName): \(formatValue(avg))\(unitName)"
                )
                context.insert(record)
            }
        }
    }

    private func syncSleep(start: Date, end: Date, context: ModelContext) async throws {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return }

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: sleepType, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )

        let samples = try await descriptor.result(for: healthStore)

        // Group by day, sum asleep durations
        let grouped = Dictionary(grouping: samples) { sample in
            Calendar.current.startOfDay(for: sample.startDate)
        }

        for (date, daySamples) in grouped {
            let totalHours = daySamples
                .filter { $0.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue ||
                          $0.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                          $0.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                          $0.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue }
                .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) / 3600.0 }

            guard totalHours > 0 else { continue }

            let dateStr = date.formatted(date: .abbreviated, time: .omitted)
            let record = HealthKitRecord(
                date: date,
                category: "sleep",
                value: totalHours,
                unit: "小时",
                summary: "\(dateStr) 睡眠: \(String(format: "%.1f", totalHours))小时"
            )
            context.insert(record)
        }
    }

    private func fetchSamples(type: HKQuantityType, unit: HKUnit, start: Date, end: Date) async throws -> [(Date, Double)] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: type, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        let samples = try await descriptor.result(for: healthStore)
        return samples.map { ($0.startDate, $0.quantity.doubleValue(for: unit)) }
    }

    private func fetchDailyStatistics(type: HKQuantityType, unit: HKUnit, start: Date, end: Date) async throws -> [(Date, Double)] {
        let interval = DateComponents(day: 1)
        let query = HKStatisticsCollectionQuery(
            quantityType: type,
            quantitySamplePredicate: HKQuery.predicateForSamples(withStart: start, end: end),
            options: .cumulativeSum,
            anchorDate: Calendar.current.startOfDay(for: start),
            intervalComponents: interval
        )

        return try await withCheckedThrowingContinuation { continuation in
            query.initialResultsHandler = { _, results, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                var dailyValues: [(Date, Double)] = []
                results?.enumerateStatistics(from: start, to: end) { stats, _ in
                    if let sum = stats.sumQuantity() {
                        dailyValues.append((stats.startDate, sum.doubleValue(for: unit)))
                    }
                }
                continuation.resume(returning: dailyValues)
            }
            healthStore.execute(query)
        }
    }

    private func formatValue(_ value: Double) -> String {
        if value == value.rounded() {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }
}
