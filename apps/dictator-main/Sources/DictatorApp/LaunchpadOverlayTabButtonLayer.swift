import Foundation

final class LaunchpadOverlayTabButtonLayer: LaunchpadControlLayer {
    private final class SelectionState {
        private let lock = NSLock()
        private var selectedTabIndex = 0

        func get() -> Int {
            lock.lock()
            let value = selectedTabIndex
            lock.unlock()
            return value
        }

        func set(_ newValue: Int) -> Bool {
            lock.lock()
            let changed = selectedTabIndex != newValue
            selectedTabIndex = newValue
            lock.unlock()
            return changed
        }
    }

    private final class TabSelectorCell: LaunchpadCellType {
        private let tabIndex: Int
        private let onSelectTab: (Int) -> Void
        private let colorProvider: (Int) -> PadColor

        init(
            tabIndex: Int,
            onSelectTab: @escaping (Int) -> Void,
            colorProvider: @escaping (Int) -> PadColor
        ) {
            self.tabIndex = tabIndex
            self.onSelectTab = onSelectTab
            self.colorProvider = colorProvider
        }

        func onPress(velocity: UInt8) {
            onSelectTab(tabIndex)
            _ = velocity
        }

        func onRelease() {}

        func getColor() -> PadColor {
            colorProvider(tabIndex)
        }
    }

    private let invalidationBus: RenderInvalidationBus
    private var coordinateForTabIndex: (Int) -> PadCoordinate
    private let selectionState: SelectionState
    private let lock = NSLock()
    private let tabButtonCells: [Int: TabSelectorCell]
    private var cellsByCoordinate: [PadCoordinate: TabSelectorCell] = [:]

    init(
        invalidationBus: RenderInvalidationBus,
        tabCount: Int,
        onSelectTab: @escaping (Int) -> Void,
        coordinateForTabIndex: @escaping (Int) -> PadCoordinate = { index in
            PadCoordinate(x: index, y: 9)
        },
        activeTabColor: PadColor = PadColor(r: 0, g: 80, b: 200),
        selectedTabColor: PadColor = PadColor(r: 0, g: 220, b: 255)
    ) {
        self.invalidationBus = invalidationBus
        self.coordinateForTabIndex = coordinateForTabIndex
        let selectionState = SelectionState()
        self.selectionState = selectionState

        var tabButtonCells: [Int: TabSelectorCell] = [:]
        for tabIndex in 0..<tabCount {
            tabButtonCells[tabIndex] = TabSelectorCell(
                tabIndex: tabIndex,
                onSelectTab: onSelectTab,
                colorProvider: { currentTabIndex in
                    currentTabIndex == selectionState.get() ? selectedTabColor : activeTabColor
                }
            )
        }
        self.tabButtonCells = tabButtonCells
        rebuildCoordinateMap()
    }

    func setSelectedTabIndex(_ selectedTabIndex: Int) {
        let changed = selectionState.set(selectedTabIndex)
        if changed {
            invalidationBus.markDirty(reason: "overlay_tab_selection")
        }
    }

    func assignCoordinates(_ coordinateForTabIndex: @escaping (Int) -> PadCoordinate) {
        lock.lock()
        self.coordinateForTabIndex = coordinateForTabIndex
        lock.unlock()
        rebuildCoordinateMap()
        invalidationBus.markDirty(reason: "overlay_tab_coordinate_assignment")
    }

    func handle(_ event: PadEvent) -> Bool {
        guard let cell = cell(at: event.coordinate) else {
            return false
        }
        switch event.phase {
        case .press:
            cell.onPress(velocity: event.velocity)
        case .release:
            cell.onRelease()
        }
        return true
    }

    func getColor(at coordinate: PadCoordinate) -> PadColor? {
        cell(at: coordinate)?.getColor()
    }

    func allCoordinatesForRendering() -> [PadCoordinate] {
        lock.lock()
        let coordinates = Array(cellsByCoordinate.keys)
        lock.unlock()
        return coordinates
    }

    private func rebuildCoordinateMap() {
        lock.lock()
        var newMap: [PadCoordinate: TabSelectorCell] = [:]
        for (tabIndex, cell) in tabButtonCells {
            newMap[coordinateForTabIndex(tabIndex)] = cell
        }
        cellsByCoordinate = newMap
        lock.unlock()
    }

    private func cell(at coordinate: PadCoordinate) -> TabSelectorCell? {
        lock.lock()
        let cell = cellsByCoordinate[coordinate]
        lock.unlock()
        return cell
    }
}
