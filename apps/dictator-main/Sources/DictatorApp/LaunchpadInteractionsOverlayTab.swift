import AppKit

private struct InteractionDetailSection {
    let title: String
    let body: String
    let defaultExpanded: Bool
}

@MainActor
final class LaunchpadInteractionsOverlayTab: LaunchpadOverlayTab {
    private enum PanelFocus {
        case left
        case right
    }

    typealias LoadInteractions = () -> [DictationInteraction]

    let id: String
    let title: String

    private let loadInteractions: LoadInteractions
    private let contentView = LaunchpadInteractionsOverlayView()

    private var interactions: [DictationInteraction] = []
    private var selectedIndex: Int?
    private var detailSections: [InteractionDetailSection] = []
    private var selectedSectionIndex: Int?
    private var panelFocus: PanelFocus = .left

    init(
        id: String = "interactions",
        title: String = "Interactions",
        loadInteractions: @escaping LoadInteractions
    ) {
        self.id = id
        self.title = title
        self.loadInteractions = loadInteractions
    }

    func makeContentView() -> NSView {
        reloadInteractions(selectLatestOnEmptySelection: true)
        return contentView
    }

    func handleOverlayKey(_ key: KeyboardKey) async -> Bool {
        switch key {
        case .up:
            if panelFocus == .right {
                moveSectionSelection(delta: -1)
            } else {
                moveInteractionSelection(delta: -1)
            }
            return true
        case .down:
            if panelFocus == .right {
                moveSectionSelection(delta: 1)
            } else {
                moveInteractionSelection(delta: 1)
            }
            return true
        case .right:
            if panelFocus == .left {
                focusRightPanel()
            } else {
                toggleSelectedSectionExpansion()
            }
            return true
        case .left:
            if panelFocus == .right {
                focusLeftPanel()
                return true
            }
            return true
        default:
            return false
        }
    }

    func overlayDidClose() {
        interactions = []
        selectedIndex = nil
        detailSections = []
        selectedSectionIndex = nil
        panelFocus = .left
        contentView.render(interactions: [], selectedIndex: nil)
        contentView.renderSections([
            InteractionDetailSection(
                title: "Details",
                body: "No interactions captured yet.",
                defaultExpanded: true
            )
        ], selectedIndex: nil, sectionFocused: false, preserveScrollPosition: false, scrollToSelection: false)
        contentView.setStatus("Loading...")
    }

    func reloadInteractions(selectLatestOnEmptySelection: Bool = false) {
        let previousID = selectedInteraction()?.id
        interactions = loadInteractions()

        if interactions.isEmpty {
            selectedIndex = nil
            detailSections = []
            selectedSectionIndex = nil
            panelFocus = .left
            contentView.render(interactions: [], selectedIndex: nil)
            contentView.renderSections([
                InteractionDetailSection(
                    title: "Details",
                    body: "Run dictation to capture interactions",
                    defaultExpanded: true
                )
            ], selectedIndex: nil, sectionFocused: false, preserveScrollPosition: false, scrollToSelection: false)
            contentView.setStatus("Run dictation to capture interactions")
            return
        }

        if let previousID,
           let index = interactions.firstIndex(where: { $0.id == previousID }) {
            selectedIndex = index
        } else if selectLatestOnEmptySelection || selectedIndex == nil {
            selectedIndex = interactions.count - 1
        } else if let selectedIndex {
            self.selectedIndex = min(max(selectedIndex, 0), interactions.count - 1)
        }

        renderSelection()
        setStatusForCurrentFocus()
    }

    private func moveInteractionSelection(delta: Int) {
        guard let selectedIndex, !interactions.isEmpty else {
            return
        }
        let next = min(max(selectedIndex + delta, 0), interactions.count - 1)
        self.selectedIndex = next
        renderSelection()
    }

    private func selectedInteraction() -> DictationInteraction? {
        guard let selectedIndex, interactions.indices.contains(selectedIndex) else {
            return nil
        }
        return interactions[selectedIndex]
    }

    private func renderSelection() {
        contentView.render(interactions: interactions, selectedIndex: selectedIndex)
        if let selected = selectedInteraction() {
            detailSections = Self.makeSections(for: selected)
            if detailSections.isEmpty {
                selectedSectionIndex = nil
            } else {
                let existing = selectedSectionIndex ?? 0
                selectedSectionIndex = min(max(existing, 0), detailSections.count - 1)
            }
            contentView.renderSections(
                detailSections,
                selectedIndex: selectedSectionIndex,
                sectionFocused: panelFocus == .right,
                preserveScrollPosition: true,
                scrollToSelection: false
            )
        } else {
            detailSections = [
                InteractionDetailSection(title: "Details", body: "No interaction selected", defaultExpanded: true)
            ]
            selectedSectionIndex = 0
            contentView.renderSections(
                detailSections,
                selectedIndex: selectedSectionIndex,
                sectionFocused: panelFocus == .right,
                preserveScrollPosition: true,
                scrollToSelection: false
            )
        }
    }

