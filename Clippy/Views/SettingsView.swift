import SwiftUI
import ServiceManagement

struct InstalledApp: Identifiable, Comparable {
    let id: String // bundleID
    let name: String

    static func < (lhs: InstalledApp, rhs: InstalledApp) -> Bool {
        lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }

    static func loadAll() -> [InstalledApp] {
        var result: [InstalledApp] = []
        var seen = Set<String>()
        let urls = LSCopyApplicationURLsForBundleIdentifier("" as CFString, nil)?
            .takeRetainedValue() as? [URL] ?? []

        // LSCopy with empty string won't work; scan Applications folders instead
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
    @Bindable private var settings = AppSettings.shared
    @State private var launchAtLogin = false
    @State private var installedApps: [InstalledApp] = []
    @State private var selectedAppID = ""

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
        .frame(width: 440, height: 420)
        .onAppear {
            installedApps = InstalledApp.loadAll()
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

            Section("Privacy") {
                Text("Clippy automatically ignores concealed data (e.g. password fields) and transient content marked by apps.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Shortcuts") {
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                    shortcutRow("Toggle Clippy", shortcut: "\u{2325}\u{2318}C")
                    shortcutRow("Paste item", shortcut: "\u{2318}1 \u{2013} \u{2318}9")
                    shortcutRow("Paste selected", shortcut: "\u{21A9}")
                    shortcutRow("Paste as plain text", shortcut: "\u{21E7}\u{21A9}")
                    shortcutRow("Save as snippet", shortcut: "\u{2318}S")
                    shortcutRow("Preview image", shortcut: "\u{2192} / \u{2190}")
                    shortcutRow("Switch tab", shortcut: "Tab")
                    shortcutRow("Delete item", shortcut: "fn \u{232B}")
                    shortcutRow("Dismiss", shortcut: "\u{238B}")
                }
                .font(.caption)
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
