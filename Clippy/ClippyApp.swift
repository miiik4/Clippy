import SwiftUI
import Carbon.HIToolbox

@main
struct ClippyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("Clippy", systemImage: "paperclip") {
            MenuBarContent(appDelegate: appDelegate)
        }

        Settings {
            SettingsView()
        }
    }
}

struct MenuBarContent: View {
    let appDelegate: AppDelegate
    @Environment(\.openSettings) private var openSettings
    @Bindable private var settings = AppSettings.shared
    @Bindable private var updateChecker = UpdateChecker.shared

    private var shortcutKey: KeyEquivalent {
        if let char = KeyCodeMap.character(for: settings.hotkeyCode) {
            return KeyEquivalent(char)
        }
        return "v"
    }

    private var shortcutModifiers: SwiftUI.EventModifiers {
        var mods: SwiftUI.EventModifiers = []
        if (settings.hotkeyModifiers & cmdKey) != 0 { mods.insert(.command) }
        if (settings.hotkeyModifiers & optionKey) != 0 { mods.insert(.option) }
        if (settings.hotkeyModifiers & controlKey) != 0 { mods.insert(.control) }
        if (settings.hotkeyModifiers & shiftKey) != 0 { mods.insert(.shift) }
        return mods
    }

    var body: some View {
        if let update = updateChecker.availableUpdate {
            Button("New version \(update.version) is available\u{2026}") {
                updateChecker.openReleasePage()
            }

            Divider()
        }

        Button("Show Clipboard History") {
            appDelegate.showPanel()
        }
        .keyboardShortcut(shortcutKey, modifiers: shortcutModifiers)

        Divider()

        Menu("Clear History") {
            Button("Last 5 Minutes") {
                appDelegate.clearLast5Min()
            }
            Button("Last 15 Minutes") {
                appDelegate.clearLast15Min()
            }
            Divider()
            Button("All History") {
                appDelegate.clearHistory()
            }
        }

        Divider()

        Button("Settings\u{2026}") {
            NSApp.activate(ignoringOtherApps: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                openSettings()
            }
        }
        .keyboardShortcut(",", modifiers: .command)

        Divider()

        Button("Quit Clippy") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
