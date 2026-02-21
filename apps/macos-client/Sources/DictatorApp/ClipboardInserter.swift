import AppKit
import ApplicationServices

public enum ClipboardInserter {
    public enum InsertError: Error, Equatable {
        case accessibilityPermissionMissing
        case clipboardWriteFailed
        case keyEventSynthesisFailed
    }

    @discardableResult
    public static func insert(_ text: String) -> Result<Void, InsertError> {
        guard AXIsProcessTrusted() else {
            return .failure(.accessibilityPermissionMissing)
        }

        let pb = NSPasteboard.general
        pb.clearContents()
        guard pb.setString(text, forType: .string) else {
            return .failure(.clipboardWriteFailed)
        }

        guard let source = CGEventSource(stateID: .hidSystemState),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) else {
            return .failure(.keyEventSynthesisFailed)
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        return .success(())
    }
}
