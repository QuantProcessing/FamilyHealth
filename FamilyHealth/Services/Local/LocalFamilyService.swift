import Foundation
import SwiftData

@MainActor
final class LocalFamilyService: FamilyService {
    private let context: ModelContext
    static let maxGroupsPerUser = 2

    init(context: ModelContext) {
        self.context = context
    }

    func createGroup(name: String, creatorId: UUID) async throws -> FamilyGroup {
        // Check the 2-group limit
        let count = try await getUserGroupCount(userId: creatorId)
        guard count < Self.maxGroupsPerUser else {
            throw FamilyError.groupLimitReached
        }

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
        let predicate = #Predicate<FamilyMember> { $0.userId == userId }
        let descriptor = FetchDescriptor(predicate: predicate)
        let memberships = try context.fetch(descriptor)
        return memberships.compactMap(\.group)
    }

    func fetchGroup(id: UUID) async throws -> FamilyGroup? {
        let predicate = #Predicate<FamilyGroup> { $0.id == id }
        let descriptor = FetchDescriptor(predicate: predicate)
        return try context.fetch(descriptor).first
    }

    func deleteGroup(id: UUID) async throws {
        let predicate = #Predicate<FamilyGroup> { $0.id == id }
        let descriptor = FetchDescriptor(predicate: predicate)
        if let group = try context.fetch(descriptor).first {
            context.delete(group) // cascade deletes members
            try context.save()
        }
    }

    func addMember(groupId: UUID, userId: UUID, role: FamilyMember.Role, invitedBy: UUID) async throws {
        // Check the 2-group limit for the joining user
        let count = try await getUserGroupCount(userId: userId)
        guard count < Self.maxGroupsPerUser else {
            throw FamilyError.groupLimitReached
        }

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
        let predicate = #Predicate<FamilyMember> {
            $0.userId == userId && $0.group?.id == groupId
        }
        let descriptor = FetchDescriptor(predicate: predicate)
        if let member = try context.fetch(descriptor).first {
            context.delete(member)
            try context.save()
        }
    }

    func getMembers(groupId: UUID) async throws -> [FamilyMember] {
        let predicate = #Predicate<FamilyMember> { $0.group?.id == groupId }
        let descriptor = FetchDescriptor(predicate: predicate)
        return try context.fetch(descriptor)
    }

    func getUserGroupCount(userId: UUID) async throws -> Int {
        let predicate = #Predicate<FamilyMember> { $0.userId == userId }
        let descriptor = FetchDescriptor(predicate: predicate)
        return try context.fetchCount(descriptor)
    }

    func isAdmin(userId: UUID, groupId: UUID) async throws -> Bool {
        let predicate = #Predicate<FamilyMember> {
            $0.userId == userId && $0.group?.id == groupId && $0.role == .admin
        }
        let descriptor = FetchDescriptor(predicate: predicate)
        return try context.fetchCount(descriptor) > 0
    }

    func generateInviteCode(groupId: UUID) async throws -> String {
        // Generate a unique code for QR local share
        let code = UUID().uuidString.prefix(8).uppercased()
        // In local mode, we save the code with the group for local transfer
        return "familyhealth://invite?code=\(code)&group=\(groupId.uuidString)"
    }
}

enum FamilyError: LocalizedError {
    case groupLimitReached
    case groupNotFound
    case alreadyMember
    case notAdmin

    var errorDescription: String? {
        switch self {
        case .groupLimitReached: return String(localized: "最多只能加入 2 个家庭组")
        case .groupNotFound: return String(localized: "家庭组不存在")
        case .alreadyMember: return String(localized: "已经是该家庭组成员")
        case .notAdmin: return String(localized: "权限不足，仅管理员可操作")
        }
    }
}
