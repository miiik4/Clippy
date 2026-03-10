import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let clipboardMonitor = ClipboardMonitor()
    private let hotkeyManager = HotkeyManager()
    private var panelController: ClipboardPanelController?
    func applicationDidFinishLaunching(_ notification: Notification) {
        panelController = ClipboardPanelController(clipboardMonitor: clipboardMonitor)

        hotkeyManager.onHotkey = { [weak self] in
            self?.panelController?.toggle()
        }
        hotkeyManager.register()

        clipboardMonitor.start()

        // Prompt for Accessibility permission (needed for paste simulation)
        PasteService.requestAccessibilityPermission()
    }

    func applicationWillTerminate(_ notification: Notification) {
        clipboardMonitor.stop()
        hotkeyManager.unregister()
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
