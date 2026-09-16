import AppKit
import KeyboardShortcuts

/// A tiny standalone window holding the shortcut recorder and the picker's appearance
/// settings — kept separate from PickerPanel since it's shown rarely and has none of the
/// picker's key handling.
final class PreferencesPanel: NSObject {
    private let panel: NSPanel
    private let settings = AppearanceSettings.shared

    private let autoPasteToggle = NSButton()
    private let accessibilityStatus = NSTextField(labelWithString: "")
    private let grantAccessButton = NSButton()
    private let opacitySlider = NSSlider()
    private let opacityReadout = NSTextField(labelWithString: "")
    private let colorWell = NSColorWell()
    private let systemBackgroundToggle = NSButton()

    override init() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 200),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        super.init()
        buildInterface()
    }

    func show() {
        // The picker's translucency comes from the opacity slider alone, so the system
        // colour picker shouldn't offer a second, conflicting alpha channel. Set here and
        // not at build time: touching NSColorPanel spins up its window.
        NSColorPanel.shared.showsAlpha = false
        // Raised in step with this window, or picking a colour would happen behind the
        // window that opened the picker.
        NSColorPanel.shared.level = NSWindow.Level(rawValue: NSWindow.Level.modalPanel.rawValue + 1)
        syncControls()
        panel.center()
        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
    }

    // MARK: - Settings

    @objc private func autoPasteToggled(_ sender: NSButton) {
        Paster.isAutoPasteEnabled = sender.state == .on
        // Ticking the box is a request for it to work, so go after the permission it needs.
        if Paster.isAutoPasteEnabled && !Paster.isTrusted {
            Paster.requestAccessibility()
        }
        syncControls()
    }

    @objc private func grantAccess() {
        Paster.requestAccessibility()
    }

    @objc private func opacityChanged(_ sender: NSSlider) {
        settings.opacity = sender.doubleValue
        updateOpacityReadout()
    }

    @objc private func backgroundColorChanged(_ sender: NSColorWell) {
        // Opacity has its own slider, so the colour itself is always stored fully opaque —
        // otherwise the picker's transparency would have two competing sources.
        settings.backgroundColor = sender.color.withAlphaComponent(1.0)
    }

    @objc private func systemBackgroundToggled(_ sender: NSButton) {
        let useSystem = sender.state == .on
        colorWell.isEnabled = !useSystem
        settings.backgroundColor = useSystem ? nil : colorWell.color.withAlphaComponent(1.0)
    }

    /// The panel is long-lived, so the controls are re-read from storage on every show
    /// rather than trusted to still match.
    private func syncControls() {
        let custom = settings.backgroundColor

        autoPasteToggle.state = Paster.isAutoPasteEnabled ? .on : .off
        updateAccessibilityStatus()

        opacitySlider.doubleValue = settings.opacity
        updateOpacityReadout()

        colorWell.color = custom ?? .windowBackgroundColor
        colorWell.isEnabled = custom != nil
        systemBackgroundToggle.state = custom == nil ? .on : .off
    }

    /// The permission is granted outside the app, so the row states plainly which of the
    /// two conditions is missing instead of showing a tick that can't deliver.
    private func updateAccessibilityStatus() {
        let needsPermission = Paster.isAutoPasteEnabled && !Paster.isTrusted

        accessibilityStatus.isHidden = !Paster.isAutoPasteEnabled
        grantAccessButton.isHidden = !needsPermission

        if needsPermission {
            accessibilityStatus.stringValue = "Needs Accessibility access to press ⌘V for you."
            accessibilityStatus.textColor = .systemOrange
        } else {
            accessibilityStatus.stringValue = "Accessibility access granted."
            accessibilityStatus.textColor = .tertiaryLabelColor
        }
    }

    private func updateOpacityReadout() {
        opacityReadout.stringValue = "\(Int((settings.opacity * 100).rounded()))%"
    }

    // MARK: - Layout

    private func buildInterface() {
        panel.title = "ClipHistory Preferences"
        panel.isReleasedWhenClosed = false
        panel.delegate = self
        // Strictly above the picker's .floating level, not merely equal to it: same-level
        // windows order by whoever was fronted last, so clicking the picker would bury the
        // preferences behind it again.
        panel.level = .modalPanel

        let recorder = KeyboardShortcuts.RecorderCocoa(for: .showHistory)

        configureOpacityControls()
        configureBackgroundControls()

        configureAutoPasteControls()

        let autoPasteStatusRow = NSStackView(views: [accessibilityStatus, grantAccessButton])
        autoPasteStatusRow.spacing = 8
        autoPasteStatusRow.alignment = .centerY

        let opacityRow = NSStackView(views: [opacitySlider, opacityReadout])
        opacityRow.spacing = 8
        opacityRow.alignment = .centerY

        let backgroundRow = NSStackView(views: [colorWell, systemBackgroundToggle])
        backgroundRow.spacing = 10
        backgroundRow.alignment = .centerY

        let footnote = NSTextField(
            labelWithString: "Opacity and colour apply to the history picker window.")
        footnote.font = .systemFont(ofSize: 11)
        footnote.textColor = .tertiaryLabelColor

        let grid = NSGridView(views: [
            [label("Show History shortcut:"), recorder],
            [label("Auto-paste:"), autoPasteToggle],
            [NSGridCell.emptyContentView, autoPasteStatusRow],
            [label("Picker opacity:"), opacityRow],
            [label("Picker background:"), backgroundRow],
            [NSGridCell.emptyContentView, footnote],
        ])
        grid.rowSpacing = 12
        grid.columnSpacing = 10
        grid.rowAlignment = .none
        grid.column(at: 0).xPlacement = .trailing
        (0..<grid.numberOfRows).forEach { grid.row(at: $0).yPlacement = .center }
        grid.translatesAutoresizingMaskIntoConstraints = false

        guard let content = panel.contentView else { return }
        content.addSubview(grid)

        NSLayoutConstraint.activate([
            grid.topAnchor.constraint(equalTo: content.topAnchor, constant: 22),
            grid.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            grid.trailingAnchor.constraint(
                lessThanOrEqualTo: content.trailingAnchor, constant: -20),
            grid.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -20),
        ])

        // The grid decides the size; the window follows it instead of a guessed contentRect.
        let fitting = content.fittingSize
        panel.setContentSize(NSSize(width: max(fitting.width, 440), height: fitting.height))

        syncControls()
    }

    private func configureAutoPasteControls() {
        autoPasteToggle.setButtonType(.switch)
        autoPasteToggle.title = "Paste straight into the app you were using"
        autoPasteToggle.target = self
        autoPasteToggle.action = #selector(autoPasteToggled)

        accessibilityStatus.font = .systemFont(ofSize: 11)

        grantAccessButton.bezelStyle = .rounded
        grantAccessButton.controlSize = .small
        grantAccessButton.title = "Grant Access…"
        grantAccessButton.target = self
        grantAccessButton.action = #selector(grantAccess)
    }

    private func configureOpacityControls() {
        opacitySlider.minValue = AppearanceSettings.opacityRange.lowerBound
        opacitySlider.maxValue = AppearanceSettings.opacityRange.upperBound
        opacitySlider.isContinuous = true
        opacitySlider.target = self
        opacitySlider.action = #selector(opacityChanged)
        opacitySlider.translatesAutoresizingMaskIntoConstraints = false

        // Monospaced digits and a fixed width so the slider doesn't shift as it's dragged.
        opacityReadout.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        opacityReadout.textColor = .secondaryLabelColor
        opacityReadout.alignment = .right
        opacityReadout.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            opacitySlider.widthAnchor.constraint(equalToConstant: 190),
            opacityReadout.widthAnchor.constraint(equalToConstant: 38),
        ])
    }

    private func configureBackgroundControls() {
        colorWell.target = self
        colorWell.action = #selector(backgroundColorChanged)
        colorWell.translatesAutoresizingMaskIntoConstraints = false

        systemBackgroundToggle.setButtonType(.switch)
        systemBackgroundToggle.title = "Use the system background"
        systemBackgroundToggle.target = self
        systemBackgroundToggle.action = #selector(systemBackgroundToggled)

        NSLayoutConstraint.activate([
            colorWell.widthAnchor.constraint(equalToConstant: 46),
            colorWell.heightAnchor.constraint(equalToConstant: 24),
        ])
    }

    private func label(_ text: String) -> NSTextField {
        NSTextField(labelWithString: text)
    }
}

// MARK: - Refresh on return from System Settings

extension PreferencesPanel: NSWindowDelegate {
    /// Accessibility is granted in another app, so the moment this window is focused again
    /// is exactly when the status line may have gone stale.
    func windowDidBecomeKey(_ notification: Notification) {
        syncControls()
    }
}
