import Foundation
import AppKit

enum ClipboardContentType: Int, Codable {
    case text
    case image
}

struct ClipboardItem: Identifiable, Codable {
    let id: UUID
    let contentType: ClipboardContentType
    let textContent: String?
    let imageData: Data?
    let timestamp: Date
    let sourceAppName: String?
    let sourceAppBundleID: String?

    var isSensitive: Bool {
        guard let bundleID = sourceAppBundleID else { return false }
        return AppSettings.sensitiveAppBundleIDs.contains(bundleID)
    }

    var previewText: String {
        switch contentType {
        case .text:
            if isSensitive {
                return "\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}"
            }
            return textContent ?? ""
        case .image:
            return "Image"
        }
    }

    var image: NSImage? {
        ImageCache.shared.image(for: self)
    }

    var wordCount: Int {
        guard let text = textContent else { return 0 }
        return text.split(whereSeparator: { $0.isWhitespace }).count
    }

    var charCount: Int {
        return textContent?.count ?? 0
    }

    private static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()

    var relativeTimeString: String {
        Self.relativeDateFormatter.localizedString(for: timestamp, relativeTo: Date())
    }

    var sourceAppIcon: NSImage? {
        guard let bundleID = sourceAppBundleID else { return nil }
        return ImageCache.shared.appIcon(for: bundleID)
    }

    static func text(_ string: String, sourceApp: NSRunningApplication? = nil) -> ClipboardItem {
        ClipboardItem(
            id: UUID(),
            contentType: .text,
            textContent: string,
            imageData: nil,
            timestamp: Date(),
            sourceAppName: sourceApp?.localizedName,
            sourceAppBundleID: sourceApp?.bundleIdentifier
        )
    }

    static func image(_ data: Data, sourceApp: NSRunningApplication? = nil) -> ClipboardItem {
        ClipboardItem(
            id: UUID(),
            contentType: .image,
            textContent: nil,
            imageData: data,
            timestamp: Date(),
            sourceAppName: sourceApp?.localizedName,
            sourceAppBundleID: sourceApp?.bundleIdentifier
        )
    }
}
