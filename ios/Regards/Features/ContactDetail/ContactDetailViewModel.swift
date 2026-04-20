import Foundation
import Observation

@Observable
public final class ContactDetailViewModel: @unchecked Sendable {

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
    private let clock: @Sendable () -> Date

    public init(contactId: UUID,
                contacts: any ContactRepository,
                interactionsRepo: any InteractionRepository,
                clock: @escaping @Sendable () -> Date = { Date() }) {
        self.contactId = contactId
        self.contacts = contacts
        self.interactionsRepo = interactionsRepo
        self.clock = clock
    }

    public func load() async {
        contact = try? await contacts.fetch(id: contactId)
        if let logs = try? await interactionsRepo.fetchRecent(forContact: contactId, limit: 8) {
            interactions = logs.map(Self.toEntry)
        }
    }

    static func toEntry(_ log: InteractionLog) -> InteractionEntry {
        let df = DateFormatter()
        df.dateFormat = "MMM d"
        let channel = log.channel?.displayName ?? "Manual"
        let source: String
        switch log.source {
        case .manual:             source = "manual log"
        case .reminderTap:        source = "reminder tap"
        case .reminderCaughtUp:   source = "reminder caught up"
        }
        return InteractionEntry(
            id: log.id,
            dateLabel: df.string(from: log.occurredAt),
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
        let days = Int(clock().timeIntervalSince(overdueAt) / 86_400)
        return (max(0, days), days > 0)
    }

    public var lastTalkedLabel: String {
        guard let last = contact?.lastInteractedAt else { return "never" }
        let rel = Contact.relativeDescription(for: last, from: clock()) ?? "—"
        let df = DateFormatter()
        df.dateFormat = "MMM d"
        return "\(rel) · \(df.string(from: last))"
    }
}
