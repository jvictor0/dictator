import UIKit

final class KeyboardViewController: UIInputViewController {
    private enum InsertState {
        case idle
        case noTranscript
        case inserted
    }

    private let nextKeyboardButton = UIButton(type: .system)
    private let insertTranscriptButton = UIButton(type: .system)
    private let openHostAppButton = UIButton(type: .system)
    private let statusLabel = UILabel()
    private var state: InsertState = .idle {
        didSet {
            renderState()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        state = SharedConfig.loadLatestTranscript() == nil ? .noTranscript : .idle
    }

    @objc
    private func handleInsertTranscriptTap() {
        guard let transcript = SharedConfig.loadLatestTranscript() else {
            state = .noTranscript
            return
        }

        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            state = .noTranscript
            return
        }

        textDocumentProxy.insertText(trimmed)
        state = .inserted
    }

    @objc
    private func handleOpenHostAppTap() {
        guard let url = URL(string: SharedConfig.hostAppLaunchURLString) else {
            statusLabel.text = "Host app URL is invalid."
            SharedConfig.appendDiagnosticsLine("[Keyboard] Invalid host app URL: \(SharedConfig.hostAppLaunchURLString)")
            return
        }

        statusLabel.text = "Opening host app..."
        SharedConfig.appendDiagnosticsLine("[Keyboard] Attempting extensionContext.open(\(url.absoluteString))")

        extensionContext?.open(url) { [weak self] success in
            DispatchQueue.main.async {
                guard let self else {
                    return
                }

                SharedConfig.appendDiagnosticsLine("[Keyboard] extensionContext.open success=\(success)")
                if success {
                    self.statusLabel.text = "Opening host app..."
                    return
                }
                self.statusLabel.text = "Unable to open host app."
                SharedConfig.appendDiagnosticsLine("[Keyboard] Host app open failed via extensionContext.")
            }
        }
    }

    private func setupUI() {
        view.backgroundColor = .systemGray6

        nextKeyboardButton.translatesAutoresizingMaskIntoConstraints = false
        nextKeyboardButton.setTitle(NSLocalizedString("Next Keyboard", comment: "Title for globe button"), for: .normal)
        nextKeyboardButton.titleLabel?.font = .preferredFont(forTextStyle: .caption1)
        nextKeyboardButton.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = .preferredFont(forTextStyle: .caption1)
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 2
        statusLabel.textColor = .secondaryLabel

        insertTranscriptButton.translatesAutoresizingMaskIntoConstraints = false
        insertTranscriptButton.setTitle("Insert Latest Transcript", for: .normal)
        insertTranscriptButton.titleLabel?.font = .boldSystemFont(ofSize: 22)
        insertTranscriptButton.layer.cornerRadius = 18
        insertTranscriptButton.layer.borderWidth = 2
        insertTranscriptButton.layer.borderColor = UIColor.systemGray3.cgColor
        insertTranscriptButton.addTarget(self, action: #selector(handleInsertTranscriptTap), for: .touchUpInside)

        openHostAppButton.translatesAutoresizingMaskIntoConstraints = false
        openHostAppButton.setTitle("Open Dictator App", for: .normal)
        openHostAppButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        openHostAppButton.layer.cornerRadius = 14
        openHostAppButton.layer.borderWidth = 1
        openHostAppButton.layer.borderColor = UIColor.systemBlue.cgColor
        openHostAppButton.backgroundColor = .systemBlue.withAlphaComponent(0.12)
        openHostAppButton.setTitleColor(.systemBlue, for: .normal)
        openHostAppButton.addTarget(self, action: #selector(handleOpenHostAppTap), for: .touchUpInside)

        view.addSubview(nextKeyboardButton)
        view.addSubview(statusLabel)
        view.addSubview(insertTranscriptButton)
        view.addSubview(openHostAppButton)

        NSLayoutConstraint.activate([
            nextKeyboardButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            nextKeyboardButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),

            statusLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 10),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),

            insertTranscriptButton.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 10),
            insertTranscriptButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            insertTranscriptButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            insertTranscriptButton.heightAnchor.constraint(equalToConstant: 68),
            
            openHostAppButton.topAnchor.constraint(equalTo: insertTranscriptButton.bottomAnchor, constant: 8),
            openHostAppButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            openHostAppButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            openHostAppButton.heightAnchor.constraint(equalToConstant: 52),
            openHostAppButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8)
        ])
    }

    private func renderState() {
        switch state {
        case .idle:
            statusLabel.text = "Ready"
            insertTranscriptButton.setTitle("Insert Latest Transcript", for: .normal)
            insertTranscriptButton.backgroundColor = .white
            insertTranscriptButton.setTitleColor(.black, for: .normal)
        case .noTranscript:
            statusLabel.text = "No saved transcript. Record in the main app first."
            insertTranscriptButton.setTitle("Insert Latest Transcript", for: .normal)
            insertTranscriptButton.backgroundColor = .white
            insertTranscriptButton.setTitleColor(.black, for: .normal)
        case .inserted:
            statusLabel.text = "Inserted latest transcript"
            insertTranscriptButton.setTitle("Insert Again", for: .normal)
            insertTranscriptButton.backgroundColor = .systemBlue
            insertTranscriptButton.setTitleColor(.white, for: .normal)
        }
    }
}