    private func moveSectionSelection(delta: Int) {
        guard !detailSections.isEmpty else {
            return
        }
        let current = selectedSectionIndex ?? 0
        let next = min(max(current + delta, 0), detailSections.count - 1)
        selectedSectionIndex = next
        contentView.setSectionSelection(
            selectedIndex: selectedSectionIndex,
            sectionFocused: panelFocus == .right,
            shouldScrollToSelection: true
        )
    }

    private func focusRightPanel() {
        panelFocus = .right
        if selectedSectionIndex == nil, !detailSections.isEmpty {
            selectedSectionIndex = 0
        }
        contentView.setSectionSelection(selectedIndex: selectedSectionIndex, sectionFocused: true, shouldScrollToSelection: true)
        setStatusForCurrentFocus()
    }

    private func focusLeftPanel() {
        panelFocus = .left
        contentView.setSectionSelection(selectedIndex: selectedSectionIndex, sectionFocused: false, shouldScrollToSelection: false)
        setStatusForCurrentFocus()
    }

    private func toggleSelectedSectionExpansion() {
        guard let selectedSectionIndex else {
            return
        }
        contentView.toggleSection(at: selectedSectionIndex)
    }

    private func setStatusForCurrentFocus() {
        switch panelFocus {
        case .left:
            contentView.setStatus("Focus: left panel (up/down). Right switches to field list.")
        case .right:
            contentView.setStatus("Focus: right fields (up/down). Right toggles collapse. Left returns.")
        }
    }

    private static func makeSections(for interaction: DictationInteraction) -> [InteractionDetailSection] {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let occurredAt = formatter.string(from: interaction.occurredAt)

        let contextBlock: String
        if interaction.optionalContext.isEmpty {
            contextBlock = "<none>"
        } else {
            contextBlock = interaction.optionalContext
                .sorted { $0.key < $1.key }
                .map { "\($0.key): \($0.value)" }
                .joined(separator: "\n")
        }

        let uncertainty = interaction.uncertaintyFlags.isEmpty
            ? "<none>"
            : interaction.uncertaintyFlags.joined(separator: ", ")

        return [
            InteractionDetailSection(
                title: "Metadata",
                body: """
                Occurred At: \(occurredAt)
                Mode: \(interaction.mode.rawValue)
                Provider: \(interaction.provider)
                Model: \(interaction.model)
                Tracked Size (bytes): \(interaction.trackedSizeBytes)
                """,
                defaultExpanded: true
            ),
            InteractionDetailSection(
                title: "Timings",
                body: """
                transcribe_ms: \(interaction.timings.transcribeMs)
                refine_ms: \(interaction.timings.refineMs)
                insert_ms: \(interaction.timings.insertMs)
                total_pipeline_ms: \(interaction.timings.totalPipelineMs)
                """,
                defaultExpanded: true
            ),
            InteractionDetailSection(
                title: "Edit Summary",
                body: interaction.editSummary,
                defaultExpanded: true
            ),
            InteractionDetailSection(
                title: "Uncertainty Flags",
                body: uncertainty,
                defaultExpanded: true
            ),
            InteractionDetailSection(
                title: "Optional Context",
                body: contextBlock,
                defaultExpanded: false
            ),
            InteractionDetailSection(
                title: "Whisper Output",
                body: interaction.whisperOutput,
                defaultExpanded: false
            ),
            InteractionDetailSection(
                title: "Final Output",
                body: interaction.finalOutput,
                defaultExpanded: true
            ),
            InteractionDetailSection(
                title: "System Prompt Path",
                body: interaction.systemPromptPath,
                defaultExpanded: false
            ),
            InteractionDetailSection(
                title: "System Prompt Body",
                body: interaction.systemPromptBody,
                defaultExpanded: false
            )
        ]
    }

    func selectedInteractionIDForTesting() -> UUID? {
        selectedInteraction()?.id
    }

    func interactionsCountForTesting() -> Int {
        interactions.count
    }

    func panelFocusForTesting() -> String {
        panelFocus == .left ? "left" : "right"
    }

    func selectedSectionTitleForTesting() -> String? {
        guard let selectedSectionIndex, detailSections.indices.contains(selectedSectionIndex) else {
            return nil
        }
        return detailSections[selectedSectionIndex].title
    }

