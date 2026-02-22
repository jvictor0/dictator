import AppKit
import ApplicationServices

public enum ClipboardInserter {
    public enum InsertError: Error, Equatable {
        case accessibilityPermissionMissing
        case clipboardWriteFailed
        case keyEventSynthesisFailed
    }

    private static let selectedTextLimit = 12000

    struct PasteboardSnapshot {
        let items: [NSPasteboardItem]
    }

    static func snapshot(_ pasteboard: NSPasteboard) -> PasteboardSnapshot {
        let copiedItems: [NSPasteboardItem] = (pasteboard.pasteboardItems ?? []).map { item in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    copy.setData(data, forType: type)
                }
            }
            return copy
        }
        return PasteboardSnapshot(items: copiedItems)
    }

    @discardableResult
    static func restore(_ snapshot: PasteboardSnapshot, to pasteboard: NSPasteboard) -> Bool {
        pasteboard.clearContents()
        guard !snapshot.items.isEmpty else {
            return true
        }
        return pasteboard.writeObjects(snapshot.items)
    }

    @discardableResult
    public static func insert(_ text: String) -> Result<Void, InsertError> {
        TraceLogger.log("insert begin (textLength=\(text.count))")
        guard AXIsProcessTrusted() else {
            TraceLogger.log("insert failed: accessibility permission missing")
            return .failure(.accessibilityPermissionMissing)
        }

        let pb = NSPasteboard.general
        let priorClipboard = snapshot(pb)
        pb.clearContents()
        guard pb.setString(text, forType: .string) else {
            TraceLogger.log("insert failed: clipboard write failed")
            return .failure(.clipboardWriteFailed)
        }

        guard let source = CGEventSource(stateID: .hidSystemState),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) else {
            TraceLogger.log("insert failed: key event synthesis failed")
            return .failure(.keyEventSynthesisFailed)
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        TraceLogger.log("insert success: posted synthetic Cmd+V")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let restored = restore(priorClipboard, to: pb)
            TraceLogger.log("clipboard restore \(restored ? "succeeded" : "failed")")
        }

        return .success(())
    }

    public static func captureSelectedText() -> Result<String?, InsertError> {
        guard AXIsProcessTrusted() else {
            return .failure(.accessibilityPermissionMissing)
        }

        let pb = NSPasteboard.general
        let priorClipboard = snapshot(pb)

        guard synthesizeCommandKey(virtualKey: 8) else {
            return .failure(.keyEventSynthesisFailed)
        }

        Thread.sleep(forTimeInterval: 0.08)
        let selected = normalizedSelectedText(pb.string(forType: .string))
        _ = restore(priorClipboard, to: pb)
        return .success(selected)
    }

    static func normalizedSelectedText(_ value: String?) -> String? {
        guard let value else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }
        if trimmed.count <= selectedTextLimit {
            return trimmed
        }
        return String(trimmed.prefix(selectedTextLimit))
    }

    private static func synthesizeCommandKey(virtualKey: CGKeyCode) -> Bool {
        guard let source = CGEventSource(stateID: .hidSystemState),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: false) else {
            return false
        }
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        return true
    }
}
