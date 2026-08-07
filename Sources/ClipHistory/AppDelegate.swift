import AppKit
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let showHistory = Self("showHistory", default: .init(.v, modifiers: [.command, .option]))
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = HistoryStore()
    private let picker = PickerPanel()
    private let preferences = PreferencesPanel()

    private var watcher: ClipboardWatcher?
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setUpStatusItem()

        picker.onPick = { text, target in
            Paster.paste(text, into: target)
        }
        picker.onDelete = { [weak self] text in
            self?.store.remove(text)
        }

        let watcher = ClipboardWatcher { [weak self] text in
            self?.store.add(text)
        }
        watcher.start()
        self.watcher = watcher

        KeyboardShortcuts.onKeyDown(for: .showHistory) { [weak self] in
            self?.togglePicker()
        }

        if !Paster.isTrusted {
            Paster.promptForAccessibility()
        }
    }

    private func togglePicker() {
        if picker.isVisible {
            picker.hide()
        } else {
            picker.show(items: store.items)
        }
    }

    // MARK: - Menu bar

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(
            systemSymbolName: "doc.on.clipboard",
            accessibilityDescription: "ClipHistory"
        )
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        statusItem = item
    }

    @objc private func showPicker() {
        picker.show(items: store.items)
    }

    @objc private func clearHistory() {
        store.clear()
    }

    @objc private func showPreferences() {
        preferences.show()
    }

    @objc private func openAccessibilitySettings() {
        Paster.openAccessibilitySettings()
    }

    @objc private func revealStorage() {
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: store.storageDirectory.path)
    }
}

// MARK: - Menu rebuilt each time it opens

extension AppDelegate: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let count = store.items.count
        let header = NSMenuItem(
            title: count == 0 ? "No history yet — copy something"
                              : "\(count) item\(count == 1 ? "" : "s") stored",
            action: nil,
            keyEquivalent: ""
        )
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        let show = NSMenuItem(title: "Show History", action: #selector(showPicker), keyEquivalent: "")
        show.target = self
        show.setShortcut(for: .showHistory)
        menu.addItem(show)

        if !Paster.isTrusted {
            let grant = NSMenuItem(
                title: "Enable Auto-Paste…",
                action: #selector(openAccessibilitySettings),
                keyEquivalent: ""
            )
            grant.target = self
            menu.addItem(grant)
        }

        let prefs = NSMenuItem(
            title: "Preferences…", action: #selector(showPreferences), keyEquivalent: ","
        )
        prefs.target = self
        menu.addItem(prefs)

        menu.addItem(.separator())

        let reveal = NSMenuItem(
            title: "Reveal Storage in Finder",
            action: #selector(revealStorage),
            keyEquivalent: ""
        )
        reveal.target = self
        menu.addItem(reveal)

        let clear = NSMenuItem(title: "Clear History", action: #selector(clearHistory), keyEquivalent: "")
        clear.target = self
        menu.addItem(clear)

        menu.addItem(.separator())

        menu.addItem(NSMenuItem(
            title: "Quit ClipHistory",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))
    }
}
