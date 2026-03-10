import Foundation

struct ClipboardStore {
    private let fileURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("Clippy", isDirectory: true)
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        fileURL = appDir.appendingPathComponent("clipboard_history.json")
    }

    func save(_ items: [ClipboardItem]) {
        do {
            let data = try JSONEncoder().encode(items)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("Failed to save clipboard history: \(error)")
        }
    }

    func load() -> [ClipboardItem] {
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode([ClipboardItem].self, from: data)
        } catch {
            return []
        }
    }
}
