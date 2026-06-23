import AppKit
import Observation

/// Checks the GitHub releases API for a newer version of Clippy and exposes
/// the result for the menu bar to display.
@Observable
@MainActor
final class UpdateChecker {
    static let shared = UpdateChecker()

    /// The latest release available on GitHub, if it is newer than the running app.
    private(set) var availableUpdate: Update?

    nonisolated struct Update: Equatable, Sendable {
        let version: String
        let url: URL
    }

    private nonisolated let owner = "miiik4"
    private nonisolated let repo = "Clippy"
    private nonisolated let session = URLSession(configuration: .ephemeral)

    private nonisolated var apiURL: URL? {
        URL(string: "https://api.github.com/repos/\(owner)/\(repo)/releases/latest")
    }

    /// The running app's marketing version (e.g. "1.3.0").
    nonisolated var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    /// Fetches the latest release and updates `availableUpdate` if it is newer.
    nonisolated func checkForUpdates() {
        guard let apiURL else { return }

        var request = URLRequest(url: apiURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Clippy/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let current = currentVersion
        session.dataTask(with: request) { [weak self] data, _, _ in
            guard let self, let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tag = json["tag_name"] as? String,
                  let urlString = json["html_url"] as? String,
                  let url = URL(string: urlString)
            else { return }

            let latest = Self.normalize(tag)
            let update = Self.isVersion(latest, newerThan: current)
                ? Update(version: latest, url: url)
                : nil

            Task { @MainActor in
                self.availableUpdate = update
            }
        }.resume()
    }

    /// Opens the release page in the default browser.
    func openReleasePage() {
        guard let url = availableUpdate?.url else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: - Version comparison

    /// Strips a leading "v" and surrounding whitespace from a tag name.
    private nonisolated static func normalize(_ tag: String) -> String {
        var version = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        if version.hasPrefix("v") || version.hasPrefix("V") {
            version.removeFirst()
        }
        return version
    }

    /// Numeric, component-wise semantic version comparison (e.g. 1.10.0 > 1.9.0).
    nonisolated static func isVersion(_ lhs: String, newerThan rhs: String) -> Bool {
        let a = lhs.split(separator: ".").map { Int($0) ?? 0 }
        let b = rhs.split(separator: ".").map { Int($0) ?? 0 }
        let count = max(a.count, b.count)
        for i in 0..<count {
            let l = i < a.count ? a[i] : 0
            let r = i < b.count ? b[i] : 0
            if l != r { return l > r }
        }
        return false
    }
}
