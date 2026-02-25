import XCTest
import DictatorCore
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

    func testLayoutDecodeAcceptsToggleFullscreenOverlayAction() throws {
        let json = """
        {
          "pages": [
            {
              "id": "control",
              "pads": [
                {
                  "x": 7,
                  "y": 8,
                  "color": { "r": 40, "g": 140, "b": 255 },
                  "action": { "type": "toggle_fullscreen_overlay" }
                }
              ]
            }
          ]
        }
        """.data(using: .utf8)!

        XCTAssertNoThrow(try LaunchpadLayoutLoader.decode(json))
    }

    func testLayoutDecodeAcceptsTalonLiteDictationAction() throws {
        let json = """
        {
          "pages": [
            {
              "id": "control",
              "pads": [
                {
                  "x": 1,
                  "y": 7,
                  "color": { "r": 255, "g": 170, "b": 0 },
                  "action": { "type": "talon_lite_dictation", "command": "toggle" }
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

    func testRenderWorkerSendsOffWhenExtendedCoordinateRemoved() {
        let bus = RenderInvalidationBus()
        let provider = VariableCoordinateColorProvider()
        let transport = FakeTransport()
        let worker = LaunchpadColorRenderWorker(invalidationBus: bus, colorProvider: provider, transport: transport)

        let coordinate = PadCoordinate(x: 1, y: 9)
        provider.coordinates = [coordinate]
        provider.colors[coordinate] = PadColor(r: 5, g: 15, b: 25)
        worker.renderNowForTesting(forceAll: false)
        XCTAssertEqual(transport.batches.count, 1)
        XCTAssertEqual(transport.batches[0], [PadColorUpdate(coordinate: coordinate, color: PadColor(r: 5, g: 15, b: 25))])

        provider.coordinates = []
        provider.colors.removeValue(forKey: coordinate)
        worker.renderNowForTesting(forceAll: false)
        XCTAssertEqual(transport.batches.count, 2)
        XCTAssertEqual(transport.batches[1], [PadColorUpdate(coordinate: coordinate, color: .off)])
    }

    func testKeyboardKeyDecodesSpace() throws {
        let json = "\"space\"".data(using: .utf8)!
        let decoded = try JSONDecoder().decode(KeyboardKey.self, from: json)
        XCTAssertEqual(decoded, .space)
    }

    func testSingleColorSysExUpdateExpandsToAllAddressableCoordinates() {
        var cached: [PadCoordinate: PadColor] = [:]
        let target = PadCoordinate(x: 2, y: 3)
        let targetColor = PadColor(r: 17, g: 33, b: 49)
        let incoming = [PadColorUpdate(coordinate: target, color: targetColor)]

        let expanded = LaunchpadMIDIManager.makeSysExUpdates(from: incoming, cachedColors: &cached)

        XCTAssertEqual(expanded.count, LaunchpadMIDIManager.allAddressableCoordinates.count)
        XCTAssertTrue(expanded.contains(PadColorUpdate(coordinate: target, color: targetColor)))
        XCTAssertTrue(expanded.contains(PadColorUpdate(coordinate: PadCoordinate(x: 0, y: 0), color: .off)))
    }

    func testMultiColorSysExUpdateStaysDelta() {
        var cached: [PadCoordinate: PadColor] = [:]
        let incoming = [
            PadColorUpdate(coordinate: PadCoordinate(x: 0, y: 0), color: PadColor(r: 1, g: 2, b: 3)),
            PadColorUpdate(coordinate: PadCoordinate(x: 1, y: 1), color: PadColor(r: 4, g: 5, b: 6))
        ]

        let result = LaunchpadMIDIManager.makeSysExUpdates(from: incoming, cachedColors: &cached)
        XCTAssertEqual(result, incoming)
    }

    func testPageFactoryDispatchesToggleFullscreenOverlayAction() throws {
        let bus = RenderInvalidationBus()
        let json = """
        {
          "initial_page_id": "control",
          "pages": [
            {
              "id": "control",
              "pads": [
                {
                  "x": 7,
                  "y": 8,
                  "color": { "r": 40, "g": 140, "b": 255 },
                  "action": { "type": "toggle_fullscreen_overlay" }
                }
              ]
            }
          ]
        }
        """.data(using: .utf8)!
        let config = try LaunchpadLayoutLoader.decode(json)

        var toggleCount = 0
        let factory = LaunchpadPageFactory(
            invalidationBus: bus,
            onKeystroke: nil,
            onDictationCommand: nil,
            onTalonLiteDictationCommand: nil,
            onContextualBackspace: nil,
            onAppReload: nil,
            onLoadSafeRuntimeConfig: nil,
            onToggleFullscreenOverlay: {
                toggleCount += 1
            },
            recordStatusColorProvider: { .off },
            shiftLatchColorProvider: { .off },
            onModifierPress: nil,
            onModifierRelease: nil
        )
        let pages = factory.makePages(from: config)
        let pageController = LaunchpadPageController(invalidationBus: bus)
        pageController.setPages(pages, initialPageID: config.initialPageID)

        pageController.handle(PadEvent(coordinate: PadCoordinate(x: 7, y: 8), phase: .press, velocity: 100))
        XCTAssertEqual(toggleCount, 1)
    }

    func testPageFactoryDispatchesTalonLiteDictationAction() throws {
        let bus = RenderInvalidationBus()
        let json = """
        {
          "initial_page_id": "control",
          "pages": [
            {
              "id": "control",
              "pads": [
                {
                  "x": 1,
                  "y": 7,
                  "color": { "r": 255, "g": 170, "b": 0 },
                  "action": { "type": "talon_lite_dictation", "command": "toggle" }
                }
              ]
            }
          ]
        }
        """.data(using: .utf8)!
        let config = try LaunchpadLayoutLoader.decode(json)

        var commands: [LaunchpadActionConfig.DictationCommand] = []
        let factory = LaunchpadPageFactory(
            invalidationBus: bus,
            onKeystroke: nil,
            onDictationCommand: nil,
            onTalonLiteDictationCommand: { commands.append($0) },
            onContextualBackspace: nil,
            onAppReload: nil,
            onLoadSafeRuntimeConfig: nil,
            onToggleFullscreenOverlay: nil,
            recordStatusColorProvider: { .off },
            shiftLatchColorProvider: { .off },
            onModifierPress: nil,
            onModifierRelease: nil
        )
        let pages = factory.makePages(from: config)
        let pageController = LaunchpadPageController(invalidationBus: bus)
        pageController.setPages(pages, initialPageID: config.initialPageID)

        pageController.handle(PadEvent(coordinate: PadCoordinate(x: 1, y: 7), phase: .press, velocity: 100))
        XCTAssertEqual(commands, [.toggle])
    }

    func testPageControllerControlLayerSlotAddRemove() {
        let bus = RenderInvalidationBus()
        let pageController = LaunchpadPageController(invalidationBus: bus)
        let layer = FakeControlLayer()

        pageController.setControlLayer(layer, forSlot: "overlay.tabs")
        XCTAssertEqual(pageController.activeControlLayerSlotIDs(), ["overlay.tabs"])
        XCTAssertEqual(pageController.getColor(at: PadCoordinate(x: 1, y: 9)), layer.color)

        pageController.handle(PadEvent(coordinate: PadCoordinate(x: 1, y: 9), phase: .press, velocity: 100))
        XCTAssertEqual(layer.handleCount, 1)

        pageController.removeControlLayer(forSlot: "overlay.tabs")
        XCTAssertTrue(pageController.activeControlLayerSlotIDs().isEmpty)
        XCTAssertEqual(pageController.getColor(at: PadCoordinate(x: 1, y: 9)), .off)

        pageController.handle(PadEvent(coordinate: PadCoordinate(x: 1, y: 9), phase: .press, velocity: 100))
        XCTAssertEqual(layer.handleCount, 1)
    }

    func testOverlayTabSlotCoordinatorInstallsAndRemovesSlotLayerByVisibility() {
        let bus = RenderInvalidationBus()
        let pageController = LaunchpadPageController(invalidationBus: bus)
        var selectedIndices: [Int] = []
        let coordinator = LaunchpadOverlayTabSlotCoordinator(
            invalidationBus: bus,
            pageController: pageController,
            tabCount: 3,
            onSelectTab: { index in
                selectedIndices.append(index)
            }
        )

        coordinator.sync(with: LaunchpadOverlayState(isVisible: false, selectedTabIndex: 0))
        XCTAssertTrue(pageController.activeControlLayerSlotIDs().isEmpty)

        coordinator.sync(with: LaunchpadOverlayState(isVisible: true, selectedTabIndex: 1))
        XCTAssertEqual(pageController.activeControlLayerSlotIDs(), ["overlay.tabs"])
        XCTAssertEqual(pageController.getColor(at: PadCoordinate(x: 1, y: 9)), PadColor(r: 0, g: 220, b: 255))

        pageController.handle(PadEvent(coordinate: PadCoordinate(x: 2, y: 9), phase: .press, velocity: 100))
        XCTAssertEqual(selectedIndices, [2])

        coordinator.sync(with: LaunchpadOverlayState(isVisible: false, selectedTabIndex: 0))
        XCTAssertTrue(pageController.activeControlLayerSlotIDs().isEmpty)
        XCTAssertEqual(pageController.getColor(at: PadCoordinate(x: 1, y: 9)), .off)
    }

    func testOverlayTabButtonLayerSupportsCoordinateReassignment() {
        let bus = RenderInvalidationBus()
        var selectedIndices: [Int] = []
        let layer = LaunchpadOverlayTabButtonLayer(
            invalidationBus: bus,
            tabCount: 2,
            onSelectTab: { selectedIndices.append($0) }
        )

        layer.assignCoordinates { tabIndex in
            PadCoordinate(x: 7, y: tabIndex)
        }

        XCTAssertEqual(Set(layer.allCoordinatesForRendering()), Set([PadCoordinate(x: 7, y: 0), PadCoordinate(x: 7, y: 1)]))
        XCTAssertTrue(layer.handle(PadEvent(coordinate: PadCoordinate(x: 7, y: 1), phase: .press, velocity: 100)))
        XCTAssertEqual(selectedIndices, [1])
    }

    @MainActor
    func testOverlayControllerRoutesArrowKeysToVisibleTab() async {
        let tab = FakeOverlayTab(id: "config", title: "config")
        let controller = LaunchpadFullscreenOverlayController(tabs: [tab])

        let hiddenHandled = await controller.handleOverlayKey(.up)
        XCTAssertFalse(hiddenHandled)
        XCTAssertTrue(tab.handledKeys.isEmpty)

        controller.show()
        let visibleHandled = await controller.handleOverlayKey(.right)
        XCTAssertTrue(visibleHandled)
        XCTAssertEqual(tab.handledKeys, [.right])
        controller.hide()
    }

    @MainActor
    func testOverlayControllerRestoresLastSelectedTabWhenReopened() async {
        let suiteName = "test.overlay.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let firstTab = FakeOverlayTab(id: "config", title: "config")
        let secondTab = FakeOverlayTab(id: "system-prompts", title: "system-prompts")
        let controller = LaunchpadFullscreenOverlayController(
            tabs: [firstTab, secondTab],
            userDefaults: defaults,
            selectedTabDefaultsKey: "test.overlay.selected"
        )

        controller.show()
        XCTAssertTrue(controller.selectTab(index: 1, showIfHidden: false))
        controller.hide()
        controller.show()

        let handled = await controller.handleOverlayKey(.right)
        XCTAssertTrue(handled)
        XCTAssertTrue(firstTab.handledKeys.isEmpty)
        XCTAssertEqual(secondTab.handledKeys, [.right])
        XCTAssertEqual(secondTab.makeContentViewCount, 2)
    }

    @MainActor
    func testOverlayControllerTemporarilyHidesDockWhileVisible() async {
        let tab = FakeOverlayTab(id: "config", title: "config")
        let controller = LaunchpadFullscreenOverlayController(tabs: [tab])
        let previous = NSApp.presentationOptions

        controller.show()
        XCTAssertTrue(NSApp.presentationOptions.contains(.hideDock))

        controller.hide()
        XCTAssertEqual(NSApp.presentationOptions, previous)
    }

    @MainActor
    func testConfigOverlayTabUsesArrowKeysForSelectionAndOptionCycling() async throws {
        var snapshots: [RuntimeConfigurationSnapshot] = [
            .init(
                name: "Cloud Model",
                currentValue: .string("qwen2.5:7b-instruct"),
                defaultValue: .string("qwen2.5:7b-instruct"),
                options: [.string("qwen2.5:7b-instruct"), .string("llama3.2")]
            ),
            .init(
                name: "Use Cloud",
                currentValue: .bool(false),
                defaultValue: .bool(false),
                options: [.bool(false), .bool(true)]
            )
        ]
        var setCalls: [(String, RuntimeConfigurationValue)] = []
        var getOptionsCalls = 0

        let tab = LaunchpadConfigOverlayTab(
            listConfigs: { snapshots },
            getOptionsForConfig: { name in
                getOptionsCalls += 1
                return snapshots.first(where: { $0.name == name })?.options ?? []
            },
            setConfig: { name, value in
                setCalls.append((name, value))
                guard let index = snapshots.firstIndex(where: { $0.name == name }) else {
                    return
                }
                snapshots[index] = .init(
                    name: snapshots[index].name,
                    currentValue: value,
                    defaultValue: snapshots[index].defaultValue,
                    options: snapshots[index].options
                )
            }
        )

        _ = tab.makeContentView()
        try await Task.sleep(nanoseconds: 40_000_000)

        let handledRightForModel = await tab.handleOverlayKey(.right)
        XCTAssertTrue(handledRightForModel)
        XCTAssertEqual(setCalls.first?.0, "Cloud Model")
        XCTAssertEqual(setCalls.first?.1, .string("llama3.2"))
        XCTAssertEqual(getOptionsCalls, 1)

        _ = await tab.handleOverlayKey(.right)
        XCTAssertEqual(getOptionsCalls, 1)

        _ = await tab.handleOverlayKey(.down)
        let handledRightForBool = await tab.handleOverlayKey(.right)
        XCTAssertTrue(handledRightForBool)
        XCTAssertEqual(setCalls.last?.0, "Use Cloud")
        XCTAssertEqual(setCalls.last?.1, .bool(true))
        XCTAssertEqual(getOptionsCalls, 2)

        tab.overlayDidClose()
        _ = tab.makeContentView()
        try await Task.sleep(nanoseconds: 40_000_000)
        _ = await tab.handleOverlayKey(.right)
        XCTAssertEqual(getOptionsCalls, 3)
    }

    @MainActor
    func testSystemPromptsTabSelectsFileOnlyOnEnter() async throws {
        var selectedPromptPath = "alpha/one.md"
        var setCalls: [String] = []

        let tab = LaunchpadSystemPromptsOverlayTab(
            listDirectoryEntries: { directory in
                switch directory {
                case "":
                    return [
                        .init(name: "alpha", relativePath: "alpha", isDirectory: true),
                        .init(name: "root.md", relativePath: "root.md", isDirectory: false)
                    ]
                case "alpha":
                    return [
                        .init(name: "one.md", relativePath: "alpha/one.md", isDirectory: false),
                        .init(name: "two.md", relativePath: "alpha/two.md", isDirectory: false)
                    ]
                default:
                    return []
                }
            },
            loadPromptBody: { path in "body-\(path)" },
            getSelectedPromptPath: { selectedPromptPath },
            setSelectedPromptPath: { path in
                setCalls.append(path)
                selectedPromptPath = path
            }
        )

        _ = tab.makeContentView()
        try await Task.sleep(nanoseconds: 80_000_000)

        _ = await tab.handleOverlayKey(.down)
        XCTAssertTrue(setCalls.isEmpty)

        _ = await tab.handleOverlayKey(.enter)
        XCTAssertEqual(setCalls, ["alpha/two.md"])
    }

    @MainActor
    func testSystemPromptsTabRightArrowExpandsDirectoryTree() async throws {
        var queriedDirectories: [String] = []

        let tab = LaunchpadSystemPromptsOverlayTab(
            listDirectoryEntries: { directory in
                queriedDirectories.append(directory)
                switch directory {
                case "":
                    return [
                        .init(name: "alpha", relativePath: "alpha", isDirectory: true)
                    ]
                case "alpha":
                    return [
                        .init(name: "child.md", relativePath: "alpha/child.md", isDirectory: false)
                    ]
                default:
                    return []
                }
            },
            loadPromptBody: { _ in "body" },
            getSelectedPromptPath: { "root.md" },
            setSelectedPromptPath: { _ in }
        )

        _ = tab.makeContentView()
        try await Task.sleep(nanoseconds: 80_000_000)
        XCTAssertTrue(queriedDirectories.contains(""))
        XCTAssertFalse(queriedDirectories.contains("alpha"))

        _ = await tab.handleOverlayKey(.right)
        XCTAssertTrue(queriedDirectories.contains("alpha"))
    }

    @MainActor
    func testInteractionsTabDefaultsToLatestAndSupportsUpDownSelection() async {
        let oldest = makeInteraction(finalOutput: "first")
        let middle = makeInteraction(finalOutput: "second")
        let newest = makeInteraction(finalOutput: "third")

        let tab = LaunchpadInteractionsOverlayTab(
            loadInteractions: { [oldest, middle, newest] }
        )

        _ = tab.makeContentView()
        XCTAssertEqual(tab.interactionsCountForTesting(), 3)
        XCTAssertEqual(tab.selectedInteractionIDForTesting(), newest.id)

        _ = await tab.handleOverlayKey(.up)
        XCTAssertEqual(tab.selectedInteractionIDForTesting(), middle.id)

        _ = await tab.handleOverlayKey(.up)
        XCTAssertEqual(tab.selectedInteractionIDForTesting(), oldest.id)

        _ = await tab.handleOverlayKey(.down)
        XCTAssertEqual(tab.selectedInteractionIDForTesting(), middle.id)
    }

    @MainActor
    func testInteractionsTabSupportsPanelFocusAndSectionToggleControls() async {
        let oldest = makeInteraction(finalOutput: "first")
        let newest = makeInteraction(finalOutput: "second")
        let tab = LaunchpadInteractionsOverlayTab(
            loadInteractions: { [oldest, newest] }
        )

        _ = tab.makeContentView()
        XCTAssertEqual(tab.panelFocusForTesting(), "left")
        XCTAssertEqual(tab.selectedInteractionIDForTesting(), newest.id)

        _ = await tab.handleOverlayKey(.right)
        XCTAssertEqual(tab.panelFocusForTesting(), "right")
        XCTAssertEqual(tab.selectedSectionTitleForTesting(), "Metadata")

        _ = await tab.handleOverlayKey(.down)
        XCTAssertEqual(tab.selectedSectionTitleForTesting(), "Timings")

        let beforeToggle = tab.selectedSectionExpandedForTesting()
        _ = await tab.handleOverlayKey(.right)
        let afterToggle = tab.selectedSectionExpandedForTesting()
        XCTAssertNotEqual(beforeToggle, afterToggle)

        _ = await tab.handleOverlayKey(.left)
        XCTAssertEqual(tab.panelFocusForTesting(), "left")
    }

    func testInteractionBufferEvictsOldestWhenTrackedBytesExceedLimit() {
        let buffer = DictationInteractionBuffer(maxBytes: 20)
        let first = makeInteraction(whisperOutput: "aaaaaa", finalOutput: "bbbbbb")
        let second = makeInteraction(whisperOutput: "cccccc", finalOutput: "dddddd")

        buffer.append(first)
        buffer.append(second)

        let kept = buffer.snapshot()
        XCTAssertEqual(kept.map(\.id), [second.id])
        XCTAssertEqual(buffer.currentTrackedBytes(), second.trackedSizeBytes)
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

private final class VariableCoordinateColorProvider: ColorProvider {
    var coordinates: [PadCoordinate] = []
    var colors: [PadCoordinate: PadColor] = [:]

    func getColor(at coordinate: PadCoordinate) -> PadColor {
        colors[coordinate] ?? .off
    }

    func allCoordinatesForRendering() -> [PadCoordinate] {
        coordinates
    }
}

private final class FakeControlLayer: LaunchpadControlLayer {
    let color = PadColor(r: 10, g: 20, b: 30)
    var handleCount = 0

    func handle(_ event: PadEvent) -> Bool {
        if event.coordinate == PadCoordinate(x: 1, y: 9) {
            handleCount += 1
            return true
        }
        return false
    }

    func getColor(at coordinate: PadCoordinate) -> PadColor? {
        coordinate == PadCoordinate(x: 1, y: 9) ? color : nil
    }

    func allCoordinatesForRendering() -> [PadCoordinate] {
        [PadCoordinate(x: 1, y: 9)]
    }
}

@MainActor
private final class FakeOverlayTab: LaunchpadOverlayTab {
    let id: String
    let title: String
    var handledKeys: [KeyboardKey] = []
    var makeContentViewCount = 0

    init(id: String, title: String) {
        self.id = id
        self.title = title
    }

    func makeContentView() -> NSView {
        makeContentViewCount += 1
        return NSView()
    }

    func handleOverlayKey(_ key: KeyboardKey) async -> Bool {
        handledKeys.append(key)
        return true
    }
}

private func makeInteraction(
    whisperOutput: String = "raw",
    finalOutput: String = "final"
) -> DictationInteraction {
    DictationInteraction(
        whisperOutput: whisperOutput,
        finalOutput: finalOutput,
        mode: .revision,
        systemPromptPath: "intent_refiner_v1.md",
        systemPromptBody: "prompt-body",
        model: "qwen2.5:7b-instruct",
        provider: "ollama",
        optionalContext: [:],
        editSummary: "summary",
        uncertaintyFlags: [],
        timings: DictationInteractionTimings(
            transcribeMs: 1,
            refineMs: 2,
            insertMs: 3,
            totalPipelineMs: 6
        )
    )
}
