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

    private init() {
        let stored = UserDefaults.standard.integer(forKey: "retentionPeriod")
        retentionPeriod = RetentionPeriod(rawValue: stored) ?? .threeMonths
    }
}
