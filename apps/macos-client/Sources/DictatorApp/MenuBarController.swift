import AppKit

final class MenuBarController {
    enum IndicatorState {
        case idle
        case recording
        case refining
    }

    private let statusItem: NSStatusItem
    private let stateMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let launchpadStatusMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    var onSetAPIKey: (() -> Void)?
    var onClearAPIKey: (() -> Void)?

    init() {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.menu = Self.makeMenu(
            stateMenuItem: stateMenuItem,
            launchpadStatusMenuItem: launchpadStatusMenuItem,
            target: self
        )
        setIndicatorState(.idle)
        setState("Ready")
        setLaunchpadStatus("Initializing")
    }

    static let statusTitle = "🫡"
    static let idleIndicator = "⚪"
    static let recordingIndicator = "🔴"
    static let refiningIndicator = "🔵"

    static func makeMenu(stateMenuItem: NSMenuItem, target: AnyObject) -> NSMenu {
        let launchpadStatusMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        return makeMenu(
            stateMenuItem: stateMenuItem,
            launchpadStatusMenuItem: launchpadStatusMenuItem,
            target: target
        )
    }

    static func makeMenu(stateMenuItem: NSMenuItem, launchpadStatusMenuItem: NSMenuItem, target: AnyObject) -> NSMenu {
        let menu = NSMenu()
        stateMenuItem.isEnabled = false
        launchpadStatusMenuItem.isEnabled = false
        menu.addItem(stateMenuItem)
        menu.addItem(launchpadStatusMenuItem)
        menu.addItem(NSMenuItem.separator())
        let setKeyItem = NSMenuItem(title: "Set OpenAI Key (Fallback)…", action: #selector(setOpenAIKey), keyEquivalent: "k")
        setKeyItem.target = target
        menu.addItem(setKeyItem)
        let clearKeyItem = NSMenuItem(title: "Clear OpenAI Key (Fallback)", action: #selector(clearOpenAIKey), keyEquivalent: "")
        clearKeyItem.target = target
        menu.addItem(clearKeyItem)
        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = target
        menu.addItem(quitItem)
        return menu
    }

    func setState(_ message: String) {
        stateMenuItem.title = "Status: \(message)"
        TraceLogger.log("menu state updated: \(message)")
    }

    func setLaunchpadStatus(_ message: String) {
        launchpadStatusMenuItem.title = "LaunchPad: \(message)"
        TraceLogger.log("launchpad menu state updated: \(message)")
    }

    func setIndicatorState(_ state: IndicatorState) {
        statusItem.button?.title = Self.makeStatusTitle(state: state)
        TraceLogger.log("menu indicator updated (state=\(state))")
    }

    static func makeStatusTitle(state: IndicatorState) -> String {
        let indicator: String
        switch state {
        case .idle:
            indicator = idleIndicator
        case .recording:
            indicator = recordingIndicator
        case .refining:
            indicator = refiningIndicator
        }
        return "\(statusTitle) \(indicator)"
    }

    @objc
    private func setOpenAIKey() {
        onSetAPIKey?()
    }

    @objc
    private func clearOpenAIKey() {
        onClearAPIKey?()
    }

    @objc
    private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
