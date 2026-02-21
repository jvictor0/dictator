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
        let isTrusted = AXIsProcessTrustedWithOptions([
            kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true
        ] as CFDictionary)
        TraceLogger.log("caps-trigger start requested (axTrusted=\(isTrusted))")

        guard isTrusted else {
            TraceLogger.log("caps-trigger start failed: accessibility permission missing")
            return false
        }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handle(event, source: "global")
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handle(event, source: "local")
            return event
        }

        let started = globalMonitor != nil || localMonitor != nil
        TraceLogger.log("caps-trigger monitors armed (global=\(globalMonitor != nil), local=\(localMonitor != nil), started=\(started))")
        return started
    }

    func stop() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
            TraceLogger.log("caps-trigger global monitor removed")
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
            TraceLogger.log("caps-trigger local monitor removed")
        }
    }

    func handle(_ event: NSEvent, source: String) {
        TraceLogger.log(
            "caps-event source=\(source) type=\(event.type.rawValue) keyCode=\(event.keyCode) modifierFlags=\(event.modifierFlags.rawValue)"
        )
        if Self.shouldTrigger(eventType: event.type, keyCode: event.keyCode) {
            TraceLogger.log("caps-trigger fired (source=\(source))")
            onTrigger()
        }
    }

    static func shouldTrigger(eventType: NSEvent.EventType, keyCode: UInt16) -> Bool {
        eventType == .flagsChanged && keyCode == capsLockKeyCode
    }
}
