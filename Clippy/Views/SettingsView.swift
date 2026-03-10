import SwiftUI

struct SettingsView: View {
    @Bindable private var settings = AppSettings.shared
    @State private var newBundleID = ""

    var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            ignoredAppsTab
                .tabItem {
                    Label("Ignored Apps", systemImage: "eye.slash")
                }
        }
        .frame(width: 440, height: 420)
    }

    // MARK: - General Tab

    private var generalTab: some View {
        Form {
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
                    shortcutRow("Save as snippet", shortcut: "\u{2318}S")
                    shortcutRow("Switch tab", shortcut: "Tab")
                    shortcutRow("Delete item", shortcut: "fn \u{232B}")
                    shortcutRow("Dismiss", shortcut: "\u{238B}")
                }
                .font(.caption)
            }
        }
        .formStyle(.grouped)
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

            Section("Custom App") {
                HStack {
                    TextField("Bundle ID (e.g. com.example.app)", text: $newBundleID)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))
                    Button("Add") {
                        let trimmed = newBundleID.trimmingCharacters(in: .whitespaces)
                        if !trimmed.isEmpty {
                            settings.ignoredAppBundleIDs.insert(trimmed)
                            newBundleID = ""
                        }
                    }
                    .disabled(newBundleID.trimmingCharacters(in: .whitespaces).isEmpty)
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
        // Extract app name from bundle ID (last component, capitalized)
        return bundleID.split(separator: ".").last.map(String.init) ?? bundleID
    }
}
