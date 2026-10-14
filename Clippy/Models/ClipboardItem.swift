import Foundation
import AppKit

enum ClipboardContentType: Int, Codable {
    case text
    case image
    case file
}

struct ClipboardItem: Identifiable, Codable {
    let id: UUID
    let contentType: ClipboardContentType
    var textContent: String?
    /// Rich-text representations captured alongside the plain string, so a
    /// normal paste keeps formatting. Never captured for sensitive items.
    var rtfData: Data?
    var htmlData: Data?
    let imageFileName: String?
    /// SHA-256 of the stored PNG, used to detect re-copies of the same image.
    let imageHash: String?
    let fileURLs: [URL]?
    var timestamp: Date
    let sourceAppName: String?
    let sourceAppBundleID: String?
    var isPinned: Bool
    /// Optional user-given name (snippets).
    var title: String?

    /// Ciphertext that could not be decrypted at load time (e.g. the Keychain
    /// key was unavailable). Written back unchanged so it is never lost.
    private var undecryptableCipher: String?

    init(
        id: UUID = UUID(),
        contentType: ClipboardContentType,
        textContent: String? = nil,
        rtfData: Data? = nil,
        htmlData: Data? = nil,
        imageFileName: String? = nil,
        imageHash: String? = nil,
        fileURLs: [URL]? = nil,
        timestamp: Date = Date(),
        sourceAppName: String?,
        sourceAppBundleID: String?,
        isPinned: Bool = false,
        title: String? = nil
    ) {
        self.id = id
        self.contentType = contentType
        self.textContent = textContent
        self.rtfData = rtfData
        self.htmlData = htmlData
        self.imageFileName = imageFileName
        self.imageHash = imageHash
        self.fileURLs = fileURLs
        self.timestamp = timestamp
        self.sourceAppName = sourceAppName
        self.sourceAppBundleID = sourceAppBundleID
        self.isPinned = isPinned
        self.title = title
    }

    private enum CodingKeys: String, CodingKey {
        case id, contentType, textContent, textEncrypted, rtfData, htmlData, imageFileName, imageHash, imageData,
             fileURLs, timestamp, sourceAppName, sourceAppBundleID, isPinned, title
    }

    /// Custom decoder that migrates legacy entries which stored image bytes
    /// inline under `imageData` into standalone files via `ImageStore`.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        contentType = try c.decode(ClipboardContentType.self, forKey: .contentType)
        timestamp = try c.decode(Date.self, forKey: .timestamp)

        let storedText = try c.decodeIfPresent(String.self, forKey: .textContent)
        let isEncrypted = try c.decodeIfPresent(Bool.self, forKey: .textEncrypted) ?? false
        if isEncrypted, let storedText {
            // Decrypt back to plaintext for in-memory use. If the key is
            // unavailable, keep the ciphertext so the next save preserves it.
            textContent = HistoryCrypto.shared.decrypt(storedText)
            undecryptableCipher = textContent == nil ? storedText : nil
        } else {
            textContent = storedText
            undecryptableCipher = nil
        }
        rtfData = try c.decodeIfPresent(Data.self, forKey: .rtfData)
        htmlData = try c.decodeIfPresent(Data.self, forKey: .htmlData)
        imageHash = try c.decodeIfPresent(String.self, forKey: .imageHash)
        fileURLs = try c.decodeIfPresent([URL].self, forKey: .fileURLs)
        sourceAppName = try c.decodeIfPresent(String.self, forKey: .sourceAppName)
        sourceAppBundleID = try c.decodeIfPresent(String.self, forKey: .sourceAppBundleID)
        isPinned = try c.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        title = try c.decodeIfPresent(String.self, forKey: .title)

        if let name = try c.decodeIfPresent(String.self, forKey: .imageFileName) {
            imageFileName = name
        } else if let legacy = try c.decodeIfPresent(Data.self, forKey: .imageData) {
            imageFileName = ImageStore.shared.write(legacy)
        } else {
            imageFileName = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(contentType, forKey: .contentType)

        if let text = textContent {
            if isSensitive {
                // Sensitive text is only ever written encrypted. If no key is
                // available the text is dropped rather than stored in plaintext.
                if let cipher = HistoryCrypto.shared.encrypt(text) {
                    try c.encode(cipher, forKey: .textContent)
                    try c.encode(true, forKey: .textEncrypted)
                }
            } else {
                try c.encode(text, forKey: .textContent)
            }
        } else if let undecryptableCipher {
            try c.encode(undecryptableCipher, forKey: .textContent)
            try c.encode(true, forKey: .textEncrypted)
        }

        if !isSensitive {
            try c.encodeIfPresent(rtfData, forKey: .rtfData)
            try c.encodeIfPresent(htmlData, forKey: .htmlData)
        }
        try c.encodeIfPresent(imageFileName, forKey: .imageFileName)
        try c.encodeIfPresent(imageHash, forKey: .imageHash)
        try c.encodeIfPresent(fileURLs, forKey: .fileURLs)
        try c.encode(timestamp, forKey: .timestamp)
        try c.encodeIfPresent(sourceAppName, forKey: .sourceAppName)
        try c.encodeIfPresent(sourceAppBundleID, forKey: .sourceAppBundleID)
        if isPinned { try c.encode(true, forKey: .isPinned) }
        try c.encodeIfPresent(title, forKey: .title)
    }

