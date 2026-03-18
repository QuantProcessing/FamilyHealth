import Foundation
import SwiftData

@MainActor
final class LocalFamilyService: FamilyService {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func createGroup(name: String, creatorId: UUID) async throws -> FamilyGroup {
        let group = FamilyGroup(name: name, creatorId: creatorId)
        context.insert(group)

        // Creator is automatically admin
        let member = FamilyMember(userId: creatorId, role: .admin)
        member.group = group
        context.insert(member)

        try context.save()
        return group
    }

    func fetchGroups(userId: UUID) async throws -> [FamilyGroup] {
        let descriptor = FetchDescriptor<FamilyMember>()
        let memberships = try context.fetch(descriptor).filter { $0.userId == userId }
        return memberships.compactMap(\.group)
    }

    func fetchGroup(id: UUID) async throws -> FamilyGroup? {
        let descriptor = FetchDescriptor<FamilyGroup>()
        return try context.fetch(descriptor).first { $0.id == id }
    }

    func deleteGroup(id: UUID) async throws {
        let descriptor = FetchDescriptor<FamilyGroup>()
        if let group = try context.fetch(descriptor).first(where: { $0.id == id }) {
            context.delete(group) // cascade deletes members
            try context.save()
        }
    }

    func addMember(groupId: UUID, userId: UUID, role: FamilyMember.Role, invitedBy: UUID) async throws {
        guard let group = try await fetchGroup(id: groupId) else {
            throw FamilyError.groupNotFound
        }

        // Check if already a member
        let existingMembers = try await getMembers(groupId: groupId)
        guard !existingMembers.contains(where: { $0.userId == userId }) else {
            throw FamilyError.alreadyMember
        }

        let member = FamilyMember(userId: userId, role: role, invitedBy: invitedBy)
        member.group = group
        context.insert(member)
        try context.save()
    }

    func removeMember(groupId: UUID, userId: UUID) async throws {
        let descriptor = FetchDescriptor<FamilyMember>()
        let members = try context.fetch(descriptor)
        if let member = members.first(where: { $0.userId == userId && $0.group?.id == groupId }) {
            context.delete(member)
            try context.save()
        }
    }

    func getMembers(groupId: UUID) async throws -> [FamilyMember] {
        let descriptor = FetchDescriptor<FamilyMember>()
        return try context.fetch(descriptor).filter { $0.group?.id == groupId }
    }

    func getUserGroupCount(userId: UUID) async throws -> Int {
        let descriptor = FetchDescriptor<FamilyMember>()
        return try context.fetch(descriptor).filter { $0.userId == userId }.count
    }

    func isAdmin(userId: UUID, groupId: UUID) async throws -> Bool {
        let descriptor = FetchDescriptor<FamilyMember>()
        let members = try context.fetch(descriptor)
        return members.contains { $0.userId == userId && $0.group?.id == groupId && $0.role == .admin }
    }

    func generateInviteCode(groupId: UUID) async throws -> String {
        // Generate a unique code for QR local share
        let code = UUID().uuidString.prefix(8).uppercased()
        // In local mode, we save the code with the group for local transfer
        return "familyhealth://invite?code=\(code)&group=\(groupId.uuidString)"
    }
}

enum FamilyError: LocalizedError {
    case groupNotFound
    case alreadyMember
    case notAdmin

    var errorDescription: String? {
        switch self {
        case .groupNotFound: return String(localized: "家庭组不存在")
        case .alreadyMember: return String(localized: "已经是该家庭组成员")
        case .notAdmin: return String(localized: "权限不足，仅管理员可操作")
        }
    }
}
