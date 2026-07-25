import Foundation

/// Clipboard history, newest first, mirrored to a JSON file so it survives a restart.
/// The file is 0600 — clipboard content is readable only by this user.
final class HistoryStore {
    private(set) var items: [String] = []

    private let limit = 500
    private let fileURL: URL
    private var pendingSave: DispatchWorkItem?

    init() {
        let directory = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ClipHistory", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        fileURL = directory.appendingPathComponent("history.json")
        load()
    }

    var storageDirectory: URL { fileURL.deletingLastPathComponent() }

    func add(_ text: String) {
        // Already top: avoids a pointless write when the watcher sees our own paste.
        if items.first == text { return }
        // Re-copying something older promotes it instead of duplicating it.
        items.removeAll { $0 == text }
        items.insert(text, at: 0)
        if items.count > limit {
            items.removeLast(items.count - limit)
        }
        scheduleSave()
    }

    /// Matching by value is unambiguous because `add` dedupes. This is the escape hatch
    /// for content no password manager tagged as concealed.
    func remove(_ text: String) {
        guard let index = items.firstIndex(of: text) else { return }
        items.remove(at: index)
        scheduleSave()
    }

    func clear() {
        items.removeAll()
        scheduleSave()
    }

    // MARK: - Persistence

    private func load() {
        guard
            let data = try? Data(contentsOf: fileURL),
            let decoded = try? JSONDecoder().decode([String].self, from: data)
        else { return }
        items = Array(decoded.prefix(limit))
    }

    /// Coalesced: rapid copying produces one write a second, not one per copy.
    private func scheduleSave() {
        pendingSave?.cancel()
        let snapshot = items
        let url = fileURL
        let work = DispatchWorkItem {
            guard let data = try? JSONEncoder().encode(snapshot) else { return }
            try? data.write(to: url, options: .atomic)
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o600], ofItemAtPath: url.path
            )
        }
        pendingSave = work
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 1.0, execute: work)
    }
}
