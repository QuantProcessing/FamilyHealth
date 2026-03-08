import Foundation
import SwiftData

@Model
final class AIModelConfig {
    @Attribute(.unique) var id: UUID
    var name: String
    var provider: Provider
    var apiEndpoint: String
    var modelName: String
    var isDefault: Bool
    var createdAt: Date
    var updatedAt: Date

    /// API Key is stored in Keychain, not in SwiftData.
    /// Use KeychainManager.getAPIKey(configId:) to retrieve.
    var keychainKeyId: String {
        "ai_api_key_\(id.uuidString)"
    }

    init(
        id: UUID = UUID(),
        name: String,
        provider: Provider,
        apiEndpoint: String,
        modelName: String,
        isDefault: Bool = false
    ) {
        self.id = id
        self.name = name
        self.provider = provider
        self.apiEndpoint = apiEndpoint
        self.modelName = modelName
        self.isDefault = isDefault
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    enum Provider: String, Codable, CaseIterable {
        case openai
        case claude
        case gemini
        case ollama
        case custom

        var displayName: String {
            switch self {
            case .openai: return "OpenAI"
            case .claude: return "Claude"
            case .gemini: return "Gemini"
            case .ollama: return "Ollama"
            case .custom: return String(localized: "自定义")
            }
        }
    }
}
