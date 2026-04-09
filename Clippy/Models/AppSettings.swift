import Carbon.HIToolbox
import Foundation
import Observation

enum RetentionPeriod: Int, CaseIterable, Codable {
    case oneDay = 1
    case sevenDays = 7
    case oneMonth = 30
    case threeMonths = 90

    var displayName: String {
        switch self {
        case .oneDay: return "24 Hours"
        case .sevenDays: return "7 Days"
        case .oneMonth: return "1 Month"
        case .threeMonths: return "3 Months"
        }
    }

    var timeInterval: TimeInterval {
        TimeInterval(rawValue) * 86400
    }
}

@Observable
final class AppSettings {
    static let shared = AppSettings()

    var retentionPeriod: RetentionPeriod {
        didSet {
            UserDefaults.standard.set(retentionPeriod.rawValue, forKey: "retentionPeriod")
        }
    }

    var ignoredAppBundleIDs: Set<String> {
        didSet {
            UserDefaults.standard.set(Array(ignoredAppBundleIDs), forKey: "ignoredAppBundleIDs")
        }
    }

    var isMergeEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isMergeEnabled, forKey: "isMergeEnabled")
        }
    }

    var mergeWindowSeconds: Double {
        didSet {
            UserDefaults.standard.set(mergeWindowSeconds, forKey: "mergeWindowSeconds")
        }
    }

    var hotkeyCode: Int {
        didSet {
            UserDefaults.standard.set(hotkeyCode, forKey: "hotkeyCode")
        }
    }

    var hotkeyModifiers: Int {
        didSet {
            UserDefaults.standard.set(hotkeyModifiers, forKey: "hotkeyModifiers")
        }
    }

    static let commonIgnoredApps: [(name: String, bundleID: String)] = [
        ("Passwords", "com.apple.Passwords"),
        ("1Password", "com.1password.1password"),
        ("1Password 7", "com.agilebits.onepassword7"),
        ("Bitwarden", "com.bitwarden.desktop"),
        ("KeePassXC", "org.keepassxc.keepassxc"),
        ("LastPass", "com.lastpass.LastPass"),
        ("Keychain Access", "com.apple.keychainaccess"),
        ("Dashlane", "com.dashlane.Dashlane"),
    ]

    static let sensitiveAppBundleIDs: Set<String> = [
        "com.apple.Passwords",
        "com.1password.1password",
        "com.agilebits.onepassword7",
        "com.bitwarden.desktop",
        "org.keepassxc.keepassxc",
        "com.lastpass.LastPass",
        "com.apple.keychainaccess",
        "com.dashlane.Dashlane",
    ]

    private init() {
        let stored = UserDefaults.standard.integer(forKey: "retentionPeriod")
        retentionPeriod = RetentionPeriod(rawValue: stored) ?? .threeMonths

        let storedIDs = UserDefaults.standard.stringArray(forKey: "ignoredAppBundleIDs") ?? []
        ignoredAppBundleIDs = Set(storedIDs)

        isMergeEnabled = UserDefaults.standard.object(forKey: "isMergeEnabled") as? Bool ?? true
        mergeWindowSeconds = UserDefaults.standard.object(forKey: "mergeWindowSeconds") as? Double ?? 1.0

        let storedKeyCode = UserDefaults.standard.object(forKey: "hotkeyCode") as? Int
        hotkeyCode = storedKeyCode ?? kVK_ANSI_V

        let storedModifiers = UserDefaults.standard.object(forKey: "hotkeyModifiers") as? Int
        hotkeyModifiers = storedModifiers ?? (optionKey | cmdKey)
    }
}
