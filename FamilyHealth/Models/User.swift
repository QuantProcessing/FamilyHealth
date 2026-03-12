import Foundation
import SwiftData

@Model
final class User {
    @Attribute(.unique) var id: UUID
    var phone: String
    var name: String
    var gender: Gender
    var birthDate: Date?
    var height: Double?
    var weight: Double?
    @Attribute(.externalStorage) var avatarData: Data?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        phone: String,
        name: String,
        gender: Gender = .male,
        birthDate: Date? = nil,
        height: Double? = nil,
        weight: Double? = nil,
        avatarData: Data? = nil
    ) {
        self.id = id
        self.phone = phone
        self.name = name
        self.gender = gender
        self.birthDate = birthDate
        self.height = height
        self.weight = weight
        self.avatarData = avatarData
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    enum Gender: String, Codable, CaseIterable {
        case male
        case female

        var displayName: String {
            switch self {
            case .male: return String(localized: "男")
            case .female: return String(localized: "女")
            }
        }
    }
}
