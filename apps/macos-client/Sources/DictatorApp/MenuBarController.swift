import AppKit

final class MenuBarController {
    private let statusItem: NSStatusItem
    private let recordingController: RecordingController

    init(recordingController: RecordingController) {
        self.recordingController = recordingController
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        configureMenu()
        updateTitle()
    }

    private func configureMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Toggle Dictation", action: #selector(toggleDictation), keyEquivalent: "d"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))

        menu.items.forEach { $0.target = self }
        statusItem.menu = menu
    }

    private func updateTitle() {
        statusItem.button?.title = recordingController.isRecording ? "Dictator ●" : "Dictator"
    }

    @objc
    func toggleDictation() {
        recordingController.toggle()
        updateTitle()
    }

    @objc
    private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
