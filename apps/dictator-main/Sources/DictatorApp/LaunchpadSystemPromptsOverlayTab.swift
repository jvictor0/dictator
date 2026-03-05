import AppKit
import DictatorCore

@MainActor
final class LaunchpadSystemPromptsOverlayTab: LaunchpadOverlayTab {
    struct DirectoryEntry {
        let name: String
        let relativePath: String
        let isDirectory: Bool
    }

    private struct VisibleEntry {
        let entry: DirectoryEntry
        let depth: Int
    }

    typealias ListDirectoryEntries = (_ relativeDirectory: String) async throws -> [DirectoryEntry]
    typealias LoadPromptBody = (_ relativePath: String) async throws -> String
    typealias GetSelectedPromptPath = () async -> String
    typealias SetSelectedPromptPath = (_ relativePath: String) async throws -> Void

    let id: String
    let title: String

    private let listDirectoryEntries: ListDirectoryEntries
    private let loadPromptBody: LoadPromptBody
    private let getSelectedPromptPath: GetSelectedPromptPath
    private let setSelectedPromptPath: SetSelectedPromptPath
    private let contentView = LaunchpadSystemPromptsOverlayView()

    private var currentDirectory = ""
    private var currentPromptPath = ""
    private var visibleEntries: [VisibleEntry] = []
    private var selectedIndex = 0
    private var expandedDirectories: Set<String> = []
    private var entriesByDirectory: [String: [DirectoryEntry]] = [:]

    init(
        id: String = "system-prompts",
        title: String = "System Prompts",
        listDirectoryEntries: @escaping ListDirectoryEntries,
        loadPromptBody: @escaping LoadPromptBody,
        getSelectedPromptPath: @escaping GetSelectedPromptPath,
        setSelectedPromptPath: @escaping SetSelectedPromptPath
    ) {
        self.id = id
        self.title = title
        self.listDirectoryEntries = listDirectoryEntries
        self.loadPromptBody = loadPromptBody
        self.getSelectedPromptPath = getSelectedPromptPath
        self.setSelectedPromptPath = setSelectedPromptPath
    }

    func makeContentView() -> NSView {
        Task { @MainActor [weak self] in
            await self?.reloadFromConfig()
        }
        return contentView
    }

    func handleOverlayKey(_ key: KeyboardKey) async -> Bool {
        switch key {
        case .up:
            await moveSelection(delta: -1)
            return true
        case .down:
            await moveSelection(delta: 1)
            return true
        case .right:
            return await enterSelectedDirectory()
        case .left:
            return await exitCurrentDirectory()
        case .enter:
            return await selectHighlightedFile()
        default:
            return false
        }
    }

    func overlayDidClose() {
        currentDirectory = ""
        currentPromptPath = ""
        visibleEntries = []
        selectedIndex = 0
        expandedDirectories = []
        entriesByDirectory = [:]
        contentView.renderSelector(directory: "", entries: [], selectedIndex: nil, currentPromptPath: "")
        contentView.setPrompt(relativePath: "", body: "")
        contentView.setStatus("Loading...")
    }

    private func reloadFromConfig() async {
        let configuredPath = await getSelectedPromptPath()
        currentPromptPath = configuredPath
        currentDirectory = parentDirectory(of: configuredPath)
        expandedDirectories = Set(ancestorDirectories(of: configuredPath))

        do {
            try await refreshVisibleEntries(preferredPath: configuredPath)
            try await previewCurrentPrompt(path: configuredPath)
            contentView.setStatus("Use up/down to highlight, enter to select, right to open, left to go back")
        } catch {
            contentView.setPrompt(relativePath: configuredPath, body: "")
            contentView.setStatus("Failed: \(error)")
        }
    }

    private func moveSelection(delta: Int) async {
        guard !visibleEntries.isEmpty else {
            return
        }
        selectedIndex = wrappedIndex(selectedIndex + delta, count: visibleEntries.count)
        renderSelector()
        await previewHighlightedEntry()
    }

