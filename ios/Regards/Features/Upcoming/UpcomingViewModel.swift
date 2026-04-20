import Foundation
import Observation

public struct UpcomingRowState: Sendable, Identifiable, Equatable {
    public let id: UUID
    public let contactId: UUID
    public let name: String
    public let kind: ReminderKind
    public let scheduledFor: Date
    public let channel: Channel
    public let cadenceText: String?
    public let occasionText: String?
    public let timeOfDayText: String
    public let dayHeader: String
}

@Observable
public final class UpcomingViewModel: @unchecked Sendable {

    public private(set) var groups: [(header: String, rows: [UpcomingRowState])] = []
    public private(set) var totalCount: Int = 0

    public var horizonDays: Int = 14

    private let contacts: any ContactRepository
    private let engine: ReminderEngine
    private let window: ReminderWindow
    private let clock: @Sendable () -> Date

    public init(contacts: any ContactRepository,
                engine: ReminderEngine = ReminderEngine(),
                window: ReminderWindow = .defaultV1(),
                clock: @escaping @Sendable () -> Date = { Date() }) {
        self.contacts = contacts
        self.engine = engine
        self.window = window
        self.clock = clock
    }

    public func load() async {
        do {
            let tracked = try await contacts.fetchTracked()
            let now = clock()
            let rows = buildRows(contacts: tracked, now: now)
            totalCount = rows.count
            groups = group(rows: rows, now: now)
        } catch {
            groups = []
            totalCount = 0
        }
    }

    private func buildRows(contacts: [Contact], now: Date) -> [UpcomingRowState] {
        let horizonEnd = now.addingTimeInterval(TimeInterval(horizonDays) * 86_400)
        var rows: [UpcomingRowState] = []

        for contact in contacts {
            // Cadence reminders
            if let cadence = contact.cadenceDays {
                let last = contact.lastInteractedAt ?? contact.createdAt
                let overdueAt = last.addingTimeInterval(TimeInterval(cadence) * 86_400)
                let target = max(now, overdueAt)
                let fires = engine.nextAllowedSlot(from: target, in: window)
                if fires <= horizonEnd, fires >= now {
                    rows.append(UpcomingRowState(
                        id: UUID(),
                        contactId: contact.id,
                        name: contact.displayName,
                        kind: .cadence,
                        scheduledFor: fires,
                        channel: contact.preferredChannel,
                        cadenceText: CadenceDescriptor.describe(days: cadence),
                        occasionText: nil,
                        timeOfDayText: Self.format(time: fires, timezone: window.timeZone),
                        dayHeader: Self.format(dayHeader: fires, now: now, timezone: window.timeZone)
                    ))
                }
            }
        }

        return rows.sorted { $0.scheduledFor < $1.scheduledFor }
    }

    private func group(rows: [UpcomingRowState], now: Date) -> [(header: String, rows: [UpcomingRowState])] {
        var ordered: [(String, [UpcomingRowState])] = []
        var seen: [String: Int] = [:]
        for row in rows {
            if let idx = seen[row.dayHeader] {
                ordered[idx].1.append(row)
            } else {
                seen[row.dayHeader] = ordered.count
                ordered.append((row.dayHeader, [row]))
            }
        }
        return ordered
    }

    static func format(time: Date, timezone: TimeZone) -> String {
        let df = DateFormatter()
        df.timeZone = timezone
        df.dateFormat = "h:mm a"
        df.amSymbol = "am"
        df.pmSymbol = "pm"
        return df.string(from: time).lowercased()
    }

    static func format(dayHeader date: Date, now: Date, timezone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone
        let today = calendar.startOfDay(for: now)
        let day = calendar.startOfDay(for: date)
        let diff = calendar.dateComponents([.day], from: today, to: day).day ?? 0

        let df = DateFormatter()
        df.timeZone = timezone
        df.dateFormat = "EEE MMM d"
        let suffix = df.string(from: date)

        if diff == 0 { return "Today · \(suffix)" }
        if diff == 1 { return "Tomorrow · \(suffix)" }
        return suffix
    }
}
