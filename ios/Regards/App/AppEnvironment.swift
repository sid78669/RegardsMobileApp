import Foundation

/// Bundle of repositories the UI layer needs. Injected at the root view so
/// swapping mock ↔ GRDB-backed repos is a one-line change (Phase 1 flips the
/// factory to `GRDBRepositories`).
public struct AppEnvironment: Sendable {
    public let contacts: any ContactRepository
    public let groups: any ContactGroupRepository
    public let reminders: any ReminderRepository
    public let interactions: any InteractionRepository
    public let window: any ReminderWindowRepository
    public let profile: any UserProfileRepository

    public init(
        contacts: any ContactRepository,
        groups: any ContactGroupRepository,
        reminders: any ReminderRepository,
        interactions: any InteractionRepository,
        window: any ReminderWindowRepository,
        profile: any UserProfileRepository
    ) {
        self.contacts = contacts
        self.groups = groups
        self.reminders = reminders
        self.interactions = interactions
        self.window = window
        self.profile = profile
    }

    /// Phase 0 default — MockRepositories seeded with the JSX cast.
    public static func makeMock(now: Date = MockRepositories.defaultNow) -> AppEnvironment {
        let mocks = MockRepositories(now: now)
        return AppEnvironment(
            contacts: mocks.contacts,
            groups: mocks.groups,
            reminders: mocks.reminders,
            interactions: mocks.interactions,
            window: mocks.window,
            profile: mocks.profile
        )
    }
}
