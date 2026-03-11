import SwiftUI

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

    var body: some View {
        Button("Show Clipboard History") {
            appDelegate.showPanel()
        }
        .keyboardShortcut("c", modifiers: [.option, .command])

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
