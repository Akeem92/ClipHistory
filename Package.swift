// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "ClipHistory",
    // Required: without this, SPM assumes an old macOS and rejects modern AppKit APIs.
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0")
    ],
    targets: [
        .executableTarget(
            name: "ClipHistory",
            dependencies: ["KeyboardShortcuts"]
        )
    ],
    // Swift 6 mode adds strict concurrency checking, which fights AppKit and Carbon
    // C callbacks. Flip to .v6 once the app works if you want to learn that.
    swiftLanguageModes: [.v5]
)
