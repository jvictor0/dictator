import SwiftUI

struct HostAppRootView: View {
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
                }
            }
            .navigationTitle("Dictator Keyboard")
        }
    }
}