    private func enterSelectedDirectory() async -> Bool {
        guard let selected = selectedVisibleEntry()?.entry else {
            return false
        }
        guard selected.isDirectory else {
            contentView.setStatus("File highlighted. Press enter to select")
            return true
        }

        expandedDirectories.insert(selected.relativePath)
        currentDirectory = selected.relativePath
        do {
            try await refreshVisibleEntries(preferredPath: selected.relativePath)
            await previewHighlightedEntry()
        } catch {
            contentView.setStatus("Failed: \(error)")
        }
        return true
    }

    private func exitCurrentDirectory() async -> Bool {
        guard !currentDirectory.isEmpty else {
            contentView.setStatus("Already at root directory")
            return true
        }

        let closingDirectory = currentDirectory
        expandedDirectories = expandedDirectories.filter {
            $0 != closingDirectory && !$0.hasPrefix(closingDirectory + "/")
        }
        currentDirectory = parentDirectory(of: closingDirectory)

        do {
            try await refreshVisibleEntries(preferredPath: currentDirectory)
            await previewHighlightedEntry()
        } catch {
            contentView.setStatus("Failed: \(error)")
        }
        return true
    }

    private func selectHighlightedFile() async -> Bool {
        guard let selected = selectedVisibleEntry()?.entry else {
            return false
        }
        guard !selected.isDirectory else {
            contentView.setStatus("Directory highlighted. Press right arrow to open")
            return true
        }

        do {
            try await setSelectedPromptPath(selected.relativePath)
            currentPromptPath = selected.relativePath
            try await previewCurrentPrompt(path: selected.relativePath)
            renderSelector()
            contentView.setStatus("Selected \(selected.relativePath)")
        } catch {
            contentView.setStatus("Failed: \(error)")
        }
        return true
    }

    private func previewCurrentPrompt(path: String) async throws {
        let body = try await loadPromptBody(path)
        contentView.setPrompt(relativePath: path, body: body)
    }

    private func previewHighlightedEntry() async {
        guard let selected = selectedVisibleEntry()?.entry else {
            return
        }

        if selected.isDirectory {
            contentView.setStatus("Directory highlighted. Right arrow opens, left arrow exits")
            return
        }

        do {
            let body = try await loadPromptBody(selected.relativePath)
            contentView.setPrompt(relativePath: selected.relativePath, body: body)
            contentView.setStatus("Previewing \(selected.relativePath). Press enter to select")
        } catch {
            contentView.setStatus("Failed: \(error)")
        }
    }

    private func refreshVisibleEntries(preferredPath: String?) async throws {
        visibleEntries = try await buildVisibleEntries(for: "", depth: 0)

        if visibleEntries.isEmpty {
            selectedIndex = 0
            contentView.renderSelector(directory: currentDirectory, entries: [], selectedIndex: nil, currentPromptPath: currentPromptPath)
            contentView.setStatus("No prompts available")
            return
        }

        if let preferredPath,
           let preferredIndex = visibleEntries.firstIndex(where: { $0.entry.relativePath == preferredPath })
        {
            selectedIndex = preferredIndex
        } else {
            selectedIndex = min(max(selectedIndex, 0), visibleEntries.count - 1)
        }

        renderSelector()
    }

    private func buildVisibleEntries(for directory: String, depth: Int) async throws -> [VisibleEntry] {
        let entries = try await entriesForDirectory(directory)
        var result: [VisibleEntry] = []
        result.reserveCapacity(entries.count)

        for entry in entries {
            result.append(VisibleEntry(entry: entry, depth: depth))
            if entry.isDirectory, expandedDirectories.contains(entry.relativePath) {
                let children = try await buildVisibleEntries(for: entry.relativePath, depth: depth + 1)
                result.append(contentsOf: children)
            }
        }

        return result
    }