    func selectedSectionExpandedForTesting() -> Bool? {
        guard let selectedSectionIndex else {
            return nil
        }
        return contentView.isSectionExpanded(at: selectedSectionIndex)
    }
}

private final class LaunchpadInteractionsOverlayView: NSView, NSTableViewDataSource, NSTableViewDelegate {
    private let titleLabel = NSTextField(labelWithString: "Interactions")
    private let statusLabel = NSTextField(labelWithString: "Loading...")

    private let interactionsScrollView = NSScrollView()
    private let interactionsTableView = NSTableView()
    private var interactions: [DictationInteraction] = []

    private let detailSectionsScrollView = NSScrollView()
    private let detailSectionsStack = NSStackView()
    private var sectionExpandedByTitle: [String: Bool] = [:]
    private var sectionViews: [CollapsibleSectionView] = []

    private let rowFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func layout() {
        super.layout()
        let contentWidth = max(300, detailSectionsScrollView.contentSize.width)
        let height = max(detailSectionsStack.fittingSize.height + 16, detailSectionsScrollView.contentSize.height)
        detailSectionsStack.frame = NSRect(x: 0, y: 0, width: contentWidth, height: height)
    }

    func render(interactions: [DictationInteraction], selectedIndex: Int?) {
        self.interactions = interactions
        interactionsTableView.reloadData()
        if let selectedIndex, interactions.indices.contains(selectedIndex) {
            interactionsTableView.selectRowIndexes(IndexSet(integer: selectedIndex), byExtendingSelection: false)
            interactionsTableView.scrollRowToVisible(selectedIndex)
        } else {
            interactionsTableView.deselectAll(nil)
        }
    }

    func renderSections(
        _ sections: [InteractionDetailSection],
        selectedIndex: Int?,
        sectionFocused: Bool,
        preserveScrollPosition: Bool,
        scrollToSelection: Bool
    ) {
        let priorOrigin = detailSectionsScrollView.contentView.bounds.origin
        detailSectionsStack.arrangedSubviews.forEach { view in
            detailSectionsStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        sectionViews = []

        for section in sections {
            let expanded = sectionExpandedByTitle[section.title] ?? section.defaultExpanded
            let sectionView = CollapsibleSectionView(
                title: section.title,
                body: section.body,
                expanded: expanded,
                onExpandedChanged: { [weak self] isExpanded in
                    self?.sectionExpandedByTitle[section.title] = isExpanded
                }
            )
            detailSectionsStack.addArrangedSubview(sectionView)
            sectionExpandedByTitle[section.title] = expanded
            sectionViews.append(sectionView)
        }
        setSectionSelection(
            selectedIndex: selectedIndex,
            sectionFocused: sectionFocused,
            shouldScrollToSelection: scrollToSelection
        )
        if preserveScrollPosition {
            restoreDetailScroll(to: priorOrigin)
        }
    }

    func setSectionSelection(selectedIndex: Int?, sectionFocused: Bool, shouldScrollToSelection: Bool) {
        for (index, sectionView) in sectionViews.enumerated() {
            let isSelected = selectedIndex == index
            sectionView.setHighlighted(isSelected && sectionFocused)
        }
        if shouldScrollToSelection, let selectedIndex, sectionViews.indices.contains(selectedIndex) {
            detailSectionsStack.scrollToVisible(sectionViews[selectedIndex].frame.insetBy(dx: 0, dy: -8))
        }
    }

    func toggleSection(at index: Int) {
        guard sectionViews.indices.contains(index) else {
            return
        }
        let sectionView = sectionViews[index]
        let visibleBefore = detailSectionsScrollView.contentView.documentVisibleRect
        let sectionTopBefore = sectionView.frame.maxY
        let deltaFromVisibleTop = sectionTopBefore - visibleBefore.maxY

        sectionViews[index].toggleExpandedFromKeyboard()
        needsLayout = true
        layoutSubtreeIfNeeded()
        anchorSectionTop(at: index, deltaFromVisibleTop: deltaFromVisibleTop)
    }

    func isSectionExpanded(at index: Int) -> Bool? {
        guard sectionViews.indices.contains(index) else {
            return nil
        }
        return sectionViews[index].expandedState
    }

    func setStatus(_ status: String) {
        statusLabel.stringValue = status
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        interactions.count
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        guard interactions.indices.contains(row),
              let column = tableView.tableColumns.first
        else {
            return 30
        }

        let width = max(120, column.width - 16)
        let text = rowDisplayText(for: row)
        let bounds = (text as NSString).boundingRect(
            with: NSSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: rowFont]
        )
        return max(30, ceil(bounds.height) + 10)
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard interactions.indices.contains(row) else {
            return nil
        }

        let identifier = NSUserInterfaceItemIdentifier("interactionCell")
        let cellView: InteractionListCellView
        if let reused = tableView.makeView(withIdentifier: identifier, owner: self) as? InteractionListCellView {
            cellView = reused
        } else {
            cellView = InteractionListCellView(frame: .zero)
            cellView.identifier = identifier
        }

        cellView.configure(text: rowDisplayText(for: row), font: rowFont)
        return cellView
    }

