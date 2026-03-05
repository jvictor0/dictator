import AppKit
import XCTest
@testable import DictatorApp

final class SmokeTests: XCTestCase {
    func testStatusTitleIsSaluteEmoji() {
        XCTAssertEqual(MenuBarController.statusTitle, "🫡")
    }

    func testStatusTitleIncludesIndicator() {
        XCTAssertEqual(MenuBarController.makeStatusTitle(state: .idle), "🫡 ⚪")
        XCTAssertEqual(MenuBarController.makeStatusTitle(state: .recording), "🫡 🔴")
        XCTAssertEqual(MenuBarController.makeStatusTitle(state: .refining), "🫡 🔵")
    }

    func testMenuIncludesQuitAction() {
        let target = NSObject()
        let stateItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        let menu = MenuBarController.makeMenu(stateMenuItem: stateItem, target: target)

        XCTAssertEqual(menu.items.count, 7)
        XCTAssertEqual(menu.items[6].title, "Quit")
        XCTAssertEqual(menu.items[6].keyEquivalent, "q")
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

    func testDecodeTranscribeResponseShape() throws {
        let json = """
        {
          "raw_transcript": "hello world",
          "segments": [
            { "start_ms": 0, "end_ms": 1000, "text": "hello world" }
          ],
          "confidence": 0.8,
          "duration_ms": 1000
        }
        """.data(using: .utf8)!

        let decoded = try APIClient.decodeTranscribeResponse(from: json)
        XCTAssertEqual(decoded.raw_transcript, "hello world")
        XCTAssertEqual(decoded.segments.count, 1)
    }

    func testActiveTargetHostExtractionStripsWWWPrefix() {
        XCTAssertEqual(ActiveTargetContextProvider.host(from: "https://www.google.com/search?q=test"), "google.com")
        XCTAssertEqual(ActiveTargetContextProvider.host(from: "https://docs.github.com/en"), "docs.github.com")
        XCTAssertNil(ActiveTargetContextProvider.host(from: "not-a-url"))
    }

    func testCodingAgentDetectionByStringContainment() {
        XCTAssertTrue(ActiveTargetContextProvider.isCodingAgent(appName: "Codex", bundleID: "com.example.codex"))
        XCTAssertTrue(ActiveTargetContextProvider.isCodingAgent(appName: "Cursor", bundleID: "com.todesktop.230313mzl4w4u92"))
        XCTAssertFalse(ActiveTargetContextProvider.isCodingAgent(appName: "Slack", bundleID: "com.tinyspeck.slackmacgap"))
    }

    func testDictationContextSentenceIncludesCodingAgentHint() {
        let codingAgentText = ActiveTargetContextProvider.dictationContextSentence(
            appName: "Codex",
            siteHost: nil,
            isCodingAgent: true
        )
        XCTAssertEqual(codingAgentText, "You are currently dictating into Codex. You are talking to a coding agent.")

        let browserText = ActiveTargetContextProvider.dictationContextSentence(
            appName: "Google Chrome",
            siteHost: "google.com",
            isCodingAgent: false
        )
        XCTAssertEqual(browserText, "You are currently dictating into Google Chrome, website google.com.")
    }

    func testClipboardNormalizedSelectedText() {
        XCTAssertNil(ClipboardInserter.normalizedSelectedText(nil))
        XCTAssertNil(ClipboardInserter.normalizedSelectedText("   \n"))
        XCTAssertEqual(ClipboardInserter.normalizedSelectedText("  hello world  "), "hello world")
    }

    func testClipboardNormalizedSelectedTextTruncatesLargePayload() {
        let raw = String(repeating: "a", count: 13000)
        let normalized = ClipboardInserter.normalizedSelectedText(raw)
        XCTAssertEqual(normalized?.count, 12000)
    }

    func testExtractSelectedTextIgnoresClipboardWhenChangeCountDidNotAdvance() {
        let selected = ClipboardInserter.extractSelectedText(
            priorChangeCount: 10,
            currentChangeCount: 10,
            rawClipboardValue: "existing clipboard content"
        )
        XCTAssertNil(selected)
    }

    func testExtractSelectedTextAcceptsFreshClipboardCopy() {
        let selected = ClipboardInserter.extractSelectedText(
            priorChangeCount: 10,
            currentChangeCount: 11,
            rawClipboardValue: "  selected text  "
        )
        XCTAssertEqual(selected, "selected text")
    }

    func testExtractSelectedTextRejectsWhitespaceWhenChangeCountAdvances() {
        let selected = ClipboardInserter.extractSelectedText(
            priorChangeCount: 4,
            currentChangeCount: 5,
            rawClipboardValue: " \n\t "
        )
        XCTAssertNil(selected)
    }

    func testFocusedInputRoleDetection() {
        XCTAssertTrue(FocusedInputDetector.isTextInputRole(role: kAXTextFieldRole as String, editableAttribute: nil))
        XCTAssertTrue(FocusedInputDetector.isTextInputRole(role: "AXUnknown", editableAttribute: true))
        XCTAssertFalse(FocusedInputDetector.isTextInputRole(role: kAXButtonRole as String, editableAttribute: nil))
    }
}
