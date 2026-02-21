import AppKit

final class MenuBarController {
    enum IndicatorState {
        case idle
        case recording
        case refining
    }

    private let statusItem: NSStatusItem
    private let stateMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")

    init() {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.menu = Self.makeMenu(stateMenuItem: stateMenuItem, target: self)
        setIndicatorState(.idle)
        setState("Ready")
    }

    static let statusTitle = "🫡"
    static let idleIndicator = "⚪"
    static let recordingIndicator = "🔴"
    static let refiningIndicator = "🔵"

    static func makeMenu(stateMenuItem: NSMenuItem, target: AnyObject) -> NSMenu {
        let menu = NSMenu()
        stateMenuItem.isEnabled = false
        menu.addItem(stateMenuItem)
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
    private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
