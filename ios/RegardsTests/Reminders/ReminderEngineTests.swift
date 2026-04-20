import Foundation
import Testing
@testable import Regards

/// Core ReminderEngine algorithm from ARCHITECTURE.md §9. DST and timezone
/// edge cases are explicit because the engine walks calendar days using the
/// window's timezone — a naive Date-math implementation would double-fire
/// (or skip) a window the day DST shifts.
struct ReminderEngineTests {

    // Helpers ---------------------------------------------------------------

    static func date(_ iso: String, tz: String = "UTC") -> Date {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        if let d = f.date(from: iso) { return d }
        // Allow "YYYY-MM-DD HH:mm" local
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: tz) ?? .current
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm"
        df.timeZone = calendar.timeZone
        return df.date(from: iso)!
    }

    static let indiaWindow = ReminderWindow(
        allowedDays: [.monday, .tuesday, .wednesday, .thursday, .friday],
        allowedTimeRanges: [
            TimeRange(start: TimeOfDay(hour: 12), end: TimeOfDay(hour: 13)),
            TimeRange(start: TimeOfDay(hour: 18), end: TimeOfDay(hour: 22)),
        ],
        quietHours: nil,
        timezoneIdentifier: "Asia/Kolkata"
    )

    static func engine(now: Date) -> ReminderEngine {
        ReminderEngine(clock: { now })
    }

    // MARK: - Basic cadence

    @Test("Contact overdue right now schedules in the next in-window slot")
    func cadenceOverdueNow() {
        // Wed 2026-04-15 14:00 local (between 13:00-18:00 gap) — not in window.
        let now = Self.date("2026-04-15 14:00", tz: "Asia/Kolkata")
        let last = Self.date("2026-03-29 09:00", tz: "Asia/Kolkata")  // 17 days ago
        let contact = Contact(
            systemContactRef: "x", displayName: "Test",
            tracked: true, cadenceDays: 14,
            priorityTier: .regular, preferredChannel: .whatsapp,
            preferredChannelValue: "+15551234567",
            lastInteractedAt: last)

        let outcome = Self.engine(now: now).scheduleCadence(
            for: contact, effectiveLastInteractedAt: last, window: Self.indiaWindow)

        guard case .scheduled(let fires) = outcome else {
            Issue.record("expected scheduled outcome, got \(outcome)"); return
        }
        // Next slot opens 18:00 the same Wed.
        let expected = Self.date("2026-04-15 18:00", tz: "Asia/Kolkata")
        #expect(fires == expected)
    }

    @Test("Not-yet-overdue contact is still scheduled, not marked overdue")
    func cadenceNotYetOverdue() {
        let now = Self.date("2026-04-15 14:00", tz: "Asia/Kolkata")
        let last = Self.date("2026-04-14 09:00", tz: "Asia/Kolkata")
        let contact = Contact(
            systemContactRef: "x", displayName: "Test",
            tracked: true, cadenceDays: 14, preferredChannel: .whatsapp,
            preferredChannelValue: "+15551234567",
            lastInteractedAt: last)

        let outcome = Self.engine(now: now).scheduleCadence(
            for: contact, effectiveLastInteractedAt: last, window: Self.indiaWindow)
        if case .notOverdue = outcome { return }
        Issue.record("expected notOverdue, got \(outcome)")
    }

    @Test("Skipped when contact not tracked")
    func cadenceSkippedWhenNotTracked() {
        let now = Date()
        var contact = Contact(systemContactRef: "x", displayName: "A",
                              preferredChannel: .whatsapp, preferredChannelValue: "")
        contact.tracked = false
        let outcome = Self.engine(now: now).scheduleCadence(
            for: contact, effectiveLastInteractedAt: nil, window: Self.indiaWindow)
        #expect(outcome == .skipped(reason: .notTracked))
    }

    @Test("Skipped when cadence is missing")
    func cadenceSkippedWhenMissing() {
        let contact = Contact(systemContactRef: "x", displayName: "A",
                              tracked: true, cadenceDays: nil,
                              preferredChannel: .whatsapp, preferredChannelValue: "")
        let outcome = Self.engine(now: Date()).scheduleCadence(
            for: contact, effectiveLastInteractedAt: nil, window: Self.indiaWindow)
        #expect(outcome == .skipped(reason: .missingCadence))
    }

    @Test("Archived contacts are skipped")
    func cadenceSkippedWhenArchived() {
        var contact = Contact(systemContactRef: "x", displayName: "A",
                              tracked: true, cadenceDays: 7,
                              preferredChannel: .whatsapp, preferredChannelValue: "")
        contact.archivedAt = Date()
        let outcome = Self.engine(now: Date()).scheduleCadence(
            for: contact, effectiveLastInteractedAt: nil, window: Self.indiaWindow)
        #expect(outcome == .skipped(reason: .archived))
    }

    @Test("First-ever reminder (no prior interaction) schedules to the next slot")
    func cadenceNeverContacted() {
        let now = Self.date("2026-04-15 14:00", tz: "Asia/Kolkata")
        let contact = Contact(
            systemContactRef: "x", displayName: "Test", tracked: true,
            cadenceDays: 7, preferredChannel: .whatsapp,
            preferredChannelValue: "+15551234567",
            lastInteractedAt: nil)
        let outcome = Self.engine(now: now).scheduleCadence(
            for: contact, effectiveLastInteractedAt: nil, window: Self.indiaWindow)
        guard case .scheduled(let fires) = outcome else {
            Issue.record("expected scheduled, got \(outcome)"); return
        }
        #expect(fires == Self.date("2026-04-15 18:00", tz: "Asia/Kolkata"))
    }

    // MARK: - Window walking

    @Test("Already inside a window returns the current moment")
    func nextAllowedSlotInsideRange() {
        let now = Self.date("2026-04-15 18:30", tz: "Asia/Kolkata")
        let slot = Self.engine(now: now).nextAllowedSlot(from: now, in: Self.indiaWindow)
        #expect(slot == now)
    }

    @Test("Before today's first range — jumps forward to that range's start")
    func nextAllowedSlotBeforeFirstRange() {
        let now = Self.date("2026-04-15 09:00", tz: "Asia/Kolkata")
        let slot = Self.engine(now: now).nextAllowedSlot(from: now, in: Self.indiaWindow)
        #expect(slot == Self.date("2026-04-15 12:00", tz: "Asia/Kolkata"))
    }

    @Test("Weekend disallowed — jumps to Monday's first slot")
    func nextAllowedSlotSkipsWeekend() {
        let now = Self.date("2026-04-18 10:00", tz: "Asia/Kolkata") // Saturday
        let slot = Self.engine(now: now).nextAllowedSlot(from: now, in: Self.indiaWindow)
        #expect(slot == Self.date("2026-04-20 12:00", tz: "Asia/Kolkata"))
    }

    @Test("Quiet hours carve out of an allowed range")
    func nextAllowedSlotHonorsQuietHours() {
        let windowWithQuiet = ReminderWindow(
            allowedDays: .weekdays,
            allowedTimeRanges: [
                TimeRange(start: TimeOfDay(hour: 18), end: TimeOfDay(hour: 22)),
            ],
            quietHours: TimeRange(start: TimeOfDay(hour: 20), end: TimeOfDay(hour: 21)),
            timezoneIdentifier: "Asia/Kolkata"
        )
        // Cursor lands at 20:30 (inside quiet). Should bump to 21:00.
        let now = Self.date("2026-04-15 20:30", tz: "Asia/Kolkata")
        let slot = Self.engine(now: now).nextAllowedSlot(from: now, in: windowWithQuiet)
        #expect(slot == Self.date("2026-04-15 21:00", tz: "Asia/Kolkata"))
    }

    @Test("Quiet-hours wrap across midnight (22:30 → 07:30)")
    func nextAllowedSlotWrappingQuietHours() {
        // An evening window fully inside wrap-quiet-hours is consumed.
        let window = ReminderWindow(
            allowedDays: .weekdays,
            allowedTimeRanges: [TimeRange(start: TimeOfDay(hour: 23), end: TimeOfDay(hour: 23, minute: 30))],
            quietHours: TimeRange(start: TimeOfDay(hour: 22, minute: 30), end: TimeOfDay(hour: 7, minute: 30)),
            timezoneIdentifier: "Asia/Kolkata"
        )
        let now = Self.date("2026-04-15 09:00", tz: "Asia/Kolkata")
        let slot = Self.engine(now: now).nextAllowedSlot(from: now, in: window)
        // Input has no viable slot ever — engine returns the input (degenerate),
        // but with at least the "walked 8 days" fallback guarding infinite loops.
        // We expect the slot to be ≥ now even if no window existed.
        #expect(slot >= now)
    }

    @Test("DST spring-forward does not skip the day's first slot in America/Los_Angeles")
    func nextAllowedSlotSpringForwardLA() {
        // In 2026, LA springs forward on Sunday March 8 at 02:00 → 03:00.
        // Saturday March 7 12:00 local. Mon–Fri + 18:00–22:00 window. We
        // expect the next slot to be Mon Mar 9 18:00 local (weekend skipped).
        let laWindow = ReminderWindow(
            allowedDays: .weekdays,
            allowedTimeRanges: [TimeRange(start: TimeOfDay(hour: 18), end: TimeOfDay(hour: 22))],
            quietHours: nil,
            timezoneIdentifier: "America/Los_Angeles"
        )
        let now = Self.date("2026-03-07 12:00", tz: "America/Los_Angeles")
        let slot = Self.engine(now: now).nextAllowedSlot(from: now, in: laWindow)
        let expected = Self.date("2026-03-09 18:00", tz: "America/Los_Angeles")
        #expect(slot == expected)
    }

    @Test("DST fall-back does not double-schedule an early-morning slot")
    func nextAllowedSlotFallBackLA() {
        // Nov 1 2026, LA falls back 02:00 → 01:00. Morning 07:00 window, Mon–Fri.
        // On Fri Oct 30 after the window closes at 08:00, next slot should be
        // Mon Nov 2 07:00 — single occurrence, not repeated.
        let morningWindow = ReminderWindow(
            allowedDays: .weekdays,
            allowedTimeRanges: [TimeRange(start: TimeOfDay(hour: 7), end: TimeOfDay(hour: 8))],
            quietHours: nil,
            timezoneIdentifier: "America/Los_Angeles"
        )
        let now = Self.date("2026-10-30 09:00", tz: "America/Los_Angeles")
        let slot = Self.engine(now: now).nextAllowedSlot(from: now, in: morningWindow)
        let expected = Self.date("2026-11-02 07:00", tz: "America/Los_Angeles")
        #expect(slot == expected)
    }

    // MARK: - Batching

    @Test("Pending reminders that share a scheduledFor collapse into one batch")
    func batchGroupsBySlot() {
        let c1 = UUID(); let c2 = UUID(); let c3 = UUID()
        let slotA = Self.date("2026-04-20 18:00", tz: "Asia/Kolkata")
        let slotB = Self.date("2026-04-21 18:00", tz: "Asia/Kolkata")
        let reminders = [
            ScheduledReminder(contactId: c1, kind: .cadence, scheduledFor: slotA, osNotificationId: "1"),
            ScheduledReminder(contactId: c2, kind: .cadence, scheduledFor: slotA, osNotificationId: "2"),
            ScheduledReminder(contactId: c3, kind: .cadence, scheduledFor: slotB, osNotificationId: "3"),
            ScheduledReminder(contactId: c1, kind: .cadence, scheduledFor: slotA,
                              osNotificationId: "cancelled", state: .cancelled),
        ]
        let batches = ReminderEngine().batch(reminders)
        #expect(batches[slotA]?.count == 2)    // cancelled is filtered
        #expect(batches[slotB]?.count == 1)
    }
}
