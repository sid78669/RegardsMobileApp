import Foundation

/// Allowed-days bitmask used by the reminder-window engine (ARCHITECTURE.md
/// §7 `ReminderWindow.allowedDaysMask`: Sun=1, Mon=2, ... Sat=64).
public struct DayOfWeekMask: OptionSet, Sendable, Codable, Equatable, Hashable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let sunday    = DayOfWeekMask(rawValue: 1 << 0)
    public static let monday    = DayOfWeekMask(rawValue: 1 << 1)
    public static let tuesday   = DayOfWeekMask(rawValue: 1 << 2)
    public static let wednesday = DayOfWeekMask(rawValue: 1 << 3)
    public static let thursday  = DayOfWeekMask(rawValue: 1 << 4)
    public static let friday    = DayOfWeekMask(rawValue: 1 << 5)
    public static let saturday  = DayOfWeekMask(rawValue: 1 << 6)

    public static let weekdays: DayOfWeekMask = [.monday, .tuesday, .wednesday, .thursday, .friday]
    public static let weekends: DayOfWeekMask = [.saturday, .sunday]
    public static let allDays: DayOfWeekMask  = [.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday]

    /// `Calendar.component(.weekday, from:)` returns 1=Sunday … 7=Saturday.
    public static func fromCalendarWeekday(_ weekday: Int) -> DayOfWeekMask {
        switch weekday {
        case 1: return .sunday
        case 2: return .monday
        case 3: return .tuesday
        case 4: return .wednesday
        case 5: return .thursday
        case 6: return .friday
        case 7: return .saturday
        default: return []
        }
    }

    public func contains(calendarWeekday weekday: Int) -> Bool {
        !isDisjoint(with: Self.fromCalendarWeekday(weekday))
    }
}
