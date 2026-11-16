import Foundation
import Combine

/// Daily usage for a site. Persists whole minutes; live session adds elapsed time.
struct UsageTime: Hashable {
    /// Minutes spent today (stored + optional live session).
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
        "today"
    }

    static let placeholder = UsageTime(dailyMinutes: 0)
}

/// Per-site daily minutes in UserDefaults, plus in-memory session tracking.
@MainActor
enum UsageTimeStore {
    private static let defaults = UserDefaults.standard
    private static var sessionStarts: [String: Date] = [:]

    private static func minutesKey(_ siteID: String) -> String { "usage.dailyMinutes.\(siteID)" }
    private static func dayKey(_ siteID: String) -> String { "usage.day.\(siteID)" }

    private static var todayStamp: String {
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        return String(format: "%04d-%02d-%02d", comps.year ?? 0, comps.month ?? 0, comps.day ?? 0)
    }

    private static func resetIfNewDay(_ siteID: String) {
        let stamp = todayStamp
        if defaults.string(forKey: dayKey(siteID)) != stamp {
            defaults.set(stamp, forKey: dayKey(siteID))
            defaults.set(0, forKey: minutesKey(siteID))
        }
    }

    static func daily(for siteID: String) -> UsageTime {
        resetIfNewDay(siteID)
        var minutes = defaults.integer(forKey: minutesKey(siteID))
        if let start = sessionStarts[siteID] {
            minutes += max(0, Int(Date().timeIntervalSince(start) / 60))
        }
        return UsageTime(dailyMinutes: minutes)
    }

    static func beginSession(for siteID: String) {
        resetIfNewDay(siteID)
        if sessionStarts[siteID] == nil {
            sessionStarts[siteID] = Date()
        }
    }

    /// Flushes elapsed session minutes into storage and clears the session clock.
    static func endSession(for siteID: String) {
        guard let start = sessionStarts.removeValue(forKey: siteID) else { return }
        resetIfNewDay(siteID)
        let elapsed = max(0, Int(Date().timeIntervalSince(start) / 60))
        if elapsed > 0 {
            let stored = defaults.integer(forKey: minutesKey(siteID))
            defaults.set(stored + elapsed, forKey: minutesKey(siteID))
        }
    }
}
