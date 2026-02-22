import UIKit

final class KeyboardViewController: UIInputViewController {
    private let pipeline = KeyboardPipelineController()
    private let statusLabel = UILabel()
    private let insertButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    private func setupUI() {
        view.backgroundColor = .systemBackground

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.text = "Dictator keyboard ready"
        statusLabel.font = .preferredFont(forTextStyle: .caption1)
        statusLabel.textColor = .secondaryLabel

        insertButton.translatesAutoresizingMaskIntoConstraints = false
        insertButton.setTitle("Run Dictation", for: .normal)
        insertButton.addTarget(self, action: #selector(runDictationTapped), for: .touchUpInside)

        view.addSubview(statusLabel)
        view.addSubview(insertButton)

        NSLayoutConstraint.activate([
            statusLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            insertButton.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 12),
            insertButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            insertButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8)
        ])
    }

    @objc
    private func runDictationTapped() {
        statusLabel.text = "Dictation scaffold: wire audio + pipeline next"
        // Temporary scaffolding action to verify extension load and insertion permissions.
        textDocumentProxy.insertText(" ")
        textDocumentProxy.deleteBackward()

        Task {
            do {
                _ = try await pipeline.runDictation(
                    audioData: Data(),
                    sampleRate: 16_000,
                    locale: "en-US",
                    sessionID: UUID().uuidString
                )
            } catch {
                await MainActor.run {
                    self.statusLabel.text = "Pipeline not wired yet"
                }
            }
        }
    }
}
