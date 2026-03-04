import SwiftUI

struct HostAppRootView: View {
    private var configuredServerURL: String {
        SharedConfig.resolvedServerURLString(bundle: .main)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Keyboard Setup") {
                    Text("1. Enable Dictator keyboard in Settings > General > Keyboard.")
                    Text("2. Enable Allow Full Access for network refinement.")
                }

                Section("Status") {
                    Text("This template stores no secrets and has no API key entry.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("Server URL: \(configuredServerURL)")
                    Text("Mic and network checks run in keyboard extension at runtime.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Dictator Keyboard")
        }
    }
}
