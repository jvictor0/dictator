import AppKit
import XCTest
@testable import DictatorApp

final class SmokeTests: XCTestCase {
    func testStatusTitleIsSaluteEmoji() {
        XCTAssertEqual(MenuBarController.statusTitle, "🫡")
    }

    func testMenuIncludesQuitAction() {
        let target = NSObject()
        let menu = MenuBarController.makeMenu(target: target)

        XCTAssertEqual(menu.items.count, 1)
        XCTAssertEqual(menu.items[0].title, "Quit")
        XCTAssertEqual(menu.items[0].keyEquivalent, "q")
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
