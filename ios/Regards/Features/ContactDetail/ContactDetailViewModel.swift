import Foundation
import Observation

@Observable @MainActor
public final class ContactDetailViewModel {

    public struct InteractionEntry: Sendable, Identifiable, Equatable {
        public let id: UUID
        public let dateLabel: String
        public let descriptionLabel: String
    }

    public private(set) var contact: Contact?
    public private(set) var interactions: [InteractionEntry] = []

    private let contacts: any ContactRepository
    private let interactionsRepo: any InteractionRepository
    private let contactId: UUID
    private let clock: () -> Date

    public init(contactId: UUID,
                contacts: any ContactRepository,
                interactionsRepo: any InteractionRepository,
                clock: @escaping () -> Date = { Date() }) {
        self.contactId = contactId
        self.contacts = contacts
        self.interactionsRepo = interactionsRepo
        self.clock = clock
    }

    public func load() async {
        do {
            contact = try await contacts.fetch(id: contactId)
            let logs = try await interactionsRepo.fetchRecent(forContact: contactId, limit: 8)
            interactions = logs.map(Self.toEntry)
        } catch {
            Self.log.error("failed to load contact \(self.contactId, privacy: .public): \(error, privacy: .public)")
            contact = nil
            interactions = []
        }
    }

    static let log = RegardsLogger.feature("ContactDetail")

    // MARK: - Formatters (constructed once, locale-pinned)

    static let shortDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "MMM d"
        return df
    }()

    static func toEntry(_ log: InteractionLog) -> InteractionEntry {
        let channel = log.channel?.displayName ?? "Manual"
        let source: String
        switch log.source {
        case .manual:             source = "manual log"
        case .reminderTap:        source = "reminder tap"
        case .reminderCaughtUp:   source = "reminder caught up"
        }
        return InteractionEntry(
            id: log.id,
            dateLabel: shortDateFormatter.string(from: log.occurredAt),
            descriptionLabel: "\(channel) · \(source)"
        )
    }

    // MARK: - Derived strings for the view

    public var priorityLabel: String {
        switch contact?.priorityTier {
        case .innerCircle?:  return "inner circle"
        case .close?:        return "close friend"
        case .regular?:      return "regular"
        case .acquaintance?: return "acquaintance"
        case nil:            return ""
        }
    }

    public var cadenceLabel: String {
        guard let days = contact?.cadenceDays else { return "not tracked" }
        return CadenceDescriptor.describe(days: days)
    }

    public var overdueSummary: (days: Int, isOverdue: Bool) {
        guard let c = contact, let cadence = c.cadenceDays,
              let last = c.lastInteractedAt else {
            return (0, false)
        }
        let overdueAt = last.addingTimeInterval(TimeInterval(cadence) * 86_400)
        // Calendar-based day delta to honor DST and timezone boundaries.
        let days = Calendar.current.dateComponents([.day], from: overdueAt, to: clock()).day ?? 0
        return (max(0, days), days > 0)
    }

    public var lastTalkedLabel: String {
        guard let last = contact?.lastInteractedAt else { return "never" }
        let rel = Contact.relativeDescription(for: last, from: clock()) ?? "—"
        return "\(rel) · \(Self.shortDateFormatter.string(from: last))"
    }
}
