import SwiftUI
import Carbon.HIToolbox

@main
struct ClippyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent(appDelegate: appDelegate, monitor: appDelegate.clipboardMonitor)
        } label: {
            MenuBarIcon(monitor: appDelegate.clipboardMonitor)
        }

        Settings {
            SettingsView(monitor: appDelegate.clipboardMonitor)
        }
    }
}

/// Paperclip icon, with a pause badge while recording is paused.
struct MenuBarIcon: View {
    let monitor: ClipboardMonitor

    var body: some View {
        Image(systemName: monitor.isPaused ? "pause.circle" : "paperclip")
    }
}

struct MenuBarContent: View {
    let appDelegate: AppDelegate
    let monitor: ClipboardMonitor
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

    private var pauseStatus: String {
        if let until = monitor.pausedUntil, until != .distantFuture {
            return "Resume Recording (paused until \(until.formatted(date: .omitted, time: .shortened)))"
        }
        if monitor.pausedUntil == nil {
            return "Resume Recording (skipping next copy)"
        }
        return "Resume Recording"
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

        if monitor.isPaused {
            Button(pauseStatus) {
                appDelegate.resumeRecording()
            }
        } else {
            Menu("Pause Recording") {
                Button("For the Next Copy") {
                    appDelegate.skipNextCopy()
                }
                Button("For 5 Minutes") {
                    appDelegate.pauseRecording(for: 5 * 60)
                }
                Button("For 1 Hour") {
                    appDelegate.pauseRecording(for: 60 * 60)
                }
                Divider()
                Button("Until Resumed") {
                    appDelegate.pauseRecording(for: nil)
                }
            }
        }

        Divider()

        Menu("Clear History") {
            Button("Last 5 Minutes") {
                appDelegate.clearLast5Min()
            }
            Button("Last 15 Minutes") {
                appDelegate.clearLast15Min()
            }
            Divider()
            Button("All Unpinned History") {
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
