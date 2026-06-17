import Foundation
import Security

public enum KeychainStoreError: LocalizedError {
    case unexpectedStatus(OSStatus)

    public var errorDescription: String? {
        switch self {
        case let .unexpectedStatus(status):
            return "Keychain 操作失败：\(status)"
        }
    }
}

/// 合并存储的平台凭证，单个 Keychain 条目
public struct StoredCredentials: Codable, Equatable {
    public var bearerToken: String
    public var mimoCookie: String

    public init(bearerToken: String = "", mimoCookie: String = "") {
        self.bearerToken = bearerToken
        self.mimoCookie = mimoCookie
    }
}

public final class KeychainStore {
    private let service = "DeepSeekUsageMonitor"
    private let combinedAccount = "AllCredentials"

    // MARK: - Legacy accounts (用于迁移旧数据)
    private enum LegacyAccount: String {
        case platformBearerToken = "DeepSeekPlatformBearerToken"
        case mimoCookie = "MimoPlatformCookie"
    }

    public init() {}

    // MARK: - 合并读写（单条目，只触发一次授权）

    public func readCredentials() throws -> StoredCredentials {
        // 先尝试读合并后的条目
        if let data = try readRaw(account: combinedAccount) {
            if let creds = try? JSONDecoder().decode(StoredCredentials.self, from: Data(data.utf8)) {
                return creds
            }
        }

        // 迁移：读取旧的分条目
        var creds = StoredCredentials()
        if let token = try readRaw(account: LegacyAccount.platformBearerToken.rawValue) {
            creds.bearerToken = token
        }
        if let cookie = try readRaw(account: LegacyAccount.mimoCookie.rawValue) {
            creds.mimoCookie = cookie
        }

        // 迁移后写回合并条目，并清理旧条目
        if !creds.bearerToken.isEmpty || !creds.mimoCookie.isEmpty {
            try saveCredentials(creds)
            try? deleteRaw(account: LegacyAccount.platformBearerToken.rawValue)
            try? deleteRaw(account: LegacyAccount.mimoCookie.rawValue)
        }

        return creds
    }

    public func saveCredentials(_ credentials: StoredCredentials) throws {
        let data = try JSONEncoder().encode(credentials)
        let value = String(data: data, encoding: .utf8) ?? "{}"
        try saveRaw(value: value, account: combinedAccount)
    }

    // MARK: - 底层 Keychain 操作

    private func readRaw(account: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else {
            throw KeychainStoreError.unexpectedStatus(status)
        }
        guard let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func saveRaw(value: String, account: String) throws {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else {
            throw KeychainStoreError.unexpectedStatus(updateStatus)
        }

        var addQuery = query
        addQuery[kSecValueData as String] = data
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw KeychainStoreError.unexpectedStatus(addStatus)
        }
    }

    private func deleteRaw(account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            throw KeychainStoreError.unexpectedStatus(status)
        }
    }
}
