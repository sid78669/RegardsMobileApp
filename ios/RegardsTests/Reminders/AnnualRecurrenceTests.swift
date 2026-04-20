import Foundation
import Testing
@testable import Regards

struct AnnualRecurrenceTests {

    static let ist = TimeZone(identifier: "Asia/Kolkata")!

    static func date(_ iso: String, tz: TimeZone = ist) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tz
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm"
        df.timeZone = tz
        return df.date(from: iso)!
    }

    @Test("Birthday later this year schedules at 09:00 on the birthday")
    func birthdayLaterThisYear() {
        let now = Self.date("2026-04-19 14:00")
        let engine = ReminderEngine(
            occasionNotificationTime: TimeOfDay(hour: 9),
            clock: { now })
        let next = engine.nextOccasionOccurrence(
            monthDay: MonthDay(month: 6, day: 14),
            timezone: Self.ist)
        #expect(next == Self.date("2026-06-14 09:00"))
    }

    @Test("Birthday already passed this year rolls into next year")
    func birthdayAlreadyPassed() {
        let now = Self.date("2026-04-19 14:00")
        let engine = ReminderEngine(
            occasionNotificationTime: TimeOfDay(hour: 9),
            clock: { now })
        let next = engine.nextOccasionOccurrence(
            monthDay: MonthDay(month: 3, day: 10),
            timezone: Self.ist)
        #expect(next == Self.date("2027-03-10 09:00"))
    }

    @Test("Birthday is today but before 09:00 — fires today")
    func birthdayTodayBeforeTime() {
        let now = Self.date("2026-06-14 07:00")
        let engine = ReminderEngine(
            occasionNotificationTime: TimeOfDay(hour: 9),
            clock: { now })
        let next = engine.nextOccasionOccurrence(
            monthDay: MonthDay(month: 6, day: 14),
            timezone: Self.ist)
        #expect(next == Self.date("2026-06-14 09:00"))
    }

    @Test("Birthday is today after 09:00 — next year")
    func birthdayTodayAfterTime() {
        let now = Self.date("2026-06-14 10:00")
        let engine = ReminderEngine(
            occasionNotificationTime: TimeOfDay(hour: 9),
            clock: { now })
        let next = engine.nextOccasionOccurrence(
            monthDay: MonthDay(month: 6, day: 14),
            timezone: Self.ist)
        #expect(next == Self.date("2027-06-14 09:00"))
    }

    @Test("Feb 29 falls back to Feb 28 in non-leap years")
    func feb29NonLeapFallback() {
        // 2027 is not a leap year; 2028 is.
        let now = Self.date("2027-01-15 14:00")
        let engine = ReminderEngine(
            occasionNotificationTime: TimeOfDay(hour: 9),
            clock: { now })
        let next = engine.nextOccasionOccurrence(
            monthDay: MonthDay(month: 2, day: 29),
            timezone: Self.ist)
        #expect(next == Self.date("2027-02-28 09:00"))
    }

    @Test("Feb 29 stays Feb 29 in leap years")
    func feb29LeapYear() {
        let now = Self.date("2028-01-15 14:00")
        let engine = ReminderEngine(
            occasionNotificationTime: TimeOfDay(hour: 9),
            clock: { now })
        let next = engine.nextOccasionOccurrence(
            monthDay: MonthDay(month: 2, day: 29),
            timezone: Self.ist)
        #expect(next == Self.date("2028-02-29 09:00"))
    }

    @Test("MonthDay encodes to and from the ISO MM-DD form")
    func monthDayIsoRoundtrip() {
        #expect(MonthDay(month: 2, day: 29).isoString == "02-29")
        #expect(MonthDay.from(isoString: "12-31") == MonthDay(month: 12, day: 31))
        #expect(MonthDay.from(isoString: "13-01") == nil)
        #expect(MonthDay.from(isoString: "not-a-date") == nil)
    }
}
