import Foundation

enum DateUtils {
    static func yyyymmdd(_ date: Date, calendar: Calendar = Calendar.current) -> Int {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        let year = comps.year ?? 0
        let month = comps.month ?? 0
        let day = comps.day ?? 0
        return year * 10000 + month * 100 + day
    }
}
