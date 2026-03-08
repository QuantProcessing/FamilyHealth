import Foundation
import SwiftData

@Model
final class FamilyGroup {
    @Attribute(.unique) var id: UUID
    var name: String
    var creatorId: UUID
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \FamilyMember.group)
    var members: [FamilyMember] = []

    init(
        id: UUID = UUID(),
        name: String,
        creatorId: UUID
    ) {
        self.id = id
        self.name = name
        self.creatorId = creatorId
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

@Model
final class FamilyMember {
    @Attribute(.unique) var id: UUID
    var userId: UUID
    var role: Role
    var invitedBy: UUID?
    var joinedAt: Date
    var group: FamilyGroup?

    init(
        id: UUID = UUID(),
        userId: UUID,
        role: Role,
        invitedBy: UUID? = nil
    ) {
        self.id = id
        self.userId = userId
        self.role = role
        self.invitedBy = invitedBy
        self.joinedAt = Date()
    }

    enum Role: String, Codable {
        case admin
        case member

        var displayName: String {
            switch self {
            case .admin: return String(localized: "管理员")
            case .member: return String(localized: "成员")
            }
        }
    }
}
