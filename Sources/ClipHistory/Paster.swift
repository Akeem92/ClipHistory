import AppKit
import ApplicationServices
import Carbon.HIToolbox
import CoreGraphics

/// Writing the clipboard is free; synthesizing Cmd+V is not — macOS only lets trusted
/// apps post keyboard events, hence the Accessibility permission. Without it the text
/// still lands on the clipboard and you press Cmd+V yourself.
enum Paster {
    static let autoPasteDidChange = Notification.Name("ClipHistoryAutoPasteDidChange")

    private static let autoPasteKey = "autoPasteEnabled"

    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// The user's own switch, separate from the system permission: two different reasons
    /// auto-paste might not happen, and the menu has to be able to tell them apart.
    /// Defaults to on — that's what the app is for.
    static var isAutoPasteEnabled: Bool {
        get { UserDefaults.standard.object(forKey: autoPasteKey) as? Bool ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: autoPasteKey)
            NotificationCenter.default.post(name: autoPasteDidChange, object: nil)
        }
    }

    /// On and actually able to fire. Anything showing auto-paste state wants this, not
    /// either half on its own.
    static var isAutoPasteActive: Bool {
        isAutoPasteEnabled && isTrusted
    }

    static func promptForAccessibility() {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary)
    }

    /// What the "Enable Auto-Paste…" menu item runs. The prompt comes first and is the
    /// part that matters: it is what registers ClipHistory in the Accessibility list.
    /// Opening the pane alone sends the user to look for a row that may not exist yet.
    static func requestAccessibility() {
        promptForAccessibility()
        openAccessibilitySettings()
    }

    static func openAccessibilitySettings() {
        // macOS 13 moved this pane into an ExtensionKit bundle. The old preference-pane id
        // still resolves through a shim, so it is kept as a fallback, but only the new one
        // reliably lands on the Accessibility list on current macOS.
        openFirstWorking([
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
        ])
    }

    private static func openFirstWorking(_ urlStrings: [String]) {
        guard let first = urlStrings.first, let url = URL(string: first) else { return }

        let configuration = NSWorkspace.OpenConfiguration()
        // System Settings is usually already running, and then the pane switches behind
        // whatever is in front — which reads as the button doing nothing at all.
        configuration.activates = true

        NSWorkspace.shared.open(url, configuration: configuration) { _, error in
            guard error != nil else { return }
            DispatchQueue.main.async { openFirstWorking(Array(urlStrings.dropFirst())) }
        }
    }

    /// - Parameter target: the app that was frontmost before the picker appeared.
    static func paste(_ text: String, into target: NSRunningApplication?) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        guard isAutoPasteEnabled else { return }  // clipboard only, by choice
        guard isTrusted else {
            NSLog("ClipHistory: no Accessibility permission — press Cmd+V to paste.")
            return
        }
        guard let target else {
            sendCommandV()
            return
        }

        target.activate()
        // Activation is async; the keystroke has to arrive after the target is frontmost.
        // Raise this if pastes ever land in the wrong app.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            sendCommandV()
        }
    }

    private static func sendCommandV() {
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return }
        let vKeyCode = CGKeyCode(kVK_ANSI_V)

        guard
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true),
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false)
        else { return }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cgAnnotatedSessionEventTap)
        keyUp.post(tap: .cgAnnotatedSessionEventTap)
    }
}
