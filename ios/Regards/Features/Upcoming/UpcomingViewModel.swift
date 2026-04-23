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

@Observable @MainActor
public final class UpcomingViewModel {

    public private(set) var groups: [(header: String, rows: [UpcomingRowState])] = []
    public private(set) var totalCount: Int = 0

    public var horizonDays: Int = 14

    private let contacts: any ContactRepository
    private let engine: ReminderEngine
    private let window: ReminderWindow
    private let clock: () -> Date

    public init(contacts: any ContactRepository,
                engine: ReminderEngine = ReminderEngine(),
                window: ReminderWindow = .defaultV1(),
                clock: @escaping () -> Date = { Date() }) {
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
            groups = group(rows: rows)
        } catch {
            Self.log.error("failed to load upcoming reminders: \(error, privacy: .public)")
            groups = []
            totalCount = 0
        }
    }

    static let log = RegardsLogger.feature("Upcoming")

    // MARK: - Formatters (constructed once, locale-pinned)
    //
    // DateFormatter construction is slow and the format we want — "h:mm a"
    // with lowercase am/pm — is locale-sensitive without an explicit POSIX
    // pin. Static formatters are reused across every row render.
    static let timeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "h:mm a"
        df.amSymbol = "am"
        df.pmSymbol = "pm"
        return df
    }()

    static let dayHeaderSuffixFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "EEE MMM d"
        return df
    }()

    private func buildRows(contacts: [Contact], now: Date) -> [UpcomingRowState] {
        let horizonEnd = now.addingTimeInterval(TimeInterval(horizonDays) * 86_400)
        var rows: [UpcomingRowState] = []

        for contact in contacts {
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

    private func group(rows: [UpcomingRowState]) -> [(header: String, rows: [UpcomingRowState])] {
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
        timeFormatter.timeZone = timezone
        return timeFormatter.string(from: time).lowercased()
    }

    static func format(dayHeader date: Date, now: Date, timezone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone
        let today = calendar.startOfDay(for: now)
        let day = calendar.startOfDay(for: date)
        let diff = calendar.dateComponents([.day], from: today, to: day).day ?? 0

        dayHeaderSuffixFormatter.timeZone = timezone
        let suffix = dayHeaderSuffixFormatter.string(from: date)

        if diff == 0 { return "Today · \(suffix)" }
        if diff == 1 { return "Tomorrow · \(suffix)" }
        return suffix
    }
}
