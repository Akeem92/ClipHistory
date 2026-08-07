import AppKit
import KeyboardShortcuts

/// A tiny standalone window holding the shortcut recorder — kept separate from
/// PickerPanel since it's shown rarely and has none of the picker's key handling.
final class PreferencesPanel: NSObject {
    private let panel: NSPanel

    override init() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 90),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        super.init()
        buildInterface()
    }

    func show() {
        panel.center()
        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
    }

    private func buildInterface() {
        panel.title = "ClipHistory Preferences"
        panel.isReleasedWhenClosed = false

        let label = NSTextField(labelWithString: "Show History shortcut:")
        label.translatesAutoresizingMaskIntoConstraints = false

        let recorder = KeyboardShortcuts.RecorderCocoa(for: .showHistory)
        recorder.translatesAutoresizingMaskIntoConstraints = false

        guard let content = panel.contentView else { return }
        content.addSubview(label)
        content.addSubview(recorder)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: content.topAnchor, constant: 24),
            label.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),

            recorder.centerYAnchor.constraint(equalTo: label.centerYAnchor),
            recorder.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 12),
            recorder.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
        ])
    }
}
