import Foundation

enum ArtworkRepairStatus {
    static let statusKey = "auto_repair_status"
    private static let lastRunKey = "auto_repair_last_run"
    private static let lastCountKey = "auto_repair_last_count"

    static func set(_ value: String?) {
        let defaults = UserDefaults.standard
        if let value, !value.isEmpty {
            defaults.set(value, forKey: statusKey)
        } else {
            defaults.removeObject(forKey: statusKey)
        }
    }

    static func lastRunAt() -> Date? {
        let timeInterval = UserDefaults.standard.double(forKey: lastRunKey)
        guard timeInterval > 0 else { return nil }
        return Date(timeIntervalSince1970: timeInterval)
    }

    static func markRunCompleted(count: Int) {
        let defaults = UserDefaults.standard
        defaults.set(Date().timeIntervalSince1970, forKey: lastRunKey)
        defaults.set(count, forKey: lastCountKey)
    }

    static func lastRunCount() -> Int {
        UserDefaults.standard.integer(forKey: lastCountKey)
    }
}

extension Notification.Name {
    static let artworkRepairDidComplete = Notification.Name("ArtworkRepairDidComplete")
}
