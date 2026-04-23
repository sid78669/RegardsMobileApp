import Foundation
import Testing
@testable import Regards

/// Locks in the DST-correct day math on `OverdueViewModel.makeOverdueRow`.
/// The VM injects `Calendar` so we can pin a fixed timezone for the test —
/// production code defaults to `.current` (user-local), which drifts from
/// `window.timeZone` by a calendar day across DST transitions and for
/// travelers. These tests document the invariant the reviewer asked us to
/// lock in on the 2026 fall-back boundary.
@MainActor
struct OverdueViewModelTests {

    static func makeCalendar(tz: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: tz) ?? .current
        return calendar
    }

    static func date(_ iso: String, tz: String) -> Date {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd HH:mm"
        df.timeZone = TimeZone(identifier: tz) ?? .current
        return df.date(from: iso)!
    }

    static func makeContact(lastInteractedAt: Date, cadenceDays: Int) -> Contact {
        Contact(
            systemContactRef: "sys-test",
            displayName: "Alex Chen",
            tracked: true,
            cadenceDays: cadenceDays,
            priorityTier: .close,
            preferredChannel: .signal,
            preferredChannelValue: "+14155550198",
            lastInteractedAt: lastInteractedAt
        )
    }

    // MARK: - DST fall-back (America/Los_Angeles, 2026-11-01)

    /// On Nov 1 2026 at 02:00 LA, the clock falls back to 01:00. A naive
    /// `(now - lastInteracted) / 86_400` counts that extra hour as a real
    /// calendar day under the wrong rounding, pushing a contact that's
    /// exactly 7 calendar-days overdue to either 6 or 8 depending on which
    /// direction the extra hour lands. Calendar-based day math is
    /// transition-aware and returns 7 exactly.
    @Test("Fall-back DST boundary: calendar day count is exactly 7")
    func fallBackBoundary() {
        let la = "America/Los_Angeles"
        let calendar = Self.makeCalendar(tz: la)
        // Last interacted: Wed Oct 22 2026 09:00 LA (pre-DST).
        let last = Self.date("2026-10-22 09:00", tz: la)
        // Now: Fri Oct 30 2026 09:00 LA (post-DST, 8 calendar days later).
        let now = Self.date("2026-10-30 09:00", tz: la)
        let contact = Self.makeContact(lastInteractedAt: last, cadenceDays: 1)

        let row = OverdueViewModel.makeOverdueRow(for: contact, now: now, calendar: calendar)

        // overdueAt = last + 1 day = Oct 23 09:00 LA.
        // Calendar day delta from Oct 23 09:00 to Oct 30 09:00 = 7.
        #expect(row?.overdueDays == 7)
    }

    /// Fires one row across the actual DST transition (Oct 31 pre → Nov 2 post).
    /// Seconds-based math computes 2 days + 3600 s ≈ 2.04 days (rounds to 2),
    /// but some simulator locales round on the seam. Calendar math is
    /// unambiguously 2 calendar days.
    @Test("Across DST fall-back: two calendar days between Oct 31 and Nov 2")
    func acrossTransition() {
        let la = "America/Los_Angeles"
        let calendar = Self.makeCalendar(tz: la)
        let last = Self.date("2026-10-30 09:00", tz: la)  // pre-fall-back
        let now  = Self.date("2026-11-02 09:00", tz: la)  // post-fall-back
        let contact = Self.makeContact(lastInteractedAt: last, cadenceDays: 1)

        let row = OverdueViewModel.makeOverdueRow(for: contact, now: now, calendar: calendar)

        // last + cadence(1 day) = Oct 31 09:00. From there to Nov 2 09:00 is
        // exactly 2 calendar days, DST seam included.
        #expect(row?.overdueDays == 2)
    }

    // MARK: - Happy path sanity

    @Test("Non-overdue contact returns 0")
    func notOverdue() {
        let utc = Self.makeCalendar(tz: "UTC")
        let last = Self.date("2026-04-19 12:00", tz: "UTC")
        let now = Self.date("2026-04-20 12:00", tz: "UTC")
        let contact = Self.makeContact(lastInteractedAt: last, cadenceDays: 14)

        let row = OverdueViewModel.makeOverdueRow(for: contact, now: now, calendar: utc)
        #expect(row?.overdueDays == 0)
    }

    @Test("Skipped contacts (no cadence / not tracked) return nil")
    func skipped() {
        let utc = Self.makeCalendar(tz: "UTC")
        var contact = Self.makeContact(lastInteractedAt: Date(), cadenceDays: 14)
        contact.tracked = false
        #expect(OverdueViewModel.makeOverdueRow(
            for: contact, now: Date(), calendar: utc) == nil)

        var noCadence = Self.makeContact(lastInteractedAt: Date(), cadenceDays: 14)
        noCadence.cadenceDays = nil
        #expect(OverdueViewModel.makeOverdueRow(
            for: noCadence, now: Date(), calendar: utc) == nil)
    }
}
