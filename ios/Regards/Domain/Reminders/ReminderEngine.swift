import Foundation

/// Result of a cadence scheduling pass for a single contact / group.
public enum CadenceSchedulingOutcome: Sendable, Equatable {
    /// Contact is not yet overdue and has no pending reminder.
    case notOverdue(firesAt: Date)
    /// Contact is overdue (or becomes overdue when `now` reaches `targetFireTime`)
    /// and the engine has picked a next window to fire in.
    case scheduled(firesAt: Date)
    /// Contact is not tracked or has no cadence set.
    case skipped(reason: SkipReason)

    public enum SkipReason: String, Sendable, Equatable {
        case notTracked
        case missingCadence
        case archived
    }
}

/// Month-day pair for annual-recurrence events (§7). Kept as its own type so
/// Feb-29 handling is explicit at every call site.
public struct MonthDay: Sendable, Equatable, Hashable {
    public let month: Int
    public let day: Int

    public init(month: Int, day: Int) {
        precondition((1...12).contains(month), "month must be 1…12")
        precondition((1...31).contains(day),   "day must be 1…31")
        self.month = month
        self.day = day
    }

    /// ISO "MM-DD" used as `ScheduledReminder.occasionDate`.
    public var isoString: String {
        String(format: "%02d-%02d", month, day)
    }

    public static func from(isoString: String) -> MonthDay? {
        let parts = isoString.split(separator: "-")
        guard parts.count == 2,
              let m = Int(parts[0]), let d = Int(parts[1]),
              (1...12).contains(m), (1...31).contains(d) else { return nil }
        return MonthDay(month: m, day: d)
    }
}

/// Pure-function reminder scheduler (ARCHITECTURE.md §9). Takes no dependency
/// on Apple platform frameworks — the platform adapter calls `schedule(for:)`
/// and translates the `Date` result into a `UNCalendarNotificationTrigger`
/// (iOS) / `AlarmManager` (Android) up-call.
public struct ReminderEngine: Sendable {

    /// Morning-of notification time for birthdays + anniversaries
    /// (default 09:00 local per §9). Stored on `UserProfile`/Settings in
    /// production; passed in here to keep the engine pure.
    public let occasionNotificationTime: TimeOfDay

    /// Injected clock — tests pass a fixed date.
    private let clock: @Sendable () -> Date

    public init(
        occasionNotificationTime: TimeOfDay = TimeOfDay(hour: 9),
        clock: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.occasionNotificationTime = occasionNotificationTime
        self.clock = clock
    }

    // MARK: - Cadence scheduling

    /// Computes when a cadence reminder should fire for a given contact.
    ///
    /// - Parameters:
    ///   - contact: the target contact (`archivedAt`, `tracked`, `cadenceDays`
    ///     are inspected).
    ///   - effectiveLastInteractedAt: either the contact's own
    ///     `lastInteractedAt`, or, for a contact that belongs to a virtual-
    ///     merge group, the *max* of `lastInteractedAt` across the group's
    ///     members (ARCHITECTURE.md §7 "Scheduling under virtual merges").
    ///     Caller is responsible for the max computation.
    ///   - window: the effective reminder window (per-contact override, or
    ///     global).
    public func scheduleCadence(
        for contact: Contact,
        effectiveLastInteractedAt: Date?,
        window: ReminderWindow
    ) -> CadenceSchedulingOutcome {
        guard contact.archivedAt == nil else { return .skipped(reason: .archived) }
        guard contact.tracked else        { return .skipped(reason: .notTracked) }
        guard let cadenceDays = contact.cadenceDays, cadenceDays > 0 else {
            return .skipped(reason: .missingCadence)
        }

        let now = clock()
        let overdueAt: Date
        if let last = effectiveLastInteractedAt {
            overdueAt = last.addingTimeInterval(TimeInterval(cadenceDays) * 86_400)
        } else {
            // Never contacted — schedule the first reminder as soon as the
            // next allowed window opens.
            overdueAt = now
        }

        let target = max(now, overdueAt)
        let fires = nextAllowedSlot(from: target, in: window)
        return overdueAt > now ? .notOverdue(firesAt: fires) : .scheduled(firesAt: fires)
    }

    // MARK: - Window walking

    /// Earliest moment ≥ `date` that falls inside one of the window's allowed
    /// `(day, time-range)` slots and is not inside `quietHours`.
    ///
    /// The walk uses the window's `timeZone` for all calendar/clock math so
    /// DST transitions are handled automatically — `Calendar.nextDate(...)` is
    /// the same API Apple's EventKit uses.
    public func nextAllowedSlot(from date: Date, in window: ReminderWindow) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = window.timeZone

