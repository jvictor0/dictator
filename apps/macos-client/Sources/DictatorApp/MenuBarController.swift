import AppKit

final class MenuBarController {
    private let statusItem: NSStatusItem

    init() {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.menu = Self.makeMenu(target: self)
        statusItem.button?.title = Self.statusTitle
    }

    static let statusTitle = "🫡"

    static func makeMenu(target: AnyObject) -> NSMenu {
        let menu = NSMenu()
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = target
        menu.addItem(quitItem)
        return menu
    }

    @objc
    private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