    private func rowDisplayText(for row: Int) -> String {
        let finalOutput = interactions[row].finalOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        return finalOutput.isEmpty ? "<empty output>" : finalOutput
    }

    private func restoreDetailScroll(to point: NSPoint) {
        guard let documentView = detailSectionsScrollView.documentView else {
            return
        }
        let visibleHeight = detailSectionsScrollView.contentView.bounds.height
        let maxY = max(0, documentView.bounds.height - visibleHeight)
        let clamped = NSPoint(x: 0, y: min(max(0, point.y), maxY))
        detailSectionsScrollView.contentView.scroll(to: clamped)
        detailSectionsScrollView.reflectScrolledClipView(detailSectionsScrollView.contentView)
    }

    private func anchorSectionTop(at index: Int, deltaFromVisibleTop: CGFloat) {
        guard sectionViews.indices.contains(index) else {
            return
        }
        let sectionFrame = sectionViews[index].frame
        let visibleHeight = detailSectionsScrollView.contentView.bounds.height
        let desiredVisibleTop = sectionFrame.maxY - deltaFromVisibleTop
        let desiredOriginY = desiredVisibleTop - visibleHeight
        restoreDetailScroll(to: NSPoint(x: 0, y: desiredOriginY))
    }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        titleLabel.font = .systemFont(ofSize: 28, weight: .bold)
        titleLabel.textColor = .white

        statusLabel.font = .systemFont(ofSize: 12, weight: .regular)
        statusLabel.textColor = NSColor.white.withAlphaComponent(0.8)

        let headerStack = NSStackView(views: [titleLabel, statusLabel])
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        headerStack.orientation = .vertical
        headerStack.alignment = .leading
        headerStack.spacing = 6

        interactionsTableView.headerView = nil
        interactionsTableView.selectionHighlightStyle = .regular
        interactionsTableView.focusRingType = .none
        interactionsTableView.backgroundColor = NSColor.black.withAlphaComponent(0.25)
        interactionsTableView.gridStyleMask = [.solidHorizontalGridLineMask]
        interactionsTableView.dataSource = self
        interactionsTableView.delegate = self

        let outputColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("final_output"))
        outputColumn.title = "Final Output"
        outputColumn.width = 420
        interactionsTableView.addTableColumn(outputColumn)

        interactionsScrollView.translatesAutoresizingMaskIntoConstraints = false
        interactionsScrollView.borderType = .bezelBorder
        interactionsScrollView.hasVerticalScroller = true
        interactionsScrollView.hasHorizontalScroller = false
        interactionsScrollView.autohidesScrollers = true
        interactionsScrollView.documentView = interactionsTableView

        detailSectionsStack.orientation = .vertical
        detailSectionsStack.alignment = .leading
        detailSectionsStack.spacing = 10
        detailSectionsStack.translatesAutoresizingMaskIntoConstraints = true

        detailSectionsScrollView.translatesAutoresizingMaskIntoConstraints = false
        detailSectionsScrollView.borderType = .bezelBorder
        detailSectionsScrollView.hasVerticalScroller = true
        detailSectionsScrollView.hasHorizontalScroller = false
        detailSectionsScrollView.autohidesScrollers = true
        detailSectionsScrollView.drawsBackground = false
        detailSectionsScrollView.documentView = detailSectionsStack

        let contentStack = NSStackView(views: [interactionsScrollView, detailSectionsScrollView])
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.orientation = .horizontal
        contentStack.alignment = .top
        contentStack.distribution = .fill
        contentStack.spacing = 12

        addSubview(headerStack)
        addSubview(contentStack)

        NSLayoutConstraint.activate([
            headerStack.topAnchor.constraint(equalTo: topAnchor, constant: 24),
            headerStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            headerStack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -24),

            contentStack.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 14),
            contentStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            contentStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            contentStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -24),

            interactionsScrollView.widthAnchor.constraint(equalToConstant: 430)
        ])
    }
}

