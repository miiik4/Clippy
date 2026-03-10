import SwiftUI

struct SettingsView: View {
    @Bindable private var settings = AppSettings.shared

    var body: some View {
        Form {
            Section("History") {
                Picker("Keep clipboard history for", selection: $settings.retentionPeriod) {
                    ForEach(RetentionPeriod.allCases, id: \.self) { period in
                        Text(period.displayName).tag(period)
                    }
                }
                .pickerStyle(.radioGroup)
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
                    shortcutRow("Delete item", shortcut: "fn \u{232B}")
                    shortcutRow("Dismiss", shortcut: "\u{238B}")
                }
                .font(.caption)
            }
        }
        .formStyle(.grouped)
        .frame(width: 380, height: 320)
    }

    private func shortcutRow(_ label: String, shortcut: String) -> some View {
        GridRow {
            Text(label)
                .foregroundStyle(.secondary)
            Text(shortcut)
                .fontDesign(.monospaced)
        }
    }
}
