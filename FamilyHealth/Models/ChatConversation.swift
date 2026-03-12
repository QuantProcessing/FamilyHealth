import Foundation
import SwiftData

@Model
final class ChatConversation: @unchecked Sendable {
    @Attribute(.unique) var id: UUID
    var userId: UUID
    var title: String?
    var modelName: String?
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \ChatMessage.conversation)
    var messages: [ChatMessage] = []

    init(
        id: UUID = UUID(),
        userId: UUID,
        title: String? = nil,
        modelName: String? = nil
    ) {
        self.id = id
        self.userId = userId
        self.title = title
        self.modelName = modelName
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

@Model
final class ChatMessage: @unchecked Sendable {
    @Attribute(.unique) var id: UUID
    var role: MessageRole
    var content: String
    var referenceIds: [UUID]
    var createdAt: Date
    var conversation: ChatConversation?

    init(
        id: UUID = UUID(),
        role: MessageRole,
        content: String,
        referenceIds: [UUID] = []
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.referenceIds = referenceIds
        self.createdAt = Date()
    }

    enum MessageRole: String, Codable {
        case system
        case user
        case assistant
    }
}
