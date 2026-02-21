import AppKit
import XCTest
@testable import DictatorApp

final class SmokeTests: XCTestCase {
    func testStatusTitleIsSaluteEmoji() {
        XCTAssertEqual(MenuBarController.statusTitle, "🫡")
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
