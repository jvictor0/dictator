import DictatorCore
import Foundation

final class SettingsViewModel {
    private let secretStore: SecretStore

    init(secretStore: SecretStore) {
        self.secretStore = secretStore
    }

    func hasAPIKey() -> Bool {
        guard let value = try? secretStore.getOpenAIKey() else {
            return false
        }
        return !(value?.isEmpty ?? true)
    }

    func saveAPIKey(_ value: String) throws {
        try secretStore.setOpenAIKey(value)
    }

    func clearAPIKey() throws {
        try secretStore.clearOpenAIKey()
    }
}
