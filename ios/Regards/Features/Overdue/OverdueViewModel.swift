import Foundation
import Observation

/// Shape the view renders per contact — precomputed in the view model so the
/// view body stays formatting-free.
public struct OverdueRowState: Sendable, Identifiable, Equatable {
    public var id: UUID { contactId }
    public let contactId: UUID
    public let name: String
    public let priority: PriorityTier
    public let isVirtualMerged: Bool
    public let overdueDays: Int
    public let cadenceText: String
    public let lastInteractedText: String?
    public let channel: Channel
    public let channelLabel: String
    public let channelValue: String
    public let accessibilityLabel: String
}

@Observable
public final class OverdueViewModel: @unchecked Sendable {

    public enum Tab: Hashable, Sendable { case overdue, upcoming }

    public var selectedTab: Tab = .overdue
    public private(set) var rows: [OverdueRowState] = []
    public private(set) var nextDigestLabel: String = "next digest at 6:00 pm"

    private let contacts: any ContactRepository
    private let clock: @Sendable () -> Date

    public init(contacts: any ContactRepository,
                clock: @escaping @Sendable () -> Date = { Date() }) {
        self.contacts = contacts
        self.clock = clock
    }

    public func load() async {
        do {
            let all = try await contacts.fetchTracked()
            let now = clock()
            rows = all.compactMap { contact in
                Self.makeOverdueRow(for: contact, now: now)
            }
            .filter { $0.overdueDays > 0 }
            .sorted {
                if $0.priority.rawValue != $1.priority.rawValue {
                    return $0.priority.rawValue < $1.priority.rawValue
                }
                return $0.overdueDays > $1.overdueDays
            }
        } catch {
            rows = []
        }
    }

    public var innerCircleRows: [OverdueRowState] { rows.filter { $0.priority == .innerCircle } }
    public var closeFriendRows: [OverdueRowState] { rows.filter { $0.priority == .close } }
    public var otherRows: [OverdueRowState] {
        rows.filter { $0.priority == .regular || $0.priority == .acquaintance }
    }

    public var overdueCount: Int { rows.count }

    static func makeOverdueRow(for contact: Contact, now: Date) -> OverdueRowState? {
        guard contact.tracked, let cadenceDays = contact.cadenceDays else { return nil }
        let last = contact.lastInteractedAt ?? contact.createdAt
        let overdueAt = last.addingTimeInterval(TimeInterval(cadenceDays) * 86_400)
        let overdueSeconds = now.timeIntervalSince(overdueAt)
        let overdueDays = Int(overdueSeconds / 86_400)

        let context = Contact.AccessibilityContext(
            now: now,
            effectiveLastInteractedAt: contact.lastInteractedAt,
            isOverdue: overdueDays > 0,
            overdueDays: max(0, overdueDays)
        )

        return OverdueRowState(
            contactId: contact.id,
            name: contact.displayName,
            priority: contact.priorityTier,
            isVirtualMerged: contact.contactGroupId != nil,
            overdueDays: max(0, overdueDays),
            cadenceText: CadenceDescriptor.describe(days: cadenceDays),
            lastInteractedText: contact.lastInteractedAt.flatMap {
                Contact.relativeDescription(for: $0, from: now)
            },
            channel: contact.preferredChannel,
            channelLabel: contact.preferredChannel.displayName,
            channelValue: contact.preferredChannelValue,
            accessibilityLabel: contact.accessibilityLabel(context: context)
        )
    }
}
