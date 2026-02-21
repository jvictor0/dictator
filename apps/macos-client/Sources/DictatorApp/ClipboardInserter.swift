import AppKit

public enum ClipboardInserter {
    @discardableResult
    public static func insert(_ text: String) -> Bool {
        let pb = NSPasteboard.general
        pb.clearContents()
        return pb.setString(text, forType: .string)
    }
}
