import DictatorCore
import Foundation
import LocalAuthentication
import Security

final class KeychainSecretStore: SecretStore {
    private let service: String
    private let account: String

    init(service: String = "com.joyo.dictator", account: String = "openai_api_key") {
        self.service = service
        self.account = account
    }

    func getOpenAIKey() throws -> String? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw KeychainError.readFailed(status)
        }
        guard let data = item as? Data,
              let key = String(data: data, encoding: .utf8),
              !key.isEmpty
        else {
            return nil
        }
        return key
    }

    func hasOpenAIKeyWithoutPrompt() -> Bool {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        let authContext = LAContext()
        authContext.interactionNotAllowed = true
        query[kSecUseAuthenticationContext as String] = authContext

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data,
                  let key = String(data: data, encoding: .utf8)
            else {
                return false
            }
            return !key.isEmpty
        case errSecInteractionNotAllowed:
            // Key exists but would require UI; treat as present to avoid startup prompt churn.
            return true
        default:
            return false
        }
    }

    func setOpenAIKey(_ key: String) throws {
        let normalized = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = normalized.data(using: .utf8), !normalized.isEmpty else {
            throw KeychainError.writeFailed(errSecParam)
        }

        var query = baseQuery()
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        if status == errSecSuccess {
            let attrs: [String: Any] = [kSecValueData as String: data]
            let updateStatus = SecItemUpdate(query as CFDictionary, attrs as CFDictionary)
            guard updateStatus == errSecSuccess else {
                throw KeychainError.writeFailed(updateStatus)
            }
            return
        }

        if status != errSecItemNotFound {
            throw KeychainError.writeFailed(status)
        }

        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let addStatus = SecItemAdd(query as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw KeychainError.writeFailed(addStatus)
        }
    }

    func clearOpenAIKey() throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

enum KeychainError: Error {
    case readFailed(OSStatus)
    case writeFailed(OSStatus)
    case deleteFailed(OSStatus)
}
