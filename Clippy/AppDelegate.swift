import AppKit
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {
    let clipboardMonitor = ClipboardMonitor()
    private let hotkeyManager = HotkeyManager()
    private var panelController: ClipboardPanelController?
    private var cancellables = Set<AnyCancellable>()
    private var updateTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // When hosting unit tests, don't record the clipboard, register the
        // hotkey or touch the user's saved history.
        if Self.isRunningTests { return }

        panelController = ClipboardPanelController(clipboardMonitor: clipboardMonitor)

        hotkeyManager.onHotkey = { [weak self] in
            self?.panelController?.toggle()
        }
        registerHotkey()

        // Re-register only when the hotkey itself changes
        NotificationCenter.default.publisher(for: .clippyHotkeyChanged)
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.registerHotkey()
            }
            .store(in: &cancellables)

        clipboardMonitor.start()

        // Prompt for Accessibility permission (needed for paste simulation)
        PasteService.requestAccessibilityPermission()

        // Check for app updates on launch, then every 6 hours.
        UpdateNotifier.shared.start()
        UpdateChecker.shared.checkForUpdates()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 6 * 60 * 60, repeats: true) { _ in
            Task { @MainActor in
                UpdateChecker.shared.checkForUpdates()
            }
        }
    }

    private static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || NSClassFromString("XCTestCase") != nil
    }

    func applicationWillTerminate(_ notification: Notification) {
        if Self.isRunningTests { return }
        clipboardMonitor.stop()
        hotkeyManager.unregister()
        updateTimer?.invalidate()
    }

    private func registerHotkey() {
        let success = hotkeyManager.register()
        AppSettings.shared.hotkeyRegistrationFailed = !success
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

    func pauseRecording(for duration: TimeInterval?) {
        clipboardMonitor.pause(for: duration)
    }

    func skipNextCopy() {
        clipboardMonitor.skipNextCopy()
    }

    func resumeRecording() {
        clipboardMonitor.resume()
    }
}
