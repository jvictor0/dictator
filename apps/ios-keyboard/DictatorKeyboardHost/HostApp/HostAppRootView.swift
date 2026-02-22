import SwiftUI

struct HostAppRootView: View {
    @StateObject private var viewModel = SettingsViewModel()

    var body: some View {
        NavigationStack {
            Form {
                Section("Keyboard Setup") {
                    Text("1. Enable Dictator keyboard in Settings > General > Keyboard.")
                    Text("2. Enable Allow Full Access for network refinement.")
                }

                Section("OpenAI Key") {
                    SecureField("sk-...", text: $viewModel.apiKeyInput)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    HStack {
                        Button("Save", action: viewModel.save)
                        Button("Clear", role: .destructive, action: viewModel.clear)
                    }
                    Text(viewModel.statusMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Dictator Keyboard")
            .onAppear(perform: viewModel.refresh)
        }
    }
}
