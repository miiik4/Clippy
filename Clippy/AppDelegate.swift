import AppKit
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let clipboardMonitor = ClipboardMonitor()
    private let hotkeyManager = HotkeyManager()
    private var panelController: ClipboardPanelController?
    private var cancellables = Set<AnyCancellable>()
    private var updateTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        panelController = ClipboardPanelController(clipboardMonitor: clipboardMonitor)

        hotkeyManager.onHotkey = { [weak self] in
            self?.panelController?.toggle()
        }
        hotkeyManager.register()

        // Re-register hotkey when settings change
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.hotkeyManager.register()
            }
            .store(in: &cancellables)

        clipboardMonitor.start()

        // Prompt for Accessibility permission (needed for paste simulation)
        PasteService.requestAccessibilityPermission()

        // Check for app updates on launch, then every 6 hours.
        UpdateChecker.shared.checkForUpdates()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 6 * 60 * 60, repeats: true) { _ in
            Task { @MainActor in
                UpdateChecker.shared.checkForUpdates()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        clipboardMonitor.stop()
        hotkeyManager.unregister()
        updateTimer?.invalidate()
    }

    // MARK: - Actions (called from MenuBarExtra)

    func showPanel() {
        panelController?.show()
    }

    func clearLast5Min() {
        clipboardMonitor.clearItems(inLastMinutes: 5)
    }

    func clearLast15Min() {
        clipboardMonitor.clearItems(inLastMinutes: 15)
    }

    func clearHistory() {
        clipboardMonitor.clearAll()
    }
}
