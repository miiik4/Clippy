import SwiftUI
import ServiceManagement
import Carbon.HIToolbox
import UniformTypeIdentifiers

struct HotkeyRecorder: NSViewRepresentable {
    @Binding var keyCode: Int
    @Binding var modifiers: Int

    class Coordinator: NSObject {
        var parent: HotkeyRecorder

        init(_ parent: HotkeyRecorder) {
            self.parent = parent
        }

        @objc func handleKeyDown(_ event: NSEvent) {
            let forbiddenKeys = [kVK_Escape, kVK_Return, kVK_Tab, kVK_Space]
            if forbiddenKeys.contains(Int(event.keyCode)) {
                return
            }
            
            // Require ⌘, ⌥ or ⌃. Shift alone, Caps Lock, fn and the numeric-pad
            // flag (set on arrow keys) would otherwise let a bare key through
            // and swallow it system-wide.
            let mods = event.modifierFlags.intersection([.command, .option, .control])
            if mods.isEmpty { return }

            parent.keyCode = Int(event.keyCode)
            parent.modifiers = carbonModifiers(from: event.modifierFlags)
        }

        private func carbonModifiers(from nseventModifiers: NSEvent.ModifierFlags) -> Int {
            var carbonMods = 0
            if nseventModifiers.contains(.command) { carbonMods |= cmdKey }
            if nseventModifiers.contains(.option) { carbonMods |= optionKey }
            if nseventModifiers.contains(.control) { carbonMods |= controlKey }
            if nseventModifiers.contains(.shift) { carbonMods |= shiftKey }
            return carbonMods
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSView {
        let view = HotkeyNSView()
        view.onKeyDown = context.coordinator.handleKeyDown
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    class HotkeyNSView: NSView {
        var onKeyDown: ((NSEvent) -> Void)?

        override var acceptsFirstResponder: Bool { true }

        override func keyDown(with event: NSEvent) {
            onKeyDown?(event)
        }
    }
}

func readableModifiers(_ modifiers: Int) -> String {
    var result = ""
    if (modifiers & controlKey) != 0 { result += "\u{2303}" }
    if (modifiers & shiftKey) != 0 { result += "\u{21E7}" }
    if (modifiers & optionKey) != 0 { result += "\u{2325}" }
    if (modifiers & cmdKey) != 0 { result += "\u{2318}" }
    return result
}

func readableKey(_ keyCode: Int) -> String {
    KeyCodeMap.displayName(for: keyCode)
}

struct InstalledApp: Identifiable, Comparable, Sendable {
    let id: String // bundleID
    let name: String

    static func < (lhs: InstalledApp, rhs: InstalledApp) -> Bool {
        lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }

    nonisolated static func loadAll() -> [InstalledApp] {
        var result: [InstalledApp] = []
        var seen = Set<String>()

        // Scan the standard Applications folders for installed apps.
        let fileManager = FileManager.default
        let searchPaths = [
            "/Applications",
            "/System/Applications",
            "/System/Applications/Utilities",
            NSHomeDirectory() + "/Applications",
        ]

        for searchPath in searchPaths {
            guard let contents = try? fileManager.contentsOfDirectory(
                at: URL(fileURLWithPath: searchPath),
                includingPropertiesForKeys: nil
            ) else { continue }

            for url in contents where url.pathExtension == "app" {
                guard let bundle = Bundle(url: url),
                      let bundleID = bundle.bundleIdentifier,
                      !seen.contains(bundleID) else { continue }
                seen.insert(bundleID)
                let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                    ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
                    ?? url.deletingPathExtension().lastPathComponent
                result.append(InstalledApp(id: bundleID, name: name))
            }
        }

        return result.sorted()
    }
}

struct SettingsView: View {
    let monitor: ClipboardMonitor
    @Bindable private var settings = AppSettings.shared
    @State private var launchAtLogin = false
    @State private var installedApps: [InstalledApp] = []
    @State private var selectedAppID = ""
    @State private var snippetTransferMessage: String?

    private var availableApps: [InstalledApp] {
        installedApps.filter { !settings.ignoredAppBundleIDs.contains($0.id) }
    }

    var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            ignoredAppsTab
                .tabItem {
                    Label("Ignored Apps", systemImage: "shield.lefthalf.filled")
                }
        }
        .frame(width: 460, height: 520)
        .task {
            installedApps = await Task.detached { InstalledApp.loadAll() }.value
        }
    }

    // MARK: - General Tab

