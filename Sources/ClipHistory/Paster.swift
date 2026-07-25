import AppKit
import ApplicationServices
import Carbon.HIToolbox
import CoreGraphics

/// Writing the clipboard is free; synthesizing Cmd+V is not — macOS only lets trusted
/// apps post keyboard events, hence the Accessibility permission. Without it the text
/// still lands on the clipboard and you press Cmd+V yourself.
enum Paster {
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    static func promptForAccessibility() {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary)
    }

    static func openAccessibilitySettings() {
        let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        )!
        NSWorkspace.shared.open(url)
    }

    /// - Parameter target: the app that was frontmost before the picker appeared.
    static func paste(_ text: String, into target: NSRunningApplication?) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

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
