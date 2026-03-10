import SwiftUI

@main
struct Clippy_v2App: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("Clippy", systemImage: "paperclip") {
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

            SettingsLink()

            Divider()

            Button("Quit Clippy") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }

        Settings {
            SettingsView()
        }
    }
}
