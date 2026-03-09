import SwiftUI
import SwiftData

/// Dependency injection container — always uses local (SwiftData) service implementations.
@MainActor @Observable
class ServiceContainer {
    let appState: AppState
    private var _modelContext: ModelContext?

    // Service instances — initially stubs, replaced when configure() is called
    private(set) var authService: any AuthService = StubAuthService()
    private(set) var reportService: any ReportService = StubReportService()
    private(set) var caseService: any CaseService = StubCaseService()
    private(set) var familyService: any FamilyService = StubFamilyService()

    init(appState: AppState) {
        self.appState = appState
    }

    func configure(modelContext: ModelContext) {
        self._modelContext = modelContext
        guard let ctx = _modelContext else { return }
        authService = LocalAuthService(context: ctx)
        reportService = LocalReportService(context: ctx)
        caseService = LocalCaseService(context: ctx)
        familyService = LocalFamilyService(context: ctx)
    }
}

// MARK: - Stub implementations (no-op defaults before configure() is called)

private struct StubAuthService: AuthService {
    func createLocalUser(phone: String, name: String, gender: User.Gender) async throws -> User { fatalError("ServiceContainer not configured") }
    func getCurrentUser() async throws -> User? { nil }
    func updateUser(_ user: User) async throws {}
    func deleteUser(id: UUID) async throws {}
    func findUser(byPhone phone: String) async throws -> User? { nil }
}

private struct StubReportService: ReportService {
    func createReport(_ report: HealthReport) async throws {}
    func fetchReports(userId: UUID) async throws -> [HealthReport] { [] }
    func fetchReport(id: UUID) async throws -> HealthReport? { nil }
    func updateReport(_ report: HealthReport) async throws {}
    func deleteReport(id: UUID) async throws {}
    func searchReports(query: String, userId: UUID?) async throws -> [HealthReport] { [] }
}

private struct StubCaseService: CaseService {
    func createCase(_ medicalCase: MedicalCase) async throws {}
    func fetchCases(userId: UUID) async throws -> [MedicalCase] { [] }
    func fetchCase(id: UUID) async throws -> MedicalCase? { nil }
    func updateCase(_ medicalCase: MedicalCase) async throws {}
    func deleteCase(id: UUID) async throws {}
    func searchCases(query: String, userId: UUID?) async throws -> [MedicalCase] { [] }
}

private struct StubFamilyService: FamilyService {
    func createGroup(name: String, creatorId: UUID) async throws -> FamilyGroup { fatalError("ServiceContainer not configured") }
    func fetchGroups(userId: UUID) async throws -> [FamilyGroup] { [] }
    func fetchGroup(id: UUID) async throws -> FamilyGroup? { nil }
    func deleteGroup(id: UUID) async throws {}
    func addMember(groupId: UUID, userId: UUID, role: FamilyMember.Role, invitedBy: UUID) async throws {}
    func removeMember(groupId: UUID, userId: UUID) async throws {}
    func getMembers(groupId: UUID) async throws -> [FamilyMember] { [] }
    func getUserGroupCount(userId: UUID) async throws -> Int { 0 }
    func isAdmin(userId: UUID, groupId: UUID) async throws -> Bool { false }
    func generateInviteCode(groupId: UUID) async throws -> String { "" }
}
