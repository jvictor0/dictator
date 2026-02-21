import AppKit
import XCTest
@testable import DictatorApp

final class SmokeTests: XCTestCase {
    func testStatusTitleIsSaluteEmoji() {
        XCTAssertEqual(MenuBarController.statusTitle, "🫡")
    }

    func testStatusTitleIncludesIndicator() {
        XCTAssertEqual(MenuBarController.makeStatusTitle(isRecording: false), "🫡 ⚪")
        XCTAssertEqual(MenuBarController.makeStatusTitle(isRecording: true), "🫡 🔴")
    }

    func testMenuIncludesQuitAction() {
        let target = NSObject()
        let stateItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        let menu = MenuBarController.makeMenu(stateMenuItem: stateItem, target: target)

        XCTAssertEqual(menu.items.count, 3)
        XCTAssertEqual(menu.items[2].title, "Quit")
        XCTAssertEqual(menu.items[2].keyEquivalent, "q")
    }

    func testCapsLockTriggerOnlyOnCapsFlagsChanged() {
        XCTAssertTrue(CapsLockTriggerController.shouldTrigger(eventType: .flagsChanged, keyCode: 57))
        XCTAssertFalse(CapsLockTriggerController.shouldTrigger(eventType: .keyDown, keyCode: 57))
        XCTAssertFalse(CapsLockTriggerController.shouldTrigger(eventType: .flagsChanged, keyCode: 0))
    }

    func testCapsLockTriggerDeduplicatesRapidDuplicateEvents() {
        XCTAssertTrue(
            CapsLockTriggerController.shouldAcceptTrigger(
                lastTimestamp: nil,
                newTimestamp: 100.0,
                minimumInterval: 0.12
            )
        )
        XCTAssertFalse(
            CapsLockTriggerController.shouldAcceptTrigger(
                lastTimestamp: 100.0,
                newTimestamp: 100.05,
                minimumInterval: 0.12
            )
        )
        XCTAssertTrue(
            CapsLockTriggerController.shouldAcceptTrigger(
                lastTimestamp: 100.0,
                newTimestamp: 100.25,
                minimumInterval: 0.12
            )
        )
    }

    func testRecordingToggleFlipsState() {
        let controller = RecordingController()
        XCTAssertFalse(controller.isRecording)
        XCTAssertTrue(controller.toggle())
        XCTAssertTrue(controller.isRecording)
        XCTAssertFalse(controller.toggle())
        XCTAssertFalse(controller.isRecording)
    }

    func testClipboardSnapshotRestoreRoundTrip() {
        let name = NSPasteboard.Name("dictator.test.clipboard.\(UUID().uuidString)")
        let pasteboard = NSPasteboard(name: name)

        pasteboard.clearContents()
        XCTAssertTrue(pasteboard.setString("original", forType: .string))
        let snap = ClipboardInserter.snapshot(pasteboard)

        pasteboard.clearContents()
        XCTAssertTrue(pasteboard.setString("temporary", forType: .string))
        XCTAssertTrue(ClipboardInserter.restore(snap, to: pasteboard))
        XCTAssertEqual(pasteboard.string(forType: .string), "original")
    }

    func testDecodeDictateResponseShape() throws {
        let json = """
        {
          "raw_transcript": "hello world",
          "revised_text": "Hello world.",
          "edit_summary": "Punctuation normalized.",
          "uncertainty_flags": []
        }
        """.data(using: .utf8)!

        let decoded = try APIClient.decodeDictateResponse(from: json)
        XCTAssertEqual(decoded.revised_text, "Hello world.")
    }
}
