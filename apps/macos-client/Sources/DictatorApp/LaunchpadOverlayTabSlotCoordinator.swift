import Foundation

final class LaunchpadOverlayTabSlotCoordinator {
    private let invalidationBus: RenderInvalidationBus
    private let pageController: LaunchpadPageController
    private let slotID: String
    private let tabCount: Int
    private let onSelectTab: (Int) -> Void
    private let activeTabColor: PadColor
    private let selectedTabColor: PadColor
    private var activeLayer: LaunchpadOverlayTabButtonLayer?

    init(
        invalidationBus: RenderInvalidationBus,
        pageController: LaunchpadPageController,
        slotID: String = "overlay.tabs",
        tabCount: Int,
        onSelectTab: @escaping (Int) -> Void,
        activeTabColor: PadColor = PadColor(r: 0, g: 80, b: 200),
        selectedTabColor: PadColor = PadColor(r: 0, g: 220, b: 255)
    ) {
        self.invalidationBus = invalidationBus
        self.pageController = pageController
        self.slotID = slotID
        self.tabCount = tabCount
        self.onSelectTab = onSelectTab
        self.activeTabColor = activeTabColor
        self.selectedTabColor = selectedTabColor
    }

    func sync(with overlayState: LaunchpadOverlayState) {
        if overlayState.isVisible {
            ensureActiveLayer()
            activeLayer?.setSelectedTabIndex(overlayState.selectedTabIndex)
            return
        }

        deactivateLayer()
    }

    private func ensureActiveLayer() {
        if activeLayer == nil {
            let layer = LaunchpadOverlayTabButtonLayer(
                invalidationBus: invalidationBus,
                tabCount: tabCount,
                onSelectTab: onSelectTab,
                activeTabColor: activeTabColor,
                selectedTabColor: selectedTabColor
            )
            activeLayer = layer
            pageController.setControlLayer(layer, forSlot: slotID)
        }
    }

    private func deactivateLayer() {
        guard activeLayer != nil else {
            return
        }
        activeLayer = nil
        pageController.removeControlLayer(forSlot: slotID)
    }
}
