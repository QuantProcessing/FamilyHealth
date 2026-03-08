import Foundation
import SwiftData

@MainActor
final class LocalReportService: ReportService {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func createReport(_ report: HealthReport) async throws {
        context.insert(report)
        try context.save()
    }

    func fetchReports(userId: UUID) async throws -> [HealthReport] {
        let predicate = #Predicate<HealthReport> { $0.userId == userId }
        let descriptor = FetchDescriptor(
            predicate: predicate,
            sortBy: [SortDescriptor(\.reportDate, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    func fetchReport(id: UUID) async throws -> HealthReport? {
        let predicate = #Predicate<HealthReport> { $0.id == id }
        let descriptor = FetchDescriptor(predicate: predicate)
        return try context.fetch(descriptor).first
    }

    func updateReport(_ report: HealthReport) async throws {
        report.updatedAt = Date()
        try context.save()
    }

    func deleteReport(id: UUID) async throws {
        let predicate = #Predicate<HealthReport> { $0.id == id }
        let descriptor = FetchDescriptor(predicate: predicate)
        if let report = try context.fetch(descriptor).first {
            context.delete(report)
            try context.save()
        }
    }

    func searchReports(query: String, userId: UUID?) async throws -> [HealthReport] {
        let predicate: Predicate<HealthReport>
        if let userId {
            predicate = #Predicate<HealthReport> {
                $0.userId == userId && (
                    $0.title.localizedStandardContains(query) ||
                    ($0.hospitalName?.localizedStandardContains(query) ?? false)
                )
            }
        } else {
            predicate = #Predicate<HealthReport> {
                $0.title.localizedStandardContains(query) ||
                ($0.hospitalName?.localizedStandardContains(query) ?? false)
            }
        }
        let descriptor = FetchDescriptor(
            predicate: predicate,
            sortBy: [SortDescriptor(\.reportDate, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }
}
