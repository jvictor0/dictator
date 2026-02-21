import AppKit
import ApplicationServices

final class CapsLockTriggerController {
    static let capsLockKeyCode: UInt16 = 57

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private let onTrigger: () -> Void

    init(onTrigger: @escaping () -> Void) {
        self.onTrigger = onTrigger
    }

    deinit {
        stop()
    }

    func start() -> Bool {
        guard AXIsProcessTrustedWithOptions([
            kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true
        ] as CFDictionary) else {
            return false
        }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handle(event)
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handle(event)
            return event
        }

        return globalMonitor != nil || localMonitor != nil
    }

    func stop() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
    }

    func handle(_ event: NSEvent) {
        if Self.shouldTrigger(eventType: event.type, keyCode: event.keyCode) {
            onTrigger()
        }
    }

    static func shouldTrigger(eventType: NSEvent.EventType, keyCode: UInt16) -> Bool {
        eventType == .flagsChanged && keyCode == capsLockKeyCode
    }
}
