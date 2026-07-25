import AppKit
import Carbon.HIToolbox

/// `canBecomeKey` so the search field accepts typing. `performKeyEquivalent` because key
/// equivalents are consulted before the field editor — the only place Cmd+1…9 and
/// Cmd+Delete can be caught while the caret is in the search box.
final class KeyPanel: NSPanel {
    var keyEquivalentHandler: ((NSEvent) -> Bool)?

    override var canBecomeKey: Bool { true }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if keyEquivalentHandler?(event) == true { return true }
        return super.performKeyEquivalent(with: event)
    }
}

/// NSTextField draws single-line text from the top of its frame and the table stretches
/// cells to full row height, so the label has to be wrapped and centred explicitly.
final class ClipCellView: NSTableCellView {
    private let iconView = NSImageView()
    private let label = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        iconView.image = NSImage(systemSymbolName: "text.alignleft", accessibilityDescription: nil)
        iconView.contentTintColor = .tertiaryLabelColor
        iconView.imageScaling = .scaleProportionallyDown
        iconView.translatesAutoresizingMaskIntoConstraints = false

        label.lineBreakMode = .byTruncatingTail
        label.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        label.translatesAutoresizingMaskIntoConstraints = false

        addSubview(iconView)
        addSubview(label)
        textField = label  // enables selected-row text recolouring

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 14),
            iconView.heightAnchor.constraint(equalToConstant: 14),

            label.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("ClipCellView is code-only")
    }

    func configure(with text: String) {
        let collapsed = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        label.stringValue = collapsed.count > 200 ? collapsed.prefix(200) + "…" : collapsed
    }
}

final class PickerPanel: NSObject {
    var onPick: ((String, NSRunningApplication?) -> Void)?
    var onDelete: ((String) -> Void)?

    private let panel: KeyPanel
    private let searchField = NSTextField()
    private let tableView = NSTableView()
    private let listScrollView = NSScrollView()
    private let previewHeader = NSTextField(labelWithString: "")
    private let previewTextView = NSTextView()
    private let previewScrollView = NSScrollView()

    private var items: [String] = []
    private var filtered: [String] = []
    private var previousApp: NSRunningApplication?

    private static let cellIdentifier = NSUserInterfaceItemIdentifier("HistoryCell")

    var isVisible: Bool { panel.isVisible }

