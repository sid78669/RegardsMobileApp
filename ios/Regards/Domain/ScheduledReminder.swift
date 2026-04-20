import Foundation

/// Why a reminder exists (ARCHITECTURE.md §7, §9).
public enum ReminderKind: String, Codable, Sendable, CaseIterable {
    case cadence
    case birthday
    case anniversary
    case customOccasion = "custom_occasion"
}

/// Lifecycle state of a scheduled reminder.
public enum ReminderState: String, Codable, Sendable, CaseIterable {
    case pending
    case fired
    case cancelled
    case userCaughtUp = "user_caught_up"
}

/// A single scheduled reminder (ARCHITECTURE.md §7). The concrete OS-level
/// notification identifier (`osNotificationId`) lets the platform adapter
/// cancel/replace it when the engine reschedules.
public struct ScheduledReminder: Sendable, Codable, Equatable, Hashable, Identifiable {
    public let id: UUID
    public let contactId: UUID
    public var kind: ReminderKind
    /// ISO month-day (e.g. "02-29") for annual-recurrence kinds; nil for cadence.
    public var occasionDate: String?
    /// Free-text label for anniversaries / custom occasions.
    public var occasionLabel: String?
    public var scheduledFor: Date
    public var osNotificationId: String
    public var state: ReminderState

    public init(
        id: UUID = UUID(),
        contactId: UUID,
        kind: ReminderKind,
        occasionDate: String? = nil,
        occasionLabel: String? = nil,
        scheduledFor: Date,
        osNotificationId: String,
        state: ReminderState = .pending
    ) {
        self.id = id
        self.contactId = contactId
        self.kind = kind
        self.occasionDate = occasionDate
        self.occasionLabel = occasionLabel
        self.scheduledFor = scheduledFor
        self.osNotificationId = osNotificationId
        self.state = state
    }
}
