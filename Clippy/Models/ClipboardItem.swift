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

    var previewText: String {
        switch contentType {
        case .text:
            return textContent ?? ""
        case .image:
            return "Image"
        }
    }

    var image: NSImage? {
        guard let data = imageData else { return nil }
        return NSImage(data: data)
    }

    var wordCount: Int {
        guard let text = textContent else { return 0 }
        return text.split(whereSeparator: { $0.isWhitespace }).count
    }

    var charCount: Int {
        return textContent?.count ?? 0
    }

    var relativeTimeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }

    var sourceAppIcon: NSImage? {
        guard let bundleID = sourceAppBundleID,
              let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return nil
        }
        return NSWorkspace.shared.icon(forFile: appURL.path)
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
