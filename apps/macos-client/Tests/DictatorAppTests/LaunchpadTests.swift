import XCTest
@testable import DictatorApp

final class LaunchpadTests: XCTestCase {
    func testLaunchpadNoteCoordinateMappingRoundTrip() {
        let samples = [
            PadCoordinate(x: 0, y: 0),
            PadCoordinate(x: 7, y: 0),
            PadCoordinate(x: 0, y: 7),
            PadCoordinate(x: 7, y: 7),
            PadCoordinate(x: 3, y: 4),
            PadCoordinate(x: -1, y: 7)
        ]

        for coordinate in samples {
            let note = LaunchpadMIDIManager.coordinateToNote(coordinate)
            XCTAssertNotNil(note)
            XCTAssertEqual(LaunchpadMIDIManager.noteToCoordinate(note!), coordinate)
        }
    }

    func testLaunchpadCellUsesDimWhenIdleAndBrightWhenPressed() {
        let bus = RenderInvalidationBus()
        let cell = LaunchpadCell(baseColor: PadColor(r: 200, g: 100, b: 40), invalidationBus: bus)
        let page = LaunchpadPage(id: "test")
        let coordinate = PadCoordinate(x: 1, y: 2)

        page.setCell(cell, at: coordinate)

        XCTAssertEqual(page.getColor(at: coordinate), PadColor(r: 50, g: 25, b: 10))
        page.handle(PadEvent(coordinate: coordinate, phase: .press, velocity: 127))
        XCTAssertEqual(page.getColor(at: coordinate), PadColor(r: 200, g: 100, b: 40))
        page.handle(PadEvent(coordinate: coordinate, phase: .release, velocity: 0))
        XCTAssertEqual(page.getColor(at: coordinate), PadColor(r: 50, g: 25, b: 10))
    }

    func testRenderInvalidationBusWakesOnDirtySignal() {
        let bus = RenderInvalidationBus()
        let exp = expectation(description: "dirty")

        DispatchQueue.global().asyncAfter(deadline: .now() + 0.05) {
            bus.markDirty(reason: "test")
            exp.fulfill()
        }

        let generation = bus.waitForDirty(since: 0, timeout: 0.5)
        wait(for: [exp], timeout: 1)
        XCTAssertGreaterThan(generation, 0)
    }

    func testLayoutDecodeValidatesKeystrokeAction() throws {
        let json = """
        {
          "initial_page_id": "arrows",
          "pages": [
            {
              "id": "arrows",
              "pads": [
                {
                  "x": 1,
                  "y": 1,
                  "color": { "r": 1, "g": 2, "b": 3 },
                  "action": { "type": "keystroke", "key": "up" }
                }
              ]
            }
          ]
        }
        """.data(using: .utf8)!

        XCTAssertNoThrow(try LaunchpadLayoutLoader.decode(json))
    }

    func testLayoutDecodeAcceptsAppReloadAction() throws {
        let json = """
        {
          "pages": [
            {
              "id": "control",
              "pads": [
                {
                  "x": -1,
                  "y": 7,
                  "color": { "r": 255, "g": 0, "b": 255 },
                  "action": { "type": "app_reload" }
                }
              ]
            }
          ]
        }
        """.data(using: .utf8)!

        XCTAssertNoThrow(try LaunchpadLayoutLoader.decode(json))
    }

    func testLayoutDecodeAcceptsShiftModifierLatchAction() throws {
        let json = """
        {
          "pages": [
            {
              "id": "control",
              "pads": [
                {
                  "x": 5,
                  "y": 6,
                  "role": "shift_latch",
                  "color": { "r": 255, "g": 220, "b": 0 },
                  "action": { "type": "modifier_latch", "modifier": "shift" }
                }
              ]
            }
          ]
        }
        """.data(using: .utf8)!

        XCTAssertNoThrow(try LaunchpadLayoutLoader.decode(json))
    }

    func testLayoutDecodeRejectsMissingKeystrokeKey() {
        let json = """
        {
          "pages": [
            {
              "id": "arrows",
              "pads": [
                {
                  "x": 1,
                  "y": 1,
                  "color": { "r": 1, "g": 2, "b": 3 },
                  "action": { "type": "keystroke" }
                }
              ]
            }
          ]
        }
        """.data(using: .utf8)!

        XCTAssertThrowsError(try LaunchpadLayoutLoader.decode(json))
    }

    func testRenderWorkerSendsOnlyDiffsAfterInitialFrame() {
        let bus = RenderInvalidationBus()
        let provider = FakeColorProvider()
        let transport = FakeTransport()

        let coordinate = PadCoordinate(x: 2, y: 3)
        provider.colors[coordinate] = PadColor(r: 10, g: 20, b: 30)

        let worker = LaunchpadColorRenderWorker(invalidationBus: bus, colorProvider: provider, transport: transport)
        worker.renderNowForTesting(forceAll: true)
        XCTAssertEqual(transport.batches.count, 1)
        XCTAssertEqual(transport.batches[0].count, 64)

        worker.renderNowForTesting(forceAll: false)
        XCTAssertEqual(transport.batches.count, 1)

        let newCoordinate = PadCoordinate(x: 5, y: 5)
        provider.colors[newCoordinate] = PadColor(r: 1, g: 2, b: 3)
        worker.renderNowForTesting(forceAll: false)

        XCTAssertEqual(transport.batches.count, 2)
        XCTAssertEqual(transport.batches[1].count, 1)
        XCTAssertEqual(transport.batches[1][0].coordinate, newCoordinate)
    }

    func testKeyboardKeyDecodesSpace() throws {
        let json = "\"space\"".data(using: .utf8)!
        let decoded = try JSONDecoder().decode(KeyboardKey.self, from: json)
        XCTAssertEqual(decoded, .space)
    }

    func testLaunchpadCellRepeatsWhileHeld() {
        let bus = RenderInvalidationBus()
        let exp = expectation(description: "repeats")
        exp.expectedFulfillmentCount = 2

        let lock = NSLock()
        var repeatCount = 0

        let cell = LaunchpadCell(
            baseColor: PadColor(r: 100, g: 100, b: 100),
            invalidationBus: bus,
            onRepeat: {
                lock.lock()
                repeatCount += 1
                let current = repeatCount
                lock.unlock()
                if current <= 2 {
                    exp.fulfill()
                }
            },
            repeatBehavior: LaunchpadCell.RepeatBehavior(initialDelay: 0.02, repeatInterval: 0.02)
        )

        cell.onPress(velocity: 127)
        wait(for: [exp], timeout: 0.3)
        cell.onRelease()

        let countAfterRelease: Int = {
            lock.lock()
            defer { lock.unlock() }
            return repeatCount
        }()

        usleep(80_000)

        let finalCount: Int = {
            lock.lock()
            defer { lock.unlock() }
            return repeatCount
        }()
        XCTAssertEqual(finalCount, countAfterRelease)
    }
}

private final class FakeColorProvider: ColorProvider {
    var colors: [PadCoordinate: PadColor] = [:]

    func getColor(at coordinate: PadCoordinate) -> PadColor {
        colors[coordinate] ?? .off
    }
}

private final class FakeTransport: LaunchpadTransport {
    var isConnected: Bool = true
    var batches: [[PadColorUpdate]] = []

    func sendBatchPadColors(_ updates: [PadColorUpdate]) {
        batches.append(updates)
    }

    func clear() {}

    func setProgrammerModeIfNeeded() {}
}
