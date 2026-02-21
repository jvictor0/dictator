import AppKit

final class DictatorAppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBarController = MenuBarController()
    }
}

let app = NSApplication.shared
let delegate = DictatorAppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
