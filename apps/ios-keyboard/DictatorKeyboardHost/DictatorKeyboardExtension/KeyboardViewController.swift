import UIKit

final class KeyboardViewController: UIInputViewController {
    private enum InsertState {
        case idle
        case noTranscript
        case inserted
    }

    private let nextKeyboardButton = UIButton(type: .system)
    private let insertTranscriptButton = UIButton(type: .system)
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

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        nextKeyboardButton.isHidden = !needsInputModeSwitchKey
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

        view.addSubview(nextKeyboardButton)
        view.addSubview(statusLabel)
        view.addSubview(insertTranscriptButton)

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
            insertTranscriptButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8)
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
