import Foundation
import Security

/// Secure storage for sensitive data (API keys, tokens) using iOS Keychain.
enum KeychainManager {
    private static let service = "com.familyhealth.app"

    // MARK: - API Key Management

    static func saveAPIKey(_ key: String, for configId: UUID) throws {
        let account = "ai_api_key_\(configId.uuidString)"
        try save(key, account: account)
    }

    static func getAPIKey(for configId: UUID) -> String? {
        let account = "ai_api_key_\(configId.uuidString)"
        return get(account: account)
    }

    static func deleteAPIKey(for configId: UUID) throws {
        let account = "ai_api_key_\(configId.uuidString)"
        try delete(account: account)
    }

    // MARK: - Token Management (for remote mode)

    static func saveAuthToken(_ token: String) throws {
        try save(token, account: "auth_token")
    }

    static func getAuthToken() -> String? {
        return get(account: "auth_token")
    }

    static func deleteAuthToken() throws {
        try delete(account: "auth_token")
    }

    // MARK: - Generic Keychain Operations

    private static func save(_ value: String, account: String) throws {
        guard let data = value.data(using: .utf8) else { return }

        // Delete existing item first
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    private static func get(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func delete(account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }
}

enum KeychainError: LocalizedError {
    case saveFailed(OSStatus)
    case deleteFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .saveFailed(let status): return "Keychain save failed: \(status)"
        case .deleteFailed(let status): return "Keychain delete failed: \(status)"
        }
    }
}
