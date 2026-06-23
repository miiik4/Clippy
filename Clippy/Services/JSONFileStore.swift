import Foundation
import os

/// Persists a `Codable` array to a JSON file in Application Support. Saves run
/// off the main thread and are debounced so a burst of changes results in a
/// single disk write; `saveImmediately` flushes synchronously on shutdown.
final class JSONFileStore<Element: Codable> {
    private let fileURL: URL
    private let label: String
    private let queue: DispatchQueue
    private let logger = Logger(subsystem: "com.clippy", category: "JSONFileStore")
    private var pendingSave: DispatchWorkItem?

    init(fileName: String, label: String) {
        self.label = label
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("Clippy", isDirectory: true)
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        fileURL = appDir.appendingPathComponent(fileName)
        queue = DispatchQueue(label: "com.clippy.store.\(label)", qos: .utility)
    }

    /// Debounced, off-main save. Coalesces rapid successive calls.
    func save(_ items: [Element]) {
        pendingSave?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.write(items) }
        pendingSave = work
        queue.asyncAfter(deadline: .now() + 0.3, execute: work)
    }

    /// Synchronous save used on shutdown so a pending debounced write is not lost.
    func saveImmediately(_ items: [Element]) {
        pendingSave?.cancel()
        pendingSave = nil
        queue.sync { write(items) }
    }

    func load() -> [Element] {
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode([Element].self, from: data)
        } catch {
            return []
        }
    }

    private func write(_ items: [Element]) {
        do {
            let data = try JSONEncoder().encode(items)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            logger.error("Failed to save \(self.label, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }
}
