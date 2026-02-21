import AppKit

final class MenuBarController {
    private let statusItem: NSStatusItem
    private let stateMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")

    init() {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.menu = Self.makeMenu(stateMenuItem: stateMenuItem, target: self)
        statusItem.button?.title = Self.statusTitle
        setState("Ready")
    }

    static let statusTitle = "🫡"

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
    }

    @objc
    private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