    private var generalTab: some View {
        Form {
            Section("Startup") {
                Toggle("Launch Clippy at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        do {
                            if newValue {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            launchAtLogin = !newValue
                        }
                    }
            }

            Section("History") {
                Picker("Keep clipboard history for", selection: $settings.retentionPeriod) {
                    ForEach(RetentionPeriod.allCases, id: \.self) { period in
                        Text(period.displayName).tag(period)
                    }
                }
                .pickerStyle(.radioGroup)

                Picker("Maximum history items", selection: $settings.maxHistoryItems) {
                    ForEach(AppSettings.historyLimitOptions, id: \.self) { limit in
                        Text("\(limit)").tag(limit)
                    }
                }
                Text("Pinned items (\u{2318}P) are kept regardless of age or this limit.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Snippets") {
                HStack {
                    Button("Export Snippets\u{2026}") { exportSnippets() }
                    Button("Import Snippets\u{2026}") { importSnippets() }
                }
                Text(snippetTransferMessage ?? "Exports text snippets and their names as JSON. Image snippets are not exported.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Global Hotkey") {
                HStack {
                    Text("Toggle Clippy")
                    Spacer()
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(nsColor: .controlBackgroundColor))
                            .frame(width: 120, height: 28)
                        
                        HotkeyRecorder(keyCode: $settings.hotkeyCode, modifiers: $settings.hotkeyModifiers)
                            .frame(width: 120, height: 28)
                        
                        Text(readableModifiers(settings.hotkeyModifiers) + readableKey(settings.hotkeyCode))
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .allowsHitTesting(false)
                    }
                }
                if settings.hotkeyRegistrationFailed {
                    Label("This shortcut is unavailable — it may be in use by another app. Try a different combination.", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                } else {
                    Text("Click the box and press your desired shortcut.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Clipboard Merging") {
                Toggle("Enable merge on rapid copy", isOn: $settings.isMergeEnabled)

                if settings.isMergeEnabled {
                    HStack {
                        Text("Merge window")
                        Slider(value: $settings.mergeWindowSeconds, in: 0.5...2.0, step: 0.25)
                        Text("\(settings.mergeWindowSeconds, specifier: "%.2g")s")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                            .frame(width: 30, alignment: .trailing)
                    }
                    Text("Copies made within this window are appended instead of creating a new entry.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Updates") {
                Toggle("Notify me when an update is available", isOn: $settings.notifyAboutUpdates)
                Text("You're running Clippy \(UpdateChecker.shared.currentVersion). New versions also appear in the menu bar menu.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Privacy") {
                Text("Clippy automatically ignores concealed data (e.g. password fields) and transient content marked by apps. Recording can be paused from the menu bar.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Shortcuts") {
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                    shortcutRow("Toggle Clippy", shortcut: readableModifiers(settings.hotkeyModifiers) + readableKey(settings.hotkeyCode))
                    shortcutRow("Paste item", shortcut: "\u{2318}1 \u{2013} \u{2318}9")
                    shortcutRow("Paste selected", shortcut: "\u{21A9}")
                    shortcutRow("Paste as plain text", shortcut: "\u{21E7}\u{21A9}")
                    shortcutRow("Save as snippet", shortcut: "\u{2318}S")
                    shortcutRow("Pin / unpin", shortcut: "\u{2318}P")
                    shortcutRow("Edit snippet", shortcut: "\u{2318}E")
                    shortcutRow("Reorder snippet", shortcut: "\u{2318}\u{2325}\u{2191} / \u{2193}")
                    shortcutRow("Preview", shortcut: "\u{2192} / \u{2190}")
                    shortcutRow("Switch tab", shortcut: "Tab")
                    shortcutRow("Delete item", shortcut: "fn \u{232B}")
                    shortcutRow("Dismiss", shortcut: "\u{238B}")
                    shortcutRow("Filter by app", shortcut: "app:Safari")
                    shortcutRow("Filter by type", shortcut: "type:link")
                }
                .font(.caption)
                Text("Types: text, image, file, link, color, pinned")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    // MARK: - Ignored Apps Tab

    private var ignoredAppsTab: some View {
        Form {
            Section("Ignored Applications") {
                Text("Clipboard content from these apps will not be recorded.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if settings.ignoredAppBundleIDs.isEmpty {
                    Text("No apps ignored yet.")
                        .foregroundStyle(.tertiary)
                        .font(.system(size: 12))
                } else {
                    ForEach(Array(settings.ignoredAppBundleIDs).sorted(), id: \.self) { bundleID in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(friendlyName(for: bundleID))
                                    .font(.system(size: 13))
                                Text(bundleID)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button(role: .destructive) {
                                settings.ignoredAppBundleIDs.remove(bundleID)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 12))
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }

            Section("Quick Add") {
                Text("Common apps that handle sensitive data:")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(AppSettings.commonIgnoredApps, id: \.bundleID) { app in
                    HStack {
                        Text(app.name)
                            .font(.system(size: 13))
                        Spacer()
                        if settings.ignoredAppBundleIDs.contains(app.bundleID) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.system(size: 14))
                        } else {
                            Button("Add") {
                                settings.ignoredAppBundleIDs.insert(app.bundleID)
                            }
                            .controlSize(.small)
                        }
                    }
                }
            }

            Section("Add App") {
                Picker("App", selection: $selectedAppID) {
                    Text("Select application").tag("")
                    ForEach(availableApps) { app in
                        Text(app.name).tag(app.id)
                    }
                }
                .onChange(of: selectedAppID) { _, newValue in
                    if !newValue.isEmpty {
                        settings.ignoredAppBundleIDs.insert(newValue)
                        selectedAppID = ""
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Snippet import / export

    private func exportSnippets() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "Clippy Snippets.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try monitor.exportSnippets().write(to: url, options: .atomic)
            snippetTransferMessage = "Exported snippets to \(url.lastPathComponent)."
        } catch {
            snippetTransferMessage = "Export failed: \(error.localizedDescription)"
        }
    }

    private func importSnippets() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let added = try monitor.importSnippets(from: Data(contentsOf: url))
            snippetTransferMessage = added == 1 ? "Imported 1 snippet." : "Imported \(added) snippets."
        } catch {
            snippetTransferMessage = "Import failed: this file is not a Clippy snippet export."
        }
    }

    // MARK: - Helpers

    private func shortcutRow(_ label: String, shortcut: String) -> some View {
        GridRow {
            Text(label)
                .foregroundStyle(.secondary)
            Text(shortcut)
                .fontDesign(.monospaced)
        }
    }

    private func friendlyName(for bundleID: String) -> String {
        if let match = AppSettings.commonIgnoredApps.first(where: { $0.bundleID == bundleID }) {
            return match.name
        }
        if let match = installedApps.first(where: { $0.id == bundleID }) {
            return match.name
        }
        return bundleID.split(separator: ".").last.map(String.init) ?? bundleID
    }
}
