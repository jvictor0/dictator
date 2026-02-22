import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var apiKeyInput: String = ""
    @Published private(set) var statusMessage: String = ""
    @Published private(set) var hasStoredKey: Bool = false

    private let store = SharedKeychainSecretStore()

    func refresh() {
        do {
            let key = try store.getOpenAIKey()?.trimmingCharacters(in: .whitespacesAndNewlines)
            hasStoredKey = !(key?.isEmpty ?? true)
            statusMessage = hasStoredKey ? "OpenAI key is saved." : "OpenAI key not set."
        } catch {
            statusMessage = "Could not read keychain item."
        }
    }

    func save() {
        do {
            try store.setOpenAIKey(apiKeyInput)
            apiKeyInput = ""
            refresh()
        } catch {
            statusMessage = "Failed to save OpenAI key."
        }
    }

    func clear() {
        do {
            try store.clearOpenAIKey()
            refresh()
        } catch {
            statusMessage = "Failed to clear OpenAI key."
        }
    }
}
