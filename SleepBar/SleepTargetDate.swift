//
//  SleepTargetDate.swift
//  SleepBar
//

import Foundation

/// Converts a 12-hour clock time into the next Date at which it occurs.
/// Returns today's date when the time is still ahead of `now`, otherwise
/// tomorrow's. Returns nil when the calendar cannot build the date.
func sleepTargetDate(hour12: Int, minute: Int, isPM: Bool,
                     from now: Date = Date(),
                     calendar: Calendar = .current) -> Date? {
    var hour24 = hour12
    if isPM && hour12 != 12 {
        hour24 = hour12 + 12
    } else if !isPM && hour12 == 12 {
        hour24 = 0
    }

    var components = calendar.dateComponents([.year, .month, .day], from: now)
    components.hour = hour24
    components.minute = minute

    guard let today = calendar.date(from: components) else { return nil }
    if today > now {
        return today
    }
    return calendar.date(byAdding: .day, value: 1, to: today)
}
