import Foundation

/// Global reminder-window preferences (ARCHITECTURE.md §7, §9).
///
/// The single-row `ReminderWindow` table in the DB maps to one `ReminderWindow`
/// value. Per-contact overrides are represented as the same struct nullable on
/// the contact record.
public struct ReminderWindow: Sendable, Codable, Equatable, Hashable {
    public let allowedDays: DayOfWeekMask
    public let allowedTimeRanges: [TimeRange]
    public let quietHours: TimeRange?
    public let timezoneIdentifier: String

    public init(
        allowedDays: DayOfWeekMask,
        allowedTimeRanges: [TimeRange],
        quietHours: TimeRange? = nil,
        timezoneIdentifier: String
    ) {
        self.allowedDays = allowedDays
        self.allowedTimeRanges = allowedTimeRanges
        self.quietHours = quietHours
        self.timezoneIdentifier = timezoneIdentifier
    }

    public var timeZone: TimeZone {
        TimeZone(identifier: timezoneIdentifier) ?? .current
    }

    /// Default V1 window: weekdays 12:00–13:00 + 18:00–22:00, quiet 22:30–07:30.
    /// Matches the mock on screen-misc.jsx::ReminderWindowsScreen.
    public static func defaultV1(timezone: TimeZone = .current) -> ReminderWindow {
        ReminderWindow(
            allowedDays: .weekdays,
            allowedTimeRanges: [
                TimeRange(start: TimeOfDay(hour: 12), end: TimeOfDay(hour: 13)),
                TimeRange(start: TimeOfDay(hour: 18), end: TimeOfDay(hour: 22)),
            ],
            quietHours: TimeRange(start: TimeOfDay(hour: 22, minute: 30),
                                  end: TimeOfDay(hour: 7, minute: 30)),
            timezoneIdentifier: timezone.identifier
        )
    }

    /// Does the given `calendarWeekday` + `time` fall inside any allowed slot
    /// and outside quiet-hours?
    public func isInWindow(calendarWeekday weekday: Int, time: TimeOfDay) -> Bool {
        guard allowedDays.contains(calendarWeekday: weekday) else { return false }
        if let quiet = quietHours, quiet.contains(time) { return false }
        return allowedTimeRanges.contains { $0.contains(time) }
    }
}