    private func entriesForDirectory(_ directory: String) async throws -> [DirectoryEntry] {
        if let cached = entriesByDirectory[directory] {
            return cached
        }
        let listed = try await listDirectoryEntries(directory)
        entriesByDirectory[directory] = listed
        return listed
    }

    private func renderSelector() {
        let rows = visibleEntries.map { visible in
            LaunchpadSystemPromptsOverlayView.Row(
                title: visible.entry.name,
                relativePath: visible.entry.relativePath,
                isDirectory: visible.entry.isDirectory,
                depth: visible.depth,
                isExpanded: visible.entry.isDirectory && expandedDirectories.contains(visible.entry.relativePath)
            )
        }

        contentView.renderSelector(
            directory: currentDirectory,
            entries: rows,
            selectedIndex: selectedIndex,
            currentPromptPath: currentPromptPath
        )
    }

    private func selectedVisibleEntry() -> VisibleEntry? {
        guard visibleEntries.indices.contains(selectedIndex) else {
            return nil
        }
        return visibleEntries[selectedIndex]
    }

    private func wrappedIndex(_ index: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        let modulo = index % count
        return modulo >= 0 ? modulo : modulo + count
    }

    private func parentDirectory(of path: String) -> String {
        guard !path.isEmpty else {
            return ""
        }
        let components = path.split(separator: "/").map(String.init)
        guard components.count > 1 else {
            return ""
        }
        return components.dropLast().joined(separator: "/")
    }

    private func ancestorDirectories(of path: String) -> [String] {
        let components = path.split(separator: "/").map(String.init)
        guard components.count > 1 else {
            return []
        }

        var ancestors: [String] = []
        for index in 0..<(components.count - 1) {
            ancestors.append(components.prefix(index + 1).joined(separator: "/"))
        }
        return ancestors
    }
}

private final class LaunchpadSystemPromptsOverlayView: NSView, NSTableViewDataSource, NSTableViewDelegate {
    struct Row {
        let title: String
        let relativePath: String
        let isDirectory: Bool
        let depth: Int
        let isExpanded: Bool
    }

    private let titleLabel = NSTextField(labelWithString: "System Prompts")
    private let directoryLabel = NSTextField(labelWithString: "Directory: /")
    private let currentPathLabel = NSTextField(labelWithString: "Current prompt: unavailable")
    private let statusLabel = NSTextField(labelWithString: "Loading...")

    private let selectorScrollView = NSScrollView()
    private let selectorTableView = NSTableView()
    private var selectorRows: [Row] = []

