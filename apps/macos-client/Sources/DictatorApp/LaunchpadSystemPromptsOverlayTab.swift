import AppKit
import DictatorCore

@MainActor
final class LaunchpadSystemPromptsOverlayTab: LaunchpadOverlayTab {
    struct PromptDetails {
        let fileName: String
        let body: String
    }

    typealias LoadPromptDetails = () async throws -> PromptDetails

    let id: String
    let title: String

    private let loadPromptDetails: LoadPromptDetails
    private let contentView = LaunchpadSystemPromptsOverlayView()

    init(
        id: String = "system-prompts",
        title: String = "System Prompts",
        loadPromptDetails: @escaping LoadPromptDetails
    ) {
        self.id = id
        self.title = title
        self.loadPromptDetails = loadPromptDetails
    }

    func makeContentView() -> NSView {
        Task { @MainActor [weak self] in
            await self?.reload()
        }
        return contentView
    }

    func overlayDidClose() {
        contentView.setPrompt(fileName: "", body: "")
        contentView.setStatus("Loading...")
    }

    @MainActor
    private func reload() async {
        do {
            let prompt = try await loadPromptDetails()
            contentView.setPrompt(fileName: prompt.fileName, body: prompt.body)
            contentView.setStatus("Active prompt loaded")
        } catch {
            contentView.setPrompt(fileName: "", body: "")
            contentView.setStatus("Failed: \(error)")
        }
    }
}

private final class LaunchpadSystemPromptsOverlayView: NSView {
    private let titleLabel = NSTextField(labelWithString: "System Prompts")
    private let fileLabel = NSTextField(labelWithString: "")
    private let statusLabel = NSTextField(labelWithString: "Loading...")
    private let scrollView = NSScrollView()
    private let promptTextView = NSTextView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        nil
    }

    func setPrompt(fileName: String, body: String) {
        fileLabel.stringValue = fileName.isEmpty ? "Current file: unavailable" : "Current file: \(fileName)"
        promptTextView.string = body
    }

    func setStatus(_ text: String) {
        statusLabel.stringValue = text
    }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        titleLabel.font = .systemFont(ofSize: 28, weight: .semibold)
        titleLabel.textColor = .white

        fileLabel.font = .monospacedSystemFont(ofSize: 13, weight: .medium)
        fileLabel.textColor = NSColor.white.withAlphaComponent(0.85)

        statusLabel.font = .systemFont(ofSize: 12, weight: .regular)
        statusLabel.textColor = NSColor.white.withAlphaComponent(0.7)

        let headerStack = NSStackView(views: [titleLabel, fileLabel, statusLabel])
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        headerStack.orientation = .vertical
        headerStack.alignment = .leading
        headerStack.spacing = 6

        promptTextView.frame = NSRect(x: 0, y: 0, width: 900, height: 600)
        promptTextView.minSize = NSSize(width: 0, height: 0)
        promptTextView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        promptTextView.isVerticallyResizable = true
        promptTextView.isHorizontallyResizable = false
        promptTextView.autoresizingMask = [.width]
        promptTextView.textContainerInset = NSSize(width: 8, height: 8)
        promptTextView.textContainer?.containerSize = NSSize(width: 900, height: CGFloat.greatestFiniteMagnitude)
        promptTextView.textContainer?.widthTracksTextView = true
        promptTextView.textContainer?.lineBreakMode = .byWordWrapping
        promptTextView.isEditable = false
        promptTextView.isSelectable = true
        promptTextView.backgroundColor = NSColor.black.withAlphaComponent(0.22)
        promptTextView.textColor = .white
        promptTextView.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        promptTextView.drawsBackground = true

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.borderType = .bezelBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.documentView = promptTextView

        addSubview(headerStack)
        addSubview(scrollView)

        NSLayoutConstraint.activate([
            headerStack.topAnchor.constraint(equalTo: topAnchor, constant: 24),
            headerStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            headerStack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -24),

            scrollView.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 14),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -24)
        ])
    }
}
