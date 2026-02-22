import Foundation
import Security

struct SharedKeychainSecretStore {
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
            throw StoreError.readFailed(status)
        }
        guard let data = item as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    func setOpenAIKey(_ key: String) throws {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else {
            throw StoreError.writeFailed(errSecParam)
        }

        var query = baseQuery()
        let lookup = SecItemCopyMatching(query as CFDictionary, nil)
        if lookup == errSecSuccess {
            let attrs: [String: Any] = [kSecValueData as String: data]
            let status = SecItemUpdate(query as CFDictionary, attrs as CFDictionary)
            guard status == errSecSuccess else {
                throw StoreError.writeFailed(status)
            }
            return
        }

        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw StoreError.writeFailed(status)
        }
    }

    func clearOpenAIKey() throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw StoreError.deleteFailed(status)
        }
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: SharedConfig.openAIKeyService,
            kSecAttrAccount as String: SharedConfig.openAIKeyAccount,
            kSecAttrAccessGroup as String: SharedConfig.keychainAccessGroup
        ]
    }

    enum StoreError: Error {
        case readFailed(OSStatus)
        case writeFailed(OSStatus)
        case deleteFailed(OSStatus)
    }
}
