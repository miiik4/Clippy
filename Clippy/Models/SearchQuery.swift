import Foundation

/// A parsed search string. Supports free text plus filter tokens:
/// `app:<name>` (source app, substring match) and
/// `type:text|image|file|link|color|pinned`.
struct SearchQuery: Equatable {
    enum Kind: String, CaseIterable {
        case text, image, file, link, color, pinned
    }

    var text = ""
    var app: String?
    var kinds: Set<Kind> = []

    init(_ raw: String) {
        var words: [String] = []
        for word in raw.split(whereSeparator: \.isWhitespace) {
            let lower = word.lowercased()
            if lower.hasPrefix("app:"), word.count > 4 {
                app = String(word.dropFirst(4))
            } else if lower.hasPrefix("type:"), let kind = Kind(rawValue: String(lower.dropFirst(5))) {
                kinds.insert(kind)
            } else {
                words.append(String(word))
            }
        }
        text = words.joined(separator: " ")
    }

    var isEmpty: Bool { text.isEmpty && app == nil && kinds.isEmpty }

    func matches(_ item: ClipboardItem) -> Bool {
        if let app {
            guard item.sourceAppName?.localizedCaseInsensitiveContains(app) == true else { return false }
        }
        if !kinds.isEmpty, !kinds.contains(where: { matches(item, kind: $0) }) {
            return false
        }
        guard !text.isEmpty else { return true }

        if item.title?.localizedCaseInsensitiveContains(text) == true { return true }
        switch item.contentType {
        case .text:
            // Never match against masked sensitive text: that would reveal
            // whether a guess matches a stored secret.
            guard !item.isSensitive else { return false }
            return item.textContent?.localizedCaseInsensitiveContains(text) ?? false
        case .image:
            return false
        case .file:
            return item.fileURLs?.contains { $0.path.localizedCaseInsensitiveContains(text) } ?? false
        }
    }

    private func matches(_ item: ClipboardItem, kind: Kind) -> Bool {
        switch kind {
        case .text: return item.contentType == .text
        case .image: return item.contentType == .image
        case .file: return item.contentType == .file
        case .link: return item.linkURL != nil
        case .color: return item.colorValue != nil
        case .pinned: return item.isPinned
        }
    }
}