    override init() {
        panel = KeyPanel(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 520),
            styleMask: [.titled, .fullSizeContentView, .closable],
            backing: .buffered,
            defer: false
        )
        super.init()
        buildInterface()
        panel.keyEquivalentHandler = { [weak self] event in
            self?.handleKeyEquivalent(event) ?? false
        }
    }

    // MARK: - Show / hide

    func show(items: [String]) {
        self.items = items
        // Before activating: once the panel is up, we are the frontmost app.
        previousApp = NSWorkspace.shared.frontmostApplication

        searchField.stringValue = ""
        applyFilter("")

        positionOnActiveScreen()
        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(searchField)
    }

    func hide() {
        panel.orderOut(nil)
    }

    private func positionOnActiveScreen() {
        let mouse = NSEvent.mouseLocation
        let screen =
            NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }

        panel.setFrameOrigin(
            NSPoint(
                x: visible.midX - panel.frame.width / 2,
                y: visible.midY - panel.frame.height / 2 + visible.height * 0.08
            ))
    }

    // MARK: - Keyboard

    private func handleKeyEquivalent(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags == .command else { return false }

        if event.keyCode == UInt16(kVK_Delete) {
            deleteSelection()
            return true
        }

        if let characters = event.charactersIgnoringModifiers,
            let digit = Int(characters),
            (1...9).contains(digit)
        {
            guard digit - 1 < filtered.count else { return true }
            selectRow(digit - 1)
            commitSelection()
            return true
        }

        return false
    }

    private func deleteSelection() {
        guard let selected = selectedItem else { return }
        let row = tableView.selectedRow

        onDelete?(selected)
        items.removeAll { $0 == selected }
        // Hold position so several entries can be deleted in a row.
        applyFilter(searchField.stringValue, preferredRow: row)
    }

    @objc private func commitSelection() {
        guard let selected = selectedItem else { return }
        let target = previousApp
        hide()  // must be out of the way before focus returns to the target
        onPick?(selected, target)
    }

    // MARK: - Filtering

    private var selectedItem: String? {
        let row = tableView.selectedRow
        guard row >= 0, row < filtered.count else { return nil }
        return filtered[row]
    }

    private func applyFilter(_ query: String, preferredRow: Int = 0) {
        let trimmed = query.trimmingCharacters(in: .whitespaces)

        if trimmed.isEmpty {
            filtered = items
        } else {
            let tokens = trimmed.split(separator: " ").map(String.init)
            filtered = items.filter { candidate in
                tokens.allSatisfy {
                    candidate.range(of: $0, options: [.caseInsensitive, .diacriticInsensitive])
                        != nil
                }
            }
        }

        tableView.reloadData()
        selectRow(min(preferredRow, max(0, filtered.count - 1)))
        updatePreview()
    }

    private func selectRow(_ row: Int) {
        guard !filtered.isEmpty, row >= 0, row < filtered.count else { return }
        tableView.selectRowIndexes([row], byExtendingSelection: false)
        tableView.scrollRowToVisible(row)
    }

    private func moveSelection(by delta: Int) {
        guard !filtered.isEmpty else { return }
        selectRow(min(max(tableView.selectedRow + delta, 0), filtered.count - 1))
    }

    // MARK: - Preview

    private func updatePreview() {
        guard let selected = selectedItem else {
            previewHeader.stringValue = items.isEmpty ? "No history yet" : "No matches"
            previewTextView.string = ""
            return
        }

        let lines = selected.split(separator: "\n", omittingEmptySubsequences: false).count
        previewHeader.stringValue = [
            "\(selected.count) chars",
            "\(lines) line\(lines == 1 ? "" : "s")",
            ByteCountFormatter.string(fromByteCount: Int64(selected.utf8.count), countStyle: .file),
        ].joined(separator: "  ·  ")

        previewTextView.string = selected
        previewTextView.scrollToBeginningOfDocument(nil)
    }

    // MARK: - Layout

    private func buildInterface() {
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = true  // click elsewhere to dismiss
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true

        configureSearchField()
        configureTable()
        configurePreview()

        let topDivider = NSBox()
        topDivider.boxType = .separator
        topDivider.translatesAutoresizingMaskIntoConstraints = false

        let verticalDivider = NSBox()
        verticalDivider.boxType = .separator
        verticalDivider.translatesAutoresizingMaskIntoConstraints = false

        let hint = NSTextField(
            labelWithString:
                "↑↓ navigate    ⏎ paste    ⌘1–9 paste directly    ⌘⌫ forget    esc close")
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .tertiaryLabelColor
        hint.translatesAutoresizingMaskIntoConstraints = false

        guard let content = panel.contentView else { return }
        [
            searchField, topDivider, listScrollView, verticalDivider,
            previewHeader, previewScrollView, hint,
        ].forEach(content.addSubview)

        NSLayoutConstraint.activate([
            searchField.topAnchor.constraint(equalTo: content.topAnchor, constant: 18),
            searchField.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 18),
            searchField.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -18),

            topDivider.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 12),
            topDivider.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            topDivider.trailingAnchor.constraint(equalTo: content.trailingAnchor),

            listScrollView.topAnchor.constraint(equalTo: topDivider.bottomAnchor, constant: 4),
            listScrollView.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            listScrollView.widthAnchor.constraint(equalTo: content.widthAnchor, multiplier: 0.42),
            listScrollView.bottomAnchor.constraint(equalTo: hint.topAnchor, constant: -8),

            verticalDivider.leadingAnchor.constraint(equalTo: listScrollView.trailingAnchor),
            verticalDivider.widthAnchor.constraint(equalToConstant: 1),
            verticalDivider.topAnchor.constraint(equalTo: topDivider.bottomAnchor),
            verticalDivider.bottomAnchor.constraint(equalTo: hint.topAnchor, constant: -8),

            previewHeader.topAnchor.constraint(equalTo: topDivider.bottomAnchor, constant: 14),
            previewHeader.leadingAnchor.constraint(
                equalTo: verticalDivider.trailingAnchor, constant: 16),
            previewHeader.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),

            previewScrollView.topAnchor.constraint(
                equalTo: previewHeader.bottomAnchor, constant: 8),
            previewScrollView.leadingAnchor.constraint(
                equalTo: verticalDivider.trailingAnchor, constant: 12),
            previewScrollView.trailingAnchor.constraint(
                equalTo: content.trailingAnchor, constant: -12),
            previewScrollView.bottomAnchor.constraint(equalTo: hint.topAnchor, constant: -8),

            hint.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 18),
            hint.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -12),
        ])
    }

    private func configureSearchField() {
        searchField.placeholderString = "Search clipboard history…"
        searchField.font = .systemFont(ofSize: 15)
        searchField.isBordered = false
        searchField.drawsBackground = false
        searchField.focusRingType = .none
        searchField.delegate = self
        searchField.translatesAutoresizingMaskIntoConstraints = false
    }

    private func configureTable() {
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("text"))
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.rowHeight = 28
        tableView.style = .inset
        tableView.backgroundColor = .clear
        tableView.dataSource = self
        tableView.delegate = self
        tableView.target = self
        tableView.doubleAction = #selector(commitSelection)
        tableView.refusesFirstResponder = true  // clicks select without stealing focus
        tableView.allowsEmptySelection = false

        listScrollView.documentView = tableView
        listScrollView.hasVerticalScroller = true
        listScrollView.drawsBackground = false
        listScrollView.translatesAutoresizingMaskIntoConstraints = false
    }

    private func configurePreview() {
        previewHeader.font = .systemFont(ofSize: 11)
        previewHeader.textColor = .secondaryLabelColor
        previewHeader.translatesAutoresizingMaskIntoConstraints = false

        // Clipboard content is shown inert: no rich text, no link/data detection, so a
        // copied URL never becomes clickable here.
        previewTextView.isEditable = false
        previewTextView.isSelectable = true
        previewTextView.isRichText = false
        previewTextView.isAutomaticLinkDetectionEnabled = false
        previewTextView.isAutomaticDataDetectionEnabled = false
        previewTextView.isContinuousSpellCheckingEnabled = false
        previewTextView.isGrammarCheckingEnabled = false
        previewTextView.drawsBackground = false
        previewTextView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        previewTextView.textContainerInset = NSSize(width: 4, height: 6)

        previewTextView.minSize = .zero
        previewTextView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude)
        previewTextView.isVerticallyResizable = true
        previewTextView.isHorizontallyResizable = false
        previewTextView.autoresizingMask = [.width]
        previewTextView.textContainer?.widthTracksTextView = true

        previewScrollView.documentView = previewTextView
        previewScrollView.hasVerticalScroller = true
        previewScrollView.drawsBackground = false
        previewScrollView.borderType = .noBorder
        previewScrollView.translatesAutoresizingMaskIntoConstraints = false
    }
}

