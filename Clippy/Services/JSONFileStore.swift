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

    /// `directory` defaults to ~/Library/Application Support/Clippy; tests
    /// pass a temporary directory.
    init(fileName: String, label: String, directory: URL? = nil) {
        self.label = label
        let appDir = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Clippy", isDirectory: true)
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

    /// Loads the stored array, skipping individual entries that fail to
    /// decode. If anything could not be read, the original file is first
    /// copied to `<name>.bak` so the next save cannot destroy it.
    func load() -> [Element] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        do {
            let entries = try JSONDecoder().decode([Lossy].self, from: data)
            let decoded = entries.compactMap(\.value)
            if decoded.count < entries.count {
                logger.error("Skipped \(entries.count - decoded.count) unreadable \(self.label, privacy: .public) entries")
                backUpCorruptFile()
            }
            return decoded
        } catch {
            logger.error("Could not read \(self.label, privacy: .public): \(error.localizedDescription, privacy: .public)")
            backUpCorruptFile()
            return []
        }
    }

    private func backUpCorruptFile() {
        let backupURL = fileURL.appendingPathExtension("bak")
        try? FileManager.default.removeItem(at: backupURL)
        try? FileManager.default.copyItem(at: fileURL, to: backupURL)
    }

    /// Decodes one array entry without failing the whole array.
    private struct Lossy: Decodable {
        let value: Element?
        init(from decoder: Decoder) throws {
            value = try? Element(from: decoder)
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
