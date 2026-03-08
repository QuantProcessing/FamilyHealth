import Foundation

/// Remote mode implementations that forward operations to the Go server via REST API.

// MARK: - Remote Auth Service

final class RemoteAuthService: AuthService {
    private let api: APIClient

    init(api: APIClient) { self.api = api }

    func login(phone: String, name: String) async throws -> User {
        struct LoginReq: Encodable { let phone: String; let name: String }
        struct LoginRes: Decodable { let token: String; let user: RemoteUser; let is_new: Bool }
        struct RemoteUser: Decodable {
            let id: UUID; let phone: String; let name: String
            let gender: String?; let avatar_url: String?
        }

        let res: LoginRes = try await api.post("/api/v1/auth/login", body: LoginReq(phone: phone, name: name))
        await api.setToken(res.token)

        // Create local User object from response
        let user = User(phone: res.user.phone, name: res.user.name)
        user.id = res.user.id
        user.gender = res.user.gender
        return user
    }

    func getUser(id: UUID) async throws -> User? {
        return nil // Fetched from server as needed
    }

    func updateUser(_ user: User) async throws {
        let _: EmptyResponse = try await api.put("/api/v1/users/me", body: user)
    }
}

// MARK: - Remote Report Service

final class RemoteReportService: ReportService {
    private let api: APIClient

    init(api: APIClient) { self.api = api }

    func createReport(_ report: HealthReport) async throws {
        let _: HealthReport = try await api.post("/api/v1/reports", body: report)
    }

    func getReports(for userId: UUID, page: Int, pageSize: Int) async throws -> [HealthReport] {
        struct ListRes: Decodable { let items: [HealthReport]; let total: Int }
        let res: ListRes = try await api.get("/api/v1/reports", query: [
            "user_id": userId.uuidString,
            "page": "\(page)",
            "size": "\(pageSize)"
        ])
        return res.items
    }

    func deleteReport(_ id: UUID) async throws {
        try await api.delete("/api/v1/reports/\(id)")
    }

    func searchReports(query: String) async throws -> [HealthReport] {
        return [] // TODO: add search endpoint
    }
}

// MARK: - Remote Case Service

final class RemoteCaseService: CaseService {
    private let api: APIClient

    init(api: APIClient) { self.api = api }

    func createCase(_ medicalCase: MedicalCase) async throws {
        let _: MedicalCase = try await api.post("/api/v1/cases", body: medicalCase)
    }

    func getCases(for userId: UUID, page: Int, pageSize: Int) async throws -> [MedicalCase] {
        struct ListRes: Decodable { let items: [MedicalCase]; let total: Int }
        let res: ListRes = try await api.get("/api/v1/cases", query: [
            "page": "\(page)",
            "size": "\(pageSize)"
        ])
        return res.items
    }

    func deleteCase(_ id: UUID) async throws {
        try await api.delete("/api/v1/cases/\(id)")
    }

    func searchCases(query: String) async throws -> [MedicalCase] {
        return [] // TODO: add search endpoint
    }
}

// MARK: - Remote Family Service

final class RemoteFamilyService: FamilyService {
    private let api: APIClient

    init(api: APIClient) { self.api = api }

    func createGroup(name: String, creatorId: UUID) async throws -> FamilyGroup {
        struct CreateReq: Encodable { let name: String }
        let group: FamilyGroup = try await api.post("/api/v1/families", body: CreateReq(name: name))
        return group
    }

    func getGroups(for userId: UUID) async throws -> [FamilyGroup] {
        return try await api.get("/api/v1/families")
    }

    func deleteGroup(id: UUID) async throws {
        try await api.delete("/api/v1/families/\(id)")
    }

    func addMember(groupId: UUID, userId: UUID, role: FamilyMember.Role, invitedBy: UUID) async throws {
        struct JoinReq: Encodable { let invite_code: String }
        // Via invite code flow on server
    }

    func removeMember(groupId: UUID, userId: UUID) async throws {
        // TODO: add endpoint
    }

    func generateInviteCode(groupId: UUID) async throws -> String {
        struct InvRes: Decodable { let invite_code: String; let qr_data: String }
        let res: InvRes = try await api.post("/api/v1/families/\(groupId)/qrcode")
        return res.qr_data
    }
}
