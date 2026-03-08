import Foundation

// MARK: - Auth Service
protocol AuthService {
    func createLocalUser(phone: String, name: String, gender: User.Gender) async throws -> User
    func getCurrentUser() async throws -> User?
    func updateUser(_ user: User) async throws
    func deleteUser(id: UUID) async throws
    func findUser(byPhone phone: String) async throws -> User?
}

// MARK: - Report Service
protocol ReportService {
    func createReport(_ report: HealthReport) async throws
    func fetchReports(userId: UUID) async throws -> [HealthReport]
    func fetchReport(id: UUID) async throws -> HealthReport?
    func updateReport(_ report: HealthReport) async throws
    func deleteReport(id: UUID) async throws
    func searchReports(query: String, userId: UUID?) async throws -> [HealthReport]
}

// MARK: - Case Service
protocol CaseService {
    func createCase(_ medicalCase: MedicalCase) async throws
    func fetchCases(userId: UUID) async throws -> [MedicalCase]
    func fetchCase(id: UUID) async throws -> MedicalCase?
    func updateCase(_ medicalCase: MedicalCase) async throws
    func deleteCase(id: UUID) async throws
    func searchCases(query: String, userId: UUID?) async throws -> [MedicalCase]
}

// MARK: - Family Service
protocol FamilyService {
    func createGroup(name: String, creatorId: UUID) async throws -> FamilyGroup
    func fetchGroups(userId: UUID) async throws -> [FamilyGroup]
    func fetchGroup(id: UUID) async throws -> FamilyGroup?
    func deleteGroup(id: UUID) async throws
    func addMember(groupId: UUID, userId: UUID, role: FamilyMember.Role, invitedBy: UUID) async throws
    func removeMember(groupId: UUID, userId: UUID) async throws
    func getMembers(groupId: UUID) async throws -> [FamilyMember]
    func getUserGroupCount(userId: UUID) async throws -> Int
    func isAdmin(userId: UUID, groupId: UUID) async throws -> Bool
    func generateInviteCode(groupId: UUID) async throws -> String
}

// MARK: - AI Service
protocol AIServiceProtocol {
    func chat(
        messages: [ChatMessage],
        config: AIModelConfig,
        apiKey: String
    ) -> AsyncThrowingStream<String, Error>

    func analyze(
        content: String,
        config: AIModelConfig,
        apiKey: String
    ) async throws -> String

    func testConnection(
        endpoint: String,
        apiKey: String,
        model: String
    ) async throws -> Bool
}
