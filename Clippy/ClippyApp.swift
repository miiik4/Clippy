import SwiftUI
import Carbon.HIToolbox

func characterFrom(keyCode: Int) -> Character? {
    switch keyCode {
    case kVK_ANSI_A: return "a"
    case kVK_ANSI_B: return "b"
    case kVK_ANSI_C: return "c"
    case kVK_ANSI_D: return "d"
    case kVK_ANSI_E: return "e"
    case kVK_ANSI_F: return "f"
    case kVK_ANSI_G: return "g"
    case kVK_ANSI_H: return "h"
    case kVK_ANSI_I: return "i"
    case kVK_ANSI_J: return "j"
    case kVK_ANSI_K: return "k"
    case kVK_ANSI_L: return "l"
    case kVK_ANSI_M: return "m"
    case kVK_ANSI_N: return "n"
    case kVK_ANSI_O: return "o"
    case kVK_ANSI_P: return "p"
    case kVK_ANSI_Q: return "q"
    case kVK_ANSI_R: return "r"
    case kVK_ANSI_S: return "s"
    case kVK_ANSI_T: return "t"
    case kVK_ANSI_U: return "u"
    case kVK_ANSI_V: return "v"
    case kVK_ANSI_W: return "w"
    case kVK_ANSI_X: return "x"
    case kVK_ANSI_Y: return "y"
    case kVK_ANSI_Z: return "z"
    case kVK_ANSI_0: return "0"
    case kVK_ANSI_1: return "1"
    case kVK_ANSI_2: return "2"
    case kVK_ANSI_3: return "3"
    case kVK_ANSI_4: return "4"
    case kVK_ANSI_5: return "5"
    case kVK_ANSI_6: return "6"
    case kVK_ANSI_7: return "7"
    case kVK_ANSI_8: return "8"
    case kVK_ANSI_9: return "9"
    default: return nil
    }
}

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
        if let char = characterFrom(keyCode: settings.hotkeyCode) {
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