    var isSensitive: Bool {
        guard let bundleID = sourceAppBundleID else { return false }
        return AppSettings.sensitiveAppBundleIDs.contains(bundleID)
    }

    var hasRichText: Bool { rtfData != nil || htmlData != nil }

    var previewText: String {
        switch contentType {
        case .text:
            if isSensitive {
                return "\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}\u{2022}"
            }
            return textContent ?? ""
        case .image:
            return "Image"
        case .file:
            return fileNames.joined(separator: ", ")
        }
    }

    var fileNames: [String] {
        (fileURLs ?? []).map { $0.lastPathComponent }
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

    /// The URL when the text is a single http(s) link.
    var linkURL: URL? {
        guard contentType == .text, !isSensitive,
              let text = textContent?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.contains(where: \.isWhitespace),
              let url = URL(string: text),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              url.host != nil else { return nil }
        return url
    }

    /// The color when the text is a hex color such as `#1E90FF` or `#fff`.
    var colorValue: NSColor? {
        guard contentType == .text, !isSensitive,
              let text = textContent?.trimmingCharacters(in: .whitespacesAndNewlines) else { return nil }
        return Self.parseHexColor(text)
    }

    static func parseHexColor(_ text: String) -> NSColor? {
        guard text.hasPrefix("#") else { return nil }
        var hex = String(text.dropFirst())
        guard [3, 6, 8].contains(hex.count), hex.allSatisfy(\.isHexDigit) else { return nil }
        if hex.count == 3 { hex = hex.map { "\($0)\($0)" }.joined() }
        guard let value = UInt64(hex, radix: 16) else { return nil }
        let hasAlpha = hex.count == 8
        let r = CGFloat((value >> (hasAlpha ? 24 : 16)) & 0xFF) / 255
        let g = CGFloat((value >> (hasAlpha ? 16 : 8)) & 0xFF) / 255
        let b = CGFloat((value >> (hasAlpha ? 8 : 0)) & 0xFF) / 255
        let a = hasAlpha ? CGFloat(value & 0xFF) / 255 : 1
        return NSColor(srgbRed: r, green: g, blue: b, alpha: a)
    }

    /// True when both items hold the same content, regardless of id or time.
    func hasSameContent(as other: ClipboardItem) -> Bool {
        guard contentType == other.contentType else { return false }
        switch contentType {
        case .text:
            return textContent != nil && textContent == other.textContent
        case .image:
            if let imageHash, let otherHash = other.imageHash { return imageHash == otherHash }
            return imageFileName == other.imageFileName
        case .file:
            return fileURLs == other.fileURLs
        }
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

    static func text(_ string: String, rtfData: Data? = nil, htmlData: Data? = nil, sourceApp: NSRunningApplication? = nil) -> ClipboardItem {
        ClipboardItem(
            contentType: .text,
            textContent: string,
            rtfData: rtfData,
            htmlData: htmlData,
            sourceAppName: sourceApp?.localizedName,
            sourceAppBundleID: sourceApp?.bundleIdentifier
        )
    }

    static func image(fileName: String, hash: String?, sourceAppName: String?, sourceAppBundleID: String?) -> ClipboardItem {
        ClipboardItem(
            contentType: .image,
            imageFileName: fileName,
            imageHash: hash,
            sourceAppName: sourceAppName,
            sourceAppBundleID: sourceAppBundleID
        )
    }

    static func files(_ urls: [URL], sourceApp: NSRunningApplication? = nil) -> ClipboardItem {
        ClipboardItem(
            contentType: .file,
            fileURLs: urls,
            sourceAppName: sourceApp?.localizedName,
            sourceAppBundleID: sourceApp?.bundleIdentifier
        )
    }
}
