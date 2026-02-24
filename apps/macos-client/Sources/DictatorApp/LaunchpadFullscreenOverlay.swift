import AppKit

struct LaunchpadOverlayState {
    let isVisible: Bool
    let selectedTabIndex: Int
}

protocol LaunchpadOverlayTab {
    var id: String { get }
    var title: String { get }
    func makeContentView() -> NSView
}

struct LaunchpadPlaceholderTab: LaunchpadOverlayTab {
    let id: String
    let title: String
    let description: String

    func makeContentView() -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.clear.cgColor

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 34, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.alignment = .center

        let descriptionLabel = NSTextField(labelWithString: description)
        descriptionLabel.font = .systemFont(ofSize: 16, weight: .regular)
        descriptionLabel.textColor = NSColor.white.withAlphaComponent(0.75)
        descriptionLabel.alignment = .center

        let stack = NSStackView(views: [titleLabel, descriptionLabel])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.spacing = 8
        stack.alignment = .centerX

        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])

        return container
    }
}

@MainActor
final class LaunchpadFullscreenOverlayController {
    private let tabs: [any LaunchpadOverlayTab]
    private var window: NSWindow?
    private var contentController: LaunchpadOverlayContentController?
    private(set) var isVisible = false
    var onStateChanged: ((LaunchpadOverlayState) -> Void)?
    var tabCount: Int { tabs.count }

    init(tabs: [any LaunchpadOverlayTab]) {
        precondition(!tabs.isEmpty, "Launchpad overlay requires at least one tab")
        self.tabs = tabs
    }

    @discardableResult
    func toggle() -> Bool {
        if isVisible {
            hide()
        } else {
            show()
        }
        return isVisible
    }

    func show() {
        ensureWindow()
        guard let window else {
            return
        }
        window.setFrame(activeScreenFrame(), display: true)
        window.orderFront(nil)
        isVisible = true
        notifyStateChanged()
    }

    func hide() {
        contentController?.resetToInitialTab()
        window?.orderOut(nil)
        isVisible = false
        notifyStateChanged()
    }

    @discardableResult
    func selectTab(index: Int, showIfHidden: Bool = true) -> Bool {
        guard tabs.indices.contains(index) else {
            return false
        }
        ensureWindow()
        contentController?.selectTab(index: index)
        if showIfHidden {
            show()
        } else {
            notifyStateChanged()
        }
        return true
    }

    private func ensureWindow() {
        if window != nil {
            return
        }

        let controller = LaunchpadOverlayContentController(tabs: tabs)
        controller.onSelectionChanged = { [weak self] _ in
            self?.notifyStateChanged()
        }

        let overlayWindow = NSWindow(
            contentRect: activeScreenFrame(),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        overlayWindow.contentViewController = controller
        overlayWindow.isOpaque = false
        overlayWindow.backgroundColor = NSColor.black.withAlphaComponent(0.95)
        overlayWindow.level = .floating
        overlayWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        overlayWindow.hasShadow = false
        overlayWindow.ignoresMouseEvents = true

        window = overlayWindow
        contentController = controller
    }

    private func notifyStateChanged() {
        onStateChanged?(
            LaunchpadOverlayState(
                isVisible: isVisible,
                selectedTabIndex: contentController?.selectedTabIndex ?? 0
            )
        )
    }

    private func activeScreenFrame() -> NSRect {
        if let keyWindowScreen = NSApp.keyWindow?.screen {
            return keyWindowScreen.frame
        }
        if let mainScreen = NSScreen.main {
            return mainScreen.frame
        }
        return NSRect(x: 0, y: 0, width: 1440, height: 900)
    }
}

@MainActor
private final class LaunchpadOverlayContentController: NSViewController {
    private let tabs: [any LaunchpadOverlayTab]
    private let tabBar: NSSegmentedControl
    private let contentContainer = NSView()
    var onSelectionChanged: ((Int) -> Void)?
    private var selectedIndex = 0
    var selectedTabIndex: Int { selectedIndex }

    init(tabs: [any LaunchpadOverlayTab]) {
        self.tabs = tabs
        self.tabBar = NSSegmentedControl(labels: tabs.map { $0.title }, trackingMode: .selectOne, target: nil, action: nil)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.95).cgColor

        tabBar.translatesAutoresizingMaskIntoConstraints = false
        tabBar.selectedSegment = 0
        tabBar.target = self
        tabBar.action = #selector(tabSelected(_:))

        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.wantsLayer = true
        contentContainer.layer?.backgroundColor = NSColor.clear.cgColor

        view.addSubview(tabBar)
        view.addSubview(contentContainer)

        NSLayoutConstraint.activate([
            tabBar.topAnchor.constraint(equalTo: view.topAnchor, constant: 24),
            tabBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            tabBar.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24),
            tabBar.heightAnchor.constraint(equalToConstant: 30),

            contentContainer.topAnchor.constraint(equalTo: tabBar.bottomAnchor, constant: 20),
            contentContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        renderSelectedTab()
    }

    func resetToInitialTab() {
        selectedIndex = 0
        tabBar.selectedSegment = 0
        renderSelectedTab()
        onSelectionChanged?(selectedIndex)
    }

    func selectTab(index: Int) {
        guard tabs.indices.contains(index) else {
            return
        }
        selectedIndex = index
        tabBar.selectedSegment = index
        renderSelectedTab()
        onSelectionChanged?(selectedIndex)
    }

    @objc
    private func tabSelected(_ sender: NSSegmentedControl) {
        selectedIndex = sender.selectedSegment
        renderSelectedTab()
        onSelectionChanged?(selectedIndex)
    }

    private func renderSelectedTab() {
        guard tabs.indices.contains(selectedIndex) else {
            return
        }

        contentContainer.subviews.forEach { $0.removeFromSuperview() }
        let selectedView = tabs[selectedIndex].makeContentView()
        selectedView.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(selectedView)

        NSLayoutConstraint.activate([
            selectedView.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            selectedView.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            selectedView.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            selectedView.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor)
        ])
    }
}
