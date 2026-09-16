import AppKit

/// Look of the picker window — background tint and how far you can see through it.
/// Stored in `UserDefaults`, like the shortcut, so it survives a rebuild. Changes post
/// `didChange` so an open picker restyles while the preferences window is still up.
final class AppearanceSettings {
    static let shared = AppearanceSettings()
    static let didChange = Notification.Name("ClipHistoryAppearanceDidChange")

    /// Below ~0.25 the panel stops reading as a window at all, so the slider floors there.
    static let opacityRange: ClosedRange<Double> = 0.25...1.0
    static let defaultOpacity: Double = 1.0

    private enum Key {
        static let opacity = "panelOpacity"
        static let backgroundColor = "panelBackgroundColor"
    }

    private let defaults = UserDefaults.standard

    private init() {}

    var opacity: Double {
        get {
            // `double(forKey:)` returns 0 for an unset key, which would mean invisible.
            guard defaults.object(forKey: Key.opacity) != nil else { return Self.defaultOpacity }
            return defaults.double(forKey: Key.opacity).clamped(to: Self.opacityRange)
        }
        set {
            defaults.set(newValue.clamped(to: Self.opacityRange), forKey: Key.opacity)
            notifyChange()
        }
    }

    /// `nil` means "follow the system window background", which is also the default.
    var backgroundColor: NSColor? {
        get {
            guard let data = defaults.data(forKey: Key.backgroundColor) else { return nil }
            return try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data)
        }
        set {
            if let color = newValue,
                let data = try? NSKeyedArchiver.archivedData(
                    withRootObject: color, requiringSecureCoding: true)
            {
                defaults.set(data, forKey: Key.backgroundColor)
            } else {
                defaults.removeObject(forKey: Key.backgroundColor)
            }
            notifyChange()
        }
    }

    private func notifyChange() {
        NotificationCenter.default.post(name: Self.didChange, object: self)
    }
}

extension NSColor {
    /// Perceived brightness, used to flip the panel to the dark appearance so labels stay
    /// readable on a dark custom background — AppKit won't infer that from a window colour.
    var isDark: Bool {
        guard let rgb = usingColorSpace(.sRGB) else { return false }
        let luminance =
            0.299 * rgb.redComponent + 0.587 * rgb.greenComponent + 0.114 * rgb.blueComponent
        return luminance < 0.5
    }
}

extension Double {
    fileprivate func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
