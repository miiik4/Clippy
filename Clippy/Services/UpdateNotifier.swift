import AppKit
import UserNotifications

/// Posts a macOS notification the first time a new version is found.
/// Permission is requested only then, so users are not prompted at launch.
final class UpdateNotifier: NSObject, UNUserNotificationCenterDelegate {
    static let shared = UpdateNotifier()

    private static let lastNotifiedKey = "lastNotifiedUpdateVersion"
    private nonisolated static let urlKey = "releaseURL"

    private var center: UNUserNotificationCenter { .current() }

    /// Installs the delegate so clicking a notification opens the release page.
    func start() {
        center.delegate = self
    }

    /// Notifies about `update` unless disabled or already notified for this version.
    func notifyIfNeeded(_ update: UpdateChecker.Update) {
        guard AppSettings.shared.notifyAboutUpdates,
              UserDefaults.standard.string(forKey: Self.lastNotifiedKey) != update.version else { return }

        let content = UNMutableNotificationContent()
        content.title = "Clippy \(update.version) is available"
        content.body = "Click to see what's new and download it."
        content.userInfo = [Self.urlKey: update.url.absoluteString]
        let request = UNNotificationRequest(identifier: "update-\(update.version)", content: content, trigger: nil)

        let center = center
        Task {
            guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return }
            do {
                try await center.add(request)
                UserDefaults.standard.set(update.version, forKey: Self.lastNotifiedKey)
            } catch {
                // Not marked as notified, so the next check tries again.
            }
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let urlString = response.notification.request.content.userInfo[Self.urlKey] as? String
        if let urlString, let url = URL(string: urlString) {
            DispatchQueue.main.async {
                NSWorkspace.shared.open(url)
            }
        }
        completionHandler()
    }

    /// Show the banner even while Clippy's panel is the key window.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
