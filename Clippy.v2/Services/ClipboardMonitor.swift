import AppKit
import Observation

@Observable
final class ClipboardMonitor {
    var items: [ClipboardItem] = []

    private var timer: Timer?
    private var lastChangeCount: Int = 0
    private let store = ClipboardStore()
    private let maxItems = 200
    private var ignoreNextChange = false

    init() {
        items = store.load()
        lastChangeCount = NSPasteboard.general.changeCount
    }

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func filteredItems(searchText: String) -> [ClipboardItem] {
        guard !searchText.isEmpty else { return items }
        return items.filter { item in
            switch item.contentType {
            case .text:
                return item.textContent?.localizedCaseInsensitiveContains(searchText) ?? false
            case .image:
                return "image".localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    func deleteItem(_ item: ClipboardItem) {
        items.removeAll { $0.id == item.id }
        store.save(items)
    }

    func clearAll() {
        items.removeAll()
        store.save(items)
    }

    func setIgnoreNextChange() {
        ignoreNextChange = true
    }

    private func checkClipboard() {
        let pasteboard = NSPasteboard.general
        let currentCount = pasteboard.changeCount

        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount

        if ignoreNextChange {
            ignoreNextChange = false
            return
        }

        let sourceApp = NSWorkspace.shared.frontmostApplication

        // Check for image first
        if let imageData = pasteboard.data(forType: .tiff) ?? pasteboard.data(forType: .png) {
            if let bitmapRep = NSBitmapImageRep(data: imageData),
               let pngData = bitmapRep.representation(using: .png, properties: [.compressionFactor: 0.8]) {
                let item = ClipboardItem.image(pngData, sourceApp: sourceApp)
                insertItem(item)
            }
        } else if let string = pasteboard.string(forType: .string), !string.isEmpty {
            // Avoid duplicate consecutive text
            if let lastText = items.first?.textContent, lastText == string {
                return
            }
            let item = ClipboardItem.text(string, sourceApp: sourceApp)
            insertItem(item)
        }
    }

    private func insertItem(_ item: ClipboardItem) {
        items.insert(item, at: 0)
        if items.count > maxItems {
            items = Array(items.prefix(maxItems))
        }
        store.save(items)
    }
}
