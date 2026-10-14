import Foundation
import CryptoKit

/// Stores clipboard image bytes as individual files on disk, keyed by filename,
/// so the history/snippet JSON stays small and text-only.
nonisolated final class ImageStore: @unchecked Sendable {
    static let shared = ImageStore()

    private let directory: URL
    private let io = DispatchQueue(label: "com.clippy.imagestore", qos: .utility)

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        directory = appSupport.appendingPathComponent("Clippy/Images", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func url(for fileName: String) -> URL {
        directory.appendingPathComponent(fileName)
    }

    func data(for fileName: String) -> Data? {
        try? Data(contentsOf: url(for: fileName))
    }

    /// Writes image bytes to a new file and returns its name, or nil if the
    /// write failed. Synchronous — call from a background queue when on a
    /// hot path.
    @discardableResult
    func write(_ data: Data) -> String? {
        let name = UUID().uuidString + ".png"
        do {
            try data.write(to: url(for: name), options: .atomic)
            return name
        } catch {
            return nil
        }
    }

    /// Hex SHA-256 of image bytes, used to recognise re-copies of an image.
    static func hash(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    /// Duplicates an existing image file so the copy can be owned independently.
    func copy(_ fileName: String) -> String? {
        guard let data = data(for: fileName) else { return nil }
        return write(data)
    }

    func delete(_ fileName: String) {
        let url = url(for: fileName)
        io.async { try? FileManager.default.removeItem(at: url) }
    }

    /// Deletes any image file not present in `referenced`, removing files
    /// orphaned by a crash between writing the image and persisting its
    /// reference. Runs off the main thread.
    func pruneUnreferenced(keeping referenced: Set<String>) {
        let directory = directory
        io.async {
            guard let names = try? FileManager.default.contentsOfDirectory(atPath: directory.path) else { return }
            for name in names where !referenced.contains(name) {
                try? FileManager.default.removeItem(at: directory.appendingPathComponent(name))
            }
        }
    }
}
