import Foundation
import SwiftData

@MainActor
final class LocalCaseService: CaseService {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func createCase(_ medicalCase: MedicalCase) async throws {
        context.insert(medicalCase)
        try context.save()
    }

    func fetchCases(userId: UUID) async throws -> [MedicalCase] {
        let predicate = #Predicate<MedicalCase> { $0.userId == userId }
        let descriptor = FetchDescriptor(
            predicate: predicate,
            sortBy: [SortDescriptor(\.visitDate, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    func fetchCase(id: UUID) async throws -> MedicalCase? {
        let predicate = #Predicate<MedicalCase> { $0.id == id }
        let descriptor = FetchDescriptor(predicate: predicate)
        return try context.fetch(descriptor).first
    }

    func updateCase(_ medicalCase: MedicalCase) async throws {
        medicalCase.updatedAt = Date()
        try context.save()
    }

    func deleteCase(id: UUID) async throws {
        let predicate = #Predicate<MedicalCase> { $0.id == id }
        let descriptor = FetchDescriptor(predicate: predicate)
        if let medicalCase = try context.fetch(descriptor).first {
            context.delete(medicalCase)
            try context.save()
        }
    }

    func searchCases(query: String, userId: UUID?) async throws -> [MedicalCase] {
        let predicate: Predicate<MedicalCase>
        if let userId {
            predicate = #Predicate<MedicalCase> {
                $0.userId == userId && (
                    $0.title.localizedStandardContains(query) ||
                    ($0.diagnosis?.localizedStandardContains(query) ?? false)
                )
            }
        } else {
            predicate = #Predicate<MedicalCase> {
                $0.title.localizedStandardContains(query) ||
                ($0.diagnosis?.localizedStandardContains(query) ?? false)
            }
        }
        let descriptor = FetchDescriptor(
            predicate: predicate,
            sortBy: [SortDescriptor(\.visitDate, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }
}
