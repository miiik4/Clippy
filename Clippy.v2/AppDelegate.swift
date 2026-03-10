import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let clipboardMonitor = ClipboardMonitor()
    private let hotkeyManager = HotkeyManager()
    private var panelController: ClipboardPanelController?
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()

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

    // MARK: - Menu Bar

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "paperclip", accessibilityDescription: "Clippy")
        }

        let menu = NSMenu()
        menu.addItem(withTitle: "Show Clipboard History", action: #selector(showPanel), keyEquivalent: "")
            .target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Clear History", action: #selector(clearHistory), keyEquivalent: "")
            .target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Clippy", action: #selector(quitApp), keyEquivalent: "q")
            .target = self

        statusItem?.menu = menu
    }

    @objc private func showPanel() {
        panelController?.show()
    }

    @objc private func clearHistory() {
        clipboardMonitor.clearAll()
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