    private let promptScrollView = NSScrollView()
    private let promptTextView = NSTextView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        nil
    }

    func renderSelector(
        directory: String,
        entries: [Row],
        selectedIndex: Int?,
        currentPromptPath: String
    ) {
        directoryLabel.stringValue = directory.isEmpty ? "Directory: (root)" : "Directory: \(directory)"
        selectorRows = entries.map { row in
            let indent = String(repeating: "  ", count: row.depth)
            let marker: String
            if row.isDirectory {
                marker = row.isExpanded ? "v" : ">"
            } else {
                marker = "-"
            }

            let base = "\(indent)\(marker) \(row.title)"
            let decorated = (!row.isDirectory && row.relativePath == currentPromptPath)
                ? "\(base) [active]"
                : base

            return Row(
                title: decorated,
                relativePath: row.relativePath,
                isDirectory: row.isDirectory,
                depth: row.depth,
                isExpanded: row.isExpanded
            )
        }

        selectorTableView.reloadData()
        if let selectedIndex, selectorRows.indices.contains(selectedIndex) {
            selectorTableView.selectRowIndexes(IndexSet(integer: selectedIndex), byExtendingSelection: false)
            selectorTableView.scrollRowToVisible(selectedIndex)
        } else {
            selectorTableView.deselectAll(nil)
        }
    }

    func setPrompt(relativePath: String, body: String) {
        currentPathLabel.stringValue = relativePath.isEmpty
            ? "Current prompt: unavailable"
            : "Current prompt: \(relativePath)"
        promptTextView.string = body
    }

    func setStatus(_ text: String) {
        statusLabel.stringValue = text
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        selectorRows.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard selectorRows.indices.contains(row) else {
            return nil
        }

        let identifier = NSUserInterfaceItemIdentifier("selectorCell")
        let textField: NSTextField
        if let reused = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTextField {
            textField = reused
        } else {
            textField = NSTextField(labelWithString: "")
            textField.identifier = identifier
            textField.lineBreakMode = .byTruncatingTail
            textField.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
            textField.textColor = .white
        }

        textField.stringValue = selectorRows[row].title
        return textField
    }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        titleLabel.font = .systemFont(ofSize: 28, weight: .semibold)
        titleLabel.textColor = .white

        directoryLabel.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        directoryLabel.textColor = NSColor.white.withAlphaComponent(0.85)

        currentPathLabel.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        currentPathLabel.textColor = NSColor.white.withAlphaComponent(0.85)

        statusLabel.font = .systemFont(ofSize: 12, weight: .regular)
        statusLabel.textColor = NSColor.white.withAlphaComponent(0.75)

        let headerStack = NSStackView(views: [titleLabel, directoryLabel, currentPathLabel, statusLabel])
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        headerStack.orientation = .vertical
        headerStack.alignment = .leading
        headerStack.spacing = 6

        selectorTableView.headerView = nil
        selectorTableView.selectionHighlightStyle = .regular
        selectorTableView.focusRingType = .none
        selectorTableView.backgroundColor = NSColor.black.withAlphaComponent(0.25)
        selectorTableView.gridStyleMask = [.solidHorizontalGridLineMask]
        selectorTableView.dataSource = self
        selectorTableView.delegate = self

        let selectorColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("entry"))
        selectorColumn.title = "Prompt Tree"
        selectorColumn.width = 360
        selectorColumn.isEditable = false
        selectorTableView.addTableColumn(selectorColumn)

        selectorScrollView.translatesAutoresizingMaskIntoConstraints = false
        selectorScrollView.borderType = .bezelBorder
        selectorScrollView.hasVerticalScroller = true
        selectorScrollView.hasHorizontalScroller = false
        selectorScrollView.autohidesScrollers = true
        selectorScrollView.documentView = selectorTableView

        promptTextView.frame = NSRect(x: 0, y: 0, width: 900, height: 600)
        promptTextView.minSize = NSSize(width: 0, height: 0)
        promptTextView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        promptTextView.isVerticallyResizable = true
        promptTextView.isHorizontallyResizable = false
        promptTextView.autoresizingMask = [.width]
        promptTextView.textContainerInset = NSSize(width: 8, height: 8)
        promptTextView.textContainer?.containerSize = NSSize(width: 900, height: CGFloat.greatestFiniteMagnitude)
        promptTextView.textContainer?.widthTracksTextView = true
        promptTextView.textContainer?.lineBreakMode = .byWordWrapping
        promptTextView.isEditable = false
        promptTextView.isSelectable = true
        promptTextView.backgroundColor = NSColor.black.withAlphaComponent(0.22)
        promptTextView.textColor = .white
        promptTextView.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        promptTextView.drawsBackground = true

        promptScrollView.translatesAutoresizingMaskIntoConstraints = false
        promptScrollView.borderType = .bezelBorder
        promptScrollView.hasVerticalScroller = true
        promptScrollView.hasHorizontalScroller = false
        promptScrollView.autohidesScrollers = true
        promptScrollView.documentView = promptTextView

        let contentStack = NSStackView(views: [selectorScrollView, promptScrollView])
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

            selectorScrollView.widthAnchor.constraint(equalToConstant: 380)
        ])
    }
}
