import Foundation

/// Placeholder daily usage for a site. Ready for future open-duration tracking.
struct UsageTime: Hashable {
    /// Minutes spent today. Stub until real tracking lands.
    var dailyMinutes: Int

    var displayString: String {
        if dailyMinutes <= 0 {
            return "0m"
        }
        let hours = dailyMinutes / 60
        let minutes = dailyMinutes % 60
        if hours > 0 {
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        }
        return "\(minutes)m"
    }

    /// Short caption under the time for scanability.
    var caption: String {
        dailyMinutes <= 0 ? "today" : "today"
    }

    static let placeholder = UsageTime(dailyMinutes: 0)
}

/// Stub store keyed by site id. Replace with real accumulation later.
enum UsageTimeStore {
    static func daily(for siteID: String) -> UsageTime {
        // Placeholder values so the UI shows a clear time string per row.
        switch siteID {
        case "instagram", "youtube":
            return .placeholder
        default:
            return .placeholder
        }
    }
}