// MARK: - Search field key handling

extension PickerPanel: NSTextFieldDelegate {
    func controlTextDidChange(_ notification: Notification) {
        applyFilter(searchField.stringValue)
    }

    func control(
        _ control: NSControl,
        textView: NSTextView,
        doCommandBy commandSelector: Selector
    ) -> Bool {
        switch commandSelector {
        case #selector(NSResponder.moveDown(_:)):
            moveSelection(by: 1)
            return true
        case #selector(NSResponder.moveUp(_:)):
            moveSelection(by: -1)
            return true
        case #selector(NSResponder.insertNewline(_:)):
            commitSelection()
            return true
        case #selector(NSResponder.cancelOperation(_:)):
            hide()
            return true
        default:
            return false
        }
    }
}

// MARK: - Table contents

extension PickerPanel: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        filtered.count
    }

    func tableView(
        _ tableView: NSTableView,
        viewFor tableColumn: NSTableColumn?,
        row: Int
    ) -> NSView? {
        let cell =
            tableView.makeView(withIdentifier: Self.cellIdentifier, owner: nil)
            as? ClipCellView
            ?? {
                let new = ClipCellView(frame: .zero)
                new.identifier = Self.cellIdentifier
                return new
            }()
        cell.configure(with: filtered[row])
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        updatePreview()
    }
}
