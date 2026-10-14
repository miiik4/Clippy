import AppKit
import Foundation
import Testing
@testable import Clippy

// MARK: - Version comparison

struct UpdateCheckerTests {
    @Test(arguments: [
        ("1.10.0", "1.9.0", true),
        ("1.3.1", "1.3", true),
        ("1.3", "1.3.0", false),
        ("1.3.0", "1.3.1", false),
        ("2.0", "1.99.99", true),
    ])
    func versionComparison(lhs: String, rhs: String, expected: Bool) {
        #expect(UpdateChecker.isVersion(lhs, newerThan: rhs) == expected)
    }
}

// MARK: - Item content helpers

struct ClipboardItemTests {
    private func text(_ string: String, bundleID: String? = nil) -> ClipboardItem {
        ClipboardItem(contentType: .text, textContent: string, sourceAppName: nil, sourceAppBundleID: bundleID)
    }

    @Test func detectsLinks() {
        #expect(text("https://example.com/path?q=1").linkURL != nil)
        #expect(text("  http://example.com  ").linkURL != nil)
        #expect(text("see https://example.com").linkURL == nil)
        #expect(text("ftp://example.com").linkURL == nil)
        #expect(text("example.com").linkURL == nil)
    }

    @Test func parsesHexColors() throws {
        let red = try #require(ClipboardItem.parseHexColor("#FF0000"))
        #expect(abs(red.redComponent - 1) < 0.001 && red.greenComponent < 0.001)
        #expect(ClipboardItem.parseHexColor("#fff") != nil)
        #expect(ClipboardItem.parseHexColor("#11223344") != nil)
        #expect(ClipboardItem.parseHexColor("FF0000") == nil)
        #expect(ClipboardItem.parseHexColor("#GG0000") == nil)
        #expect(ClipboardItem.parseHexColor("#12345") == nil)
    }

    @Test func sameContentComparison() {
        #expect(text("a").hasSameContent(as: text("a")))
        #expect(!text("a").hasSameContent(as: text("b")))

        let imageA = ClipboardItem.image(fileName: "1.png", hash: "abc", sourceAppName: nil, sourceAppBundleID: nil)
        let imageB = ClipboardItem.image(fileName: "2.png", hash: "abc", sourceAppName: nil, sourceAppBundleID: nil)
        let imageC = ClipboardItem.image(fileName: "3.png", hash: "def", sourceAppName: nil, sourceAppBundleID: nil)
        #expect(imageA.hasSameContent(as: imageB))
        #expect(!imageA.hasSameContent(as: imageC))
        #expect(!imageA.hasSameContent(as: text("a")))
    }

    @Test func codableRoundTripKeepsNewFields() throws {
        var item = ClipboardItem(
            contentType: .text, textContent: "hello", rtfData: Data("{\\rtf1 hello}".utf8),
            sourceAppName: "Notes", sourceAppBundleID: "com.apple.Notes", title: "Greeting"
        )
        item.isPinned = true
        let decoded = try JSONDecoder().decode(ClipboardItem.self, from: JSONEncoder().encode(item))
        #expect(decoded.id == item.id)
        #expect(decoded.textContent == "hello")
        #expect(decoded.rtfData == item.rtfData)
        #expect(decoded.isPinned)
        #expect(decoded.title == "Greeting")
    }

    @Test func decodesLegacyEntriesWithoutNewFields() throws {
        let legacy = """
        {"id":"\(UUID().uuidString)","contentType":0,"textContent":"old","timestamp":0}
        """
        let decoded = try JSONDecoder().decode(ClipboardItem.self, from: Data(legacy.utf8))
        #expect(decoded.textContent == "old")
        #expect(!decoded.isPinned)
        #expect(decoded.title == nil)
    }
}

// MARK: - Search

struct SearchQueryTests {
    private func item(_ text: String, app: String? = nil, pinned: Bool = false, bundleID: String? = nil) -> ClipboardItem {
        ClipboardItem(contentType: .text, textContent: text, sourceAppName: app, sourceAppBundleID: bundleID, isPinned: pinned)
    }

    @Test func parsesFilterTokens() {
        let query = SearchQuery("foo app:Safari type:link bar")
        #expect(query.text == "foo bar")
        #expect(query.app == "Safari")
        #expect(query.kinds == [.link])
    }

    @Test func unknownTypeStaysInFreeText() {
        #expect(SearchQuery("type:banana").text == "type:banana")
    }

    @Test func filtersByAppTypeAndText() {
        let link = item("https://example.com", app: "Safari")
        let note = item("shopping list", app: "Notes", pinned: true)
        #expect(SearchQuery("app:safari").matches(link))
        #expect(!SearchQuery("app:safari").matches(note))
        #expect(SearchQuery("type:link").matches(link))
        #expect(!SearchQuery("type:link").matches(note))
        #expect(SearchQuery("type:pinned list").matches(note))
        #expect(!SearchQuery("type:pinned example").matches(link))
    }

    @Test func neverMatchesSensitiveText() {
        let secret = item("hunter2", bundleID: "com.1password.1password")
        #expect(!SearchQuery("hunter").matches(secret))
        #expect(SearchQuery("").matches(secret))
    }

    @Test func matchesSnippetTitles() {
        var snippet = item("long body")
        snippet.title = "Signature"
        #expect(SearchQuery("signa").matches(snippet))
    }
}

// MARK: - Pasteboard type preference

struct PasteboardPreferenceTests {
    @Test func prefersWhicheverTheAppListsFirst() {
        #expect(ClipboardMonitor.prefersImage(types: [.png]))
        #expect(ClipboardMonitor.prefersImage(types: [.tiff, .string]))
        #expect(!ClipboardMonitor.prefersImage(types: [.string, .rtf, .tiff]))
        #expect(!ClipboardMonitor.prefersImage(types: [.string]))
    }
}

// MARK: - Persistence

struct JSONFileStoreTests {
    private struct Entry: Codable, Equatable {
        let name: String
    }

    private func makeDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("ClippyTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test func skipsUnreadableEntriesAndBacksUpFile() throws {
        let dir = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("store.json")
        try Data(#"[{"name":"a"},{"wrong":1},{"name":"b"}]"#.utf8).write(to: file)

        let store = JSONFileStore<Entry>(fileName: "store.json", label: "test", directory: dir)
        #expect(store.load() == [Entry(name: "a"), Entry(name: "b")])
        #expect(FileManager.default.fileExists(atPath: file.appendingPathExtension("bak").path))
    }

    @Test func corruptFileIsBackedUp() throws {
        let dir = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("store.json")
        try Data("not json".utf8).write(to: file)

        let store = JSONFileStore<Entry>(fileName: "store.json", label: "test", directory: dir)
        #expect(store.load().isEmpty)
        let backup = try String(contentsOf: file.appendingPathExtension("bak"), encoding: .utf8)
        #expect(backup == "not json")
    }

    @Test func roundTrip() throws {
        let dir = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = JSONFileStore<Entry>(fileName: "store.json", label: "test", directory: dir)
        store.saveImmediately([Entry(name: "x")])
        #expect(store.load() == [Entry(name: "x")])
    }
}
