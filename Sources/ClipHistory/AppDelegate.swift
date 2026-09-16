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

        // Only worth prompting for a permission the user has asked to use.
        if Paster.isAutoPasteEnabled && !Paster.isTrusted {
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

    @objc private func toggleAutoPaste() {
        Paster.isAutoPasteEnabled.toggle()
        // Switching it on is a request for it to actually work, so chase the permission
        // it needs in the same click instead of leaving a tick that does nothing.
        if Paster.isAutoPasteEnabled && !Paster.isTrusted {
            openAccessibilitySettings()
        }
    }

    @objc private func showPreferences() {
        preferences.show()
    }

    /// Clicking this a second time while still untrusted almost always means the grant was
    /// invalidated rather than never given, so the second visit explains that instead of
    /// silently reopening the same list.
    @objc private func openAccessibilitySettings() {
        let key = "accessibilityRequested"
        let askedBefore = UserDefaults.standard.bool(forKey: key)
        UserDefaults.standard.set(true, forKey: key)

        if askedBefore {
            let alert = NSAlert()
            alert.messageText = "ClipHistory still isn't trusted for Auto-Paste"
            alert.informativeText = """
                If ClipHistory is already ticked in the Accessibility list, remove it with \
                "−" and add it back with "+".

                macOS ties the grant to the app's code signature, and build.sh signs \
                ad-hoc — a signature that changes on every rebuild. The tick survives, the \
                permission doesn't. Tools/make-signing-cert.sh fixes this for good.
                """
            alert.addButton(withTitle: "Open Accessibility Settings")
            alert.addButton(withTitle: "Cancel")
            NSApp.activate()
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }

        Paster.requestAccessibility()
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

        let autoPaste = NSMenuItem(
            title: "Auto-Paste", action: #selector(toggleAutoPaste), keyEquivalent: ""
        )
        autoPaste.target = self
        // The tick follows the setting the click controls, not whether it can currently
        // fire — otherwise ticking it while untrusted would look like a dead menu item.
        // The indented line below carries the "granted, but blocked" news instead.
        autoPaste.state = Paster.isAutoPasteEnabled ? .on : .off
        menu.addItem(autoPaste)

        // Switched on but unable to fire: a bare tick would be a lie, so name the half
        // that's missing rather than leaving the user to wonder why nothing pastes.
        if Paster.isAutoPasteEnabled && !Paster.isTrusted {
            let grant = NSMenuItem(
                title: "Needs Accessibility Access…",
                action: #selector(openAccessibilitySettings),
                keyEquivalent: ""
            )
            grant.target = self
            grant.indentationLevel = 1
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