        // Sort ranges once; we rely on ascending start time below.
        let sortedRanges = window.allowedTimeRanges.sorted { $0.start < $1.start }
        guard !sortedRanges.isEmpty, !window.allowedDays.isEmpty else {
            // Degenerate config — return the input date unchanged; the caller
            // should surface a UX error.
            return date
        }

        // Walk at most 8 days forward (guarantees we land on the next
        // occurrence of every weekday). In-loop we inspect today first, then
        // each following day.
        var cursor = date
        for dayOffset in 0..<8 {
            let candidateDay: Date = dayOffset == 0
                ? cursor
                : calendar.date(byAdding: .day, value: 1, to: cursor)!
            cursor = candidateDay

            let weekday = calendar.component(.weekday, from: candidateDay)
            guard window.allowedDays.contains(calendarWeekday: weekday) else { continue }

            // Figure out the wall-clock time on this day.
            let startOfDay = calendar.startOfDay(for: candidateDay)
            let timeOfDay: TimeOfDay
            if dayOffset == 0 {
                let comps = calendar.dateComponents([.hour, .minute], from: candidateDay)
                timeOfDay = TimeOfDay(hour: comps.hour ?? 0, minute: comps.minute ?? 0)
            } else {
                timeOfDay = TimeOfDay.midnight
            }

            // Find the next range on this day whose end is after the cursor's
            // time, and advance the cursor past quiet-hours if necessary.
            for range in sortedRanges {
                // Range already in the past on this day — skip.
                if range.end <= timeOfDay { continue }

                // Our earliest candidate inside this range on this day.
                var rangeCursor = max(range.start, timeOfDay)

                // Quiet-hours override: step forward until we're out of it.
                if let quiet = window.quietHours {
                    if quiet.contains(rangeCursor) {
                        // Shift rangeCursor to quiet.end (wrap-aware).
                        let proposed = quiet.end
                        // If quiet.end still falls inside the range, use it;
                        // otherwise this range is fully consumed by quiet.
                        if range.contains(proposed) {
                            rangeCursor = proposed
                        } else {
                            continue
                        }
                    }
                }

                // Rebuild the Date from (startOfDay, rangeCursor).
                let proposedDate = calendar.date(byAdding: .minute,
                                                 value: rangeCursor.minutesSinceMidnight,
                                                 to: startOfDay)!
                if proposedDate >= date { return proposedDate }
            }
        }

        // Unreachable in practice — fall back to the input date if the search
        // exhausts 8 days without finding a slot.
        return date
    }

    // MARK: - Annual recurrence (birthdays, anniversaries)

    /// The next occurrence of `monthDay` at `occasionNotificationTime` in the
    /// given timezone. Feb 29 falls back to Feb 28 in non-leap years. If today
    /// *is* the occasion and the notification time is still in the future,
    /// fires today; otherwise fires next year.
    public func nextOccasionOccurrence(
        monthDay: MonthDay,
        timezone: TimeZone
    ) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone

        let now = clock()
        let todayComps = calendar.dateComponents([.year, .month, .day], from: now)
        guard let thisYear = todayComps.year else { return now }

        func resolve(year: Int) -> Date? {
            let adjustedDay = resolveFeb29Fallback(year: year, monthDay: monthDay,
                                                   calendar: calendar)
            var comps = DateComponents()
            comps.year = year
            comps.month = monthDay.month
            comps.day = adjustedDay
            comps.hour = occasionNotificationTime.hour
            comps.minute = occasionNotificationTime.minute
            return calendar.date(from: comps)
        }

        if let thisYearDate = resolve(year: thisYear), thisYearDate >= now {
            return thisYearDate
        }
        // Already passed this year — roll forward.
        return resolve(year: thisYear + 1) ?? now
    }

    /// Returns the effective day for the occurrence — Feb 29 in a non-leap
    /// year becomes Feb 28 (§9).
    func resolveFeb29Fallback(year: Int, monthDay: MonthDay, calendar: Calendar) -> Int {
        guard monthDay.month == 2, monthDay.day == 29 else { return monthDay.day }
        var comps = DateComponents()
        comps.year = year
        comps.month = 2
        comps.day = 29
        if calendar.date(from: comps) != nil, calendar.range(of: .day, in: .month,
                                                             for: calendar.date(from: comps)!)?.count == 29 {
            return 29
        }
        return 28
    }

    // MARK: - Batching

    /// Group reminders that share a window slot (same `scheduledFor`) so the
    /// platform adapter can collapse them into a single digest notification
    /// (§9 "Batching").
    public func batch(_ reminders: [ScheduledReminder]) -> [Date: [ScheduledReminder]] {
        Dictionary(grouping: reminders.filter { $0.state == .pending },
                   by: { $0.scheduledFor })
    }
}
