import Foundation
import Security

enum KeychainStore {
    enum Key: String {
        case youtubeAPIKey
        case xBearerToken
    }

    private static let service = "com.dodo-reach.QuickPeek"

    static func string(for key: Key) -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return ""
        }

        return value
    }

    @discardableResult
    static func set(_ value: String, for key: Key) -> OSStatus {
        if value.isEmpty {
            return deleteValue(for: key)
        }

        guard let data = value.data(using: .utf8) else {
            return errSecParam
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return updateStatus
        }

        var insertQuery = query
        insertQuery[kSecValueData as String] = data
        return SecItemAdd(insertQuery as CFDictionary, nil)
    }

    @discardableResult
    static func deleteValue(for key: Key) -> OSStatus {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecItemNotFound ? errSecSuccess : status
    }
}