private final class InteractionListCellView: NSView {
    private let textFieldLabel = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        nil
    }

    func configure(text: String, font: NSFont) {
        textFieldLabel.stringValue = text
        textFieldLabel.font = font
    }

    private func setup() {
        textFieldLabel.translatesAutoresizingMaskIntoConstraints = false
        textFieldLabel.lineBreakMode = .byWordWrapping
        textFieldLabel.maximumNumberOfLines = 0
        textFieldLabel.cell?.wraps = true
        textFieldLabel.cell?.usesSingleLineMode = false
        textFieldLabel.textColor = .white

        addSubview(textFieldLabel)
        NSLayoutConstraint.activate([
            textFieldLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            textFieldLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            textFieldLabel.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            textFieldLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4)
        ])
    }
}

private final class CollapsibleSectionView: NSBox {
    private let headerButton = NSButton(title: "", target: nil, action: nil)
    private let bodyScrollView = NSScrollView()
    private let bodyTextView = NSTextView()

    private var sectionTitle: String = ""
    private var isExpanded = true
    private let onExpandedChanged: (Bool) -> Void
    private let normalBorderColor = NSColor.white.withAlphaComponent(0.2)
    private let highlightedBorderColor = NSColor.systemBlue.withAlphaComponent(0.9)

    init(title: String, body: String, expanded: Bool, onExpandedChanged: @escaping (Bool) -> Void) {
        self.onExpandedChanged = onExpandedChanged
        super.init(frame: .zero)
        setup()
        apply(title: title, body: body, expanded: expanded)
    }

    required init?(coder: NSCoder) {
        nil
    }

    @objc
    private func toggleExpanded() {
        applyToggle()
    }

    func toggleExpandedFromKeyboard() {
        applyToggle()
    }

    var expandedState: Bool {
        isExpanded
    }

    func setHighlighted(_ highlighted: Bool) {
        borderColor = highlighted ? highlightedBorderColor : normalBorderColor
        fillColor = highlighted
            ? NSColor.systemBlue.withAlphaComponent(0.12)
            : NSColor.black.withAlphaComponent(0.18)
    }

    private func applyToggle() {
        isExpanded.toggle()
        bodyScrollView.isHidden = !isExpanded
        headerButton.title = (isExpanded ? "▼ " : "▶ ") + sectionTitle
        onExpandedChanged(isExpanded)
    }

    private func apply(title: String, body: String, expanded: Bool) {
        sectionTitle = title
        isExpanded = expanded
        headerButton.title = (expanded ? "▼ " : "▶ ") + title
        bodyTextView.string = body
        bodyScrollView.isHidden = !expanded
    }

    private func setup() {
        boxType = .custom
        borderWidth = 1
        borderColor = normalBorderColor
        cornerRadius = 6
        fillColor = NSColor.black.withAlphaComponent(0.18)
        contentViewMargins = NSSize(width: 8, height: 8)

        headerButton.translatesAutoresizingMaskIntoConstraints = false
        headerButton.setButtonType(.momentaryPushIn)
        headerButton.bezelStyle = .inline
        headerButton.isBordered = false
        headerButton.alignment = .left
        headerButton.font = .systemFont(ofSize: 13, weight: .semibold)
        headerButton.contentTintColor = .white
        headerButton.target = self
        headerButton.action = #selector(toggleExpanded)

        bodyTextView.frame = NSRect(x: 0, y: 0, width: 400, height: 120)
        bodyTextView.isEditable = false
        bodyTextView.isSelectable = true
        bodyTextView.isVerticallyResizable = true
        bodyTextView.isHorizontallyResizable = false
        bodyTextView.textContainerInset = NSSize(width: 6, height: 6)
        bodyTextView.textContainer?.lineBreakMode = .byWordWrapping
        bodyTextView.textContainer?.widthTracksTextView = true
        bodyTextView.backgroundColor = NSColor.black.withAlphaComponent(0.15)
        bodyTextView.textColor = .white
        bodyTextView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)

        bodyScrollView.translatesAutoresizingMaskIntoConstraints = false
        bodyScrollView.borderType = .bezelBorder
        bodyScrollView.hasVerticalScroller = true
        bodyScrollView.hasHorizontalScroller = false
        bodyScrollView.autohidesScrollers = true
        bodyScrollView.documentView = bodyTextView

        let stack = NSStackView(views: [headerButton, bodyScrollView])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8

        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
            bodyScrollView.widthAnchor.constraint(equalTo: stack.widthAnchor),
            bodyScrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 120),
            widthAnchor.constraint(greaterThanOrEqualToConstant: 320)
        ])
    }
}
