import AppKit
import DictatorCore

@MainActor
final class LaunchpadConfigOverlayTab: LaunchpadOverlayTab {
    typealias ListConfigs = () async throws -> [RuntimeConfigurationSnapshot]
    typealias GetOptionsForConfig = (_ name: String) async throws -> [RuntimeConfigurationValue]
    typealias SetConfig = (_ name: String, _ value: RuntimeConfigurationValue) async throws -> Void

    let id: String
    let title: String

    private let listConfigs: ListConfigs
    private let getOptionsForConfig: GetOptionsForConfig
    private let setConfig: SetConfig
    private let contentView = LaunchpadConfigOverlayView()

    private var hasLoaded = false
    private var snapshots: [RuntimeConfigurationSnapshot] = []
    private var optionsCache: [String: [RuntimeConfigurationValue]] = [:]
    private var selectedIndex = 0

    init(
        id: String = "config",
        title: String = "config",
        listConfigs: @escaping ListConfigs,
        getOptionsForConfig: @escaping GetOptionsForConfig,
        setConfig: @escaping SetConfig
    ) {
        self.id = id
        self.title = title
        self.listConfigs = listConfigs
        self.getOptionsForConfig = getOptionsForConfig
        self.setConfig = setConfig
    }

    func makeContentView() -> NSView {
        if !hasLoaded {
            hasLoaded = true
            Task { @MainActor [weak self] in
                await self?.reloadRows()
            }
        }
        return contentView
    }

    func handleOverlayKey(_ key: KeyboardKey) async -> Bool {
        switch key {
        case .up:
            moveSelection(delta: -1)
            return true
        case .down:
            moveSelection(delta: 1)
            return true
        case .left:
            await cycleOption(step: -1)
            return true
        case .right:
            await cycleOption(step: 1)
            return true
        default:
            return false
        }
    }

    func overlayDidClose() {
        optionsCache.removeAll()
        hasLoaded = false
        snapshots = []
        selectedIndex = 0
        contentView.render(rows: [], selectedIndex: nil)
        contentView.setStatus("Loading...")
    }

    @MainActor
    private func moveSelection(delta: Int) {
        guard !snapshots.isEmpty else {
            return
        }
        let upperBound = snapshots.count - 1
        selectedIndex = max(0, min(upperBound, selectedIndex + delta))
        renderRows()
    }

    @MainActor
    private func cycleOption(step: Int) async {
        guard snapshots.indices.contains(selectedIndex) else {
            return
        }
        let selected = snapshots[selectedIndex]

        do {
            let options: [RuntimeConfigurationValue]
            if let cached = optionsCache[selected.name] {
                options = cached
            } else {
                options = try await getOptionsForConfig(selected.name)
                optionsCache[selected.name] = options
            }
            guard !options.isEmpty else {
                return
            }

            let currentIndex = options.firstIndex(of: selected.currentValue) ?? 0
            let nextIndex = wrappedIndex(currentIndex + step, count: options.count)
            let nextValue = options[nextIndex]

            try await setConfig(selected.name, nextValue)
            await reloadRows()
        } catch {
            contentView.setStatus("Failed: \(error)")
        }
    }

    @MainActor
    private func reloadRows() async {
        do {
            let listed = try await listConfigs()
            snapshots = listed
            if snapshots.isEmpty {
                selectedIndex = 0
                contentView.render(rows: [], selectedIndex: nil)
                contentView.setStatus("No runtime configs")
                return
            }
            selectedIndex = max(0, min(selectedIndex, snapshots.count - 1))
            renderRows()
            contentView.setStatus("Use up/down to select, left/right to change")
        } catch {
            contentView.render(rows: [], selectedIndex: nil)
            contentView.setStatus("Failed: \(error)")
        }
    }

    @MainActor
    private func renderRows() {
        let rows = snapshots.map { snapshot in
            LaunchpadConfigOverlayView.Row(
                name: snapshot.name,
                value: Self.displayValue(snapshot.currentValue)
            )
        }
        contentView.render(rows: rows, selectedIndex: selectedIndex)
    }

    private func wrappedIndex(_ index: Int, count: Int) -> Int {
        if count == 0 {
            return 0
        }
        let modulo = index % count
        return modulo >= 0 ? modulo : modulo + count
    }

    private static func displayValue(_ value: RuntimeConfigurationValue) -> String {
        switch value {
        case let .string(stringValue):
            return stringValue
        case let .bool(boolValue):
            return boolValue ? "true" : "false"
        }
    }
}

private final class LaunchpadConfigOverlayView: NSView, NSTableViewDataSource, NSTableViewDelegate {
    struct Row {
        let name: String
        let value: String
    }

    private let titleLabel = NSTextField(labelWithString: "config")
    private let statusLabel = NSTextField(labelWithString: "Loading...")
    private let scrollView = NSScrollView()
    private let tableView = NSTableView()
    private var rows: [Row] = []

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        nil
    }

    func render(rows: [Row], selectedIndex: Int?) {
        self.rows = rows
        tableView.reloadData()
        if let selectedIndex, rows.indices.contains(selectedIndex) {
            tableView.selectRowIndexes(IndexSet(integer: selectedIndex), byExtendingSelection: false)
            tableView.scrollRowToVisible(selectedIndex)
        } else {
            tableView.deselectAll(nil)
        }
    }

    func setStatus(_ text: String) {
        statusLabel.stringValue = text
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        rows.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard rows.indices.contains(row) else {
            return nil
        }

        let identifier = NSUserInterfaceItemIdentifier(
            tableColumn?.identifier.rawValue == "name" ? "nameCell" : "valueCell"
        )
        let textField: NSTextField
        if let reused = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTextField {
            textField = reused
        } else {
            textField = NSTextField(labelWithString: "")
            textField.identifier = identifier
            textField.lineBreakMode = .byTruncatingTail
            textField.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
            textField.textColor = .white
        }

        if tableColumn?.identifier.rawValue == "name" {
            textField.stringValue = rows[row].name
        } else {
            textField.stringValue = rows[row].value
        }
        return textField
    }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 28, weight: .bold)
        titleLabel.textColor = .white

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = .systemFont(ofSize: 13, weight: .regular)
        statusLabel.textColor = NSColor.white.withAlphaComponent(0.8)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.borderType = .bezelBorder
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false

        tableView.headerView = NSTableHeaderView()
        tableView.selectionHighlightStyle = .regular
        tableView.focusRingType = .none
        tableView.backgroundColor = NSColor.black.withAlphaComponent(0.25)
        tableView.gridStyleMask = [.solidHorizontalGridLineMask]
        tableView.dataSource = self
        tableView.delegate = self

        let nameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        nameColumn.title = "Config"
        nameColumn.width = 260
        let valueColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("value"))
        valueColumn.title = "Current Value"
        valueColumn.width = 520
        tableView.addTableColumn(nameColumn)
        tableView.addTableColumn(valueColumn)

        scrollView.documentView = tableView

        addSubview(titleLabel)
        addSubview(statusLabel)
        addSubview(scrollView)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),

            statusLabel.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 18),
            statusLabel.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            statusLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -24),

            scrollView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -24)
        ])
    }
}
