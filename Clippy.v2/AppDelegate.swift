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

        // Clear submenu
        let clearMenu = NSMenu()
        let clear5 = NSMenuItem(title: "Last 5 Minutes", action: #selector(clearLast5Min), keyEquivalent: "")
        clear5.target = self
        clearMenu.addItem(clear5)
        let clear15 = NSMenuItem(title: "Last 15 Minutes", action: #selector(clearLast15Min), keyEquivalent: "")
        clear15.target = self
        clearMenu.addItem(clear15)
        clearMenu.addItem(.separator())
        let clearAll = NSMenuItem(title: "All History", action: #selector(clearHistory), keyEquivalent: "")
        clearAll.target = self
        clearMenu.addItem(clearAll)

        let clearItem = NSMenuItem(title: "Clear History", action: nil, keyEquivalent: "")
        clearItem.submenu = clearMenu
        menu.addItem(clearItem)

        menu.addItem(.separator())

        menu.addItem(withTitle: "Settings\u{2026}", action: #selector(openSettings), keyEquivalent: ",")
            .target = self

        menu.addItem(.separator())

        menu.addItem(withTitle: "Quit Clippy", action: #selector(quitApp), keyEquivalent: "q")
            .target = self

        statusItem?.menu = menu
    }

    // MARK: - Actions

    @objc private func showPanel() {
        panelController?.show()
    }

    @objc private func clearLast5Min() {
        clipboardMonitor.clearItems(inLastMinutes: 5)
    }

    @objc private func clearLast15Min() {
        clipboardMonitor.clearItems(inLastMinutes: 15)
    }

    @objc private func clearHistory() {
        clipboardMonitor.clearAll()
    }

    @objc private func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
