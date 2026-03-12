import Foundation
import SwiftData

@Model
final class AIModelConfig: @unchecked Sendable {
    @Attribute(.unique) var id: UUID
    var name: String
    var provider: Provider
    var apiEndpoint: String
    var modelName: String
    var isDefault: Bool
    var isBuiltIn: Bool
    var createdAt: Date
    var updatedAt: Date

    /// API Key is stored in Keychain, not in SwiftData.
    var keychainKeyId: String {
        "ai_api_key_\(id.uuidString)"
    }

    init(
        id: UUID = UUID(),
        name: String,
        provider: Provider,
        apiEndpoint: String,
        modelName: String,
        isDefault: Bool = false,
        isBuiltIn: Bool = false
    ) {
        self.id = id
        self.name = name
        self.provider = provider
        self.apiEndpoint = apiEndpoint
        self.modelName = modelName
        self.isDefault = isDefault
        self.isBuiltIn = isBuiltIn
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    enum Provider: String, Codable, CaseIterable {
        case siliconflow
        case deepseek
        case glm
        case kimi
        case doubao
        case qwen
        case custom

        var displayName: String {
            switch self {
            case .siliconflow: return "硅基流动"
            case .deepseek: return "DeepSeek"
            case .glm: return "智谱 GLM"
            case .kimi: return "Kimi (月之暗面)"
            case .doubao: return "豆包 (字节)"
            case .qwen: return "通义千问"
            case .custom: return "自定义"
            }
        }

        var defaultEndpoint: String {
            switch self {
            case .siliconflow: return "https://api.siliconflow.cn/v1"
            case .deepseek: return "https://api.deepseek.com/v1"
            case .glm: return "https://open.bigmodel.cn/api/paas/v4"
            case .kimi: return "https://api.moonshot.cn/v1"
            case .doubao: return "https://ark.cn-beijing.volces.com/api/v3"
            case .qwen: return "https://dashscope.aliyuncs.com/compatible-mode/v1"
            case .custom: return ""
            }
        }

        var defaultModel: String {
            switch self {
            case .siliconflow: return "internlm/internlm2_5-7b-chat"
            case .deepseek: return "deepseek-chat"
            case .glm: return "glm-4-flash"
            case .kimi: return "moonshot-v1-8k"
            case .doubao: return "doubao-1.5-pro-32k-250115"
            case .qwen: return "qwen-plus"
            case .custom: return ""
            }
        }

        var iconName: String {
            switch self {
            case .siliconflow: return "bolt.circle.fill"
            case .deepseek: return "brain.head.profile"
            case .glm: return "sparkles"
            case .kimi: return "moon.stars"
            case .doubao: return "bubble.left.and.text.bubble.right"
            case .qwen: return "cloud.bolt"
            case .custom: return "wrench.and.screwdriver"
            }
        }
    }

    /// Built-in free API key (SiliconFlow)
    static let builtInAPIKey = "sk-gwfvvoogqemgpipnhyitauiaineagwiefyvwuplbclicdagr"

    /// Proxy endpoint served by the FamilyHealth backend
    static let proxyEndpoint = "http://localhost:8080/api/v1/ai/proxy"
}
