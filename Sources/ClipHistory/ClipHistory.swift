import AppKit

@main
struct ClipHistory {
    /// Static because NSApplication.delegate is a weak reference.
    private static let appDelegate = AppDelegate()

    static func main() {
        let app = NSApplication.shared
        app.delegate = appDelegate
        app.setActivationPolicy(.accessory)  // no Dock icon; mirrors LSUIElement
        app.run()
    }
}
