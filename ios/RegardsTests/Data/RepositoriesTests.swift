import Foundation
import Testing
import GRDB
@testable import Regards

/// CRUD round-trip coverage for every `*Repository` protocol against an
/// in-memory GRDB DB. `DatabaseMigratorTests` covers schema + migration plus
/// the basic Contact / Reminder happy paths; this suite fills in the methods
/// those don't exercise (fetchTracked, fetchMembers, archive, group CRUD,
/// fetchPending(forContact:), reminder delete, interaction fetchRecent
/// ordering, ReminderWindow + UserProfile singleton overwrites).
struct RepositoriesTests {

    // MARK: - ContactRepository

    @Test("fetchTracked filters out untracked and archived contacts")
    func fetchTrackedFiltersUntrackedAndArchived() async throws {
        let queue = try DatabaseFactory.makeInMemoryDatabase()
        let repo = GRDBRepositories(dbQueue: queue).contacts

        let tracked = Contact(
            systemContactRef: "sys-tracked",
            displayName: "Tracked Tina",
            tracked: true, cadenceDays: 14,
            preferredChannel: .phoneCall, preferredChannelValue: "+15555550100")
        let untracked = Contact(
            systemContactRef: "sys-untracked",
            displayName: "Untracked Ulysses",
            tracked: false,
            preferredChannel: .phoneCall, preferredChannelValue: "+15555550101")
        let archived = Contact(
            systemContactRef: "sys-archived",
            displayName: "Archived Aisha",
            tracked: true, cadenceDays: 30,
            preferredChannel: .sms, preferredChannelValue: "+15555550102")

        try await repo.upsert(tracked)
        try await repo.upsert(untracked)
        try await repo.upsert(archived)
        try await repo.archive(id: archived.id, at: Date(timeIntervalSince1970: 1_800_000_000))

        let result = try await repo.fetchTracked()
        #expect(result.map(\.id) == [tracked.id])
    }

    @Test("fetchMembers returns only contacts with the given contactGroupId")
    func fetchMembersByGroup() async throws {
        let queue = try DatabaseFactory.makeInMemoryDatabase()
        let repos = GRDBRepositories(dbQueue: queue)

        let primary = Contact(
            systemContactRef: "sys-mom-personal",
            displayName: "Mom (personal)",
            tracked: true, preferredChannel: .phoneCall,
            preferredChannelValue: "+15555550200")
        try await repos.contacts.upsert(primary)

        let group = ContactGroup(
            displayName: "Mom",
            primaryContactId: primary.id,
            createdBy: .user)
        try await repos.groups.upsert(group)

        let member1 = Contact(
            systemContactRef: "sys-mom-personal-2",
            displayName: "Mom (work)",
            contactGroupId: group.id,
            preferredChannel: .email,
            preferredChannelValue: "")
        let member2 = Contact(
            systemContactRef: "sys-mom-whatsapp",
            displayName: "Mom (WhatsApp)",
            contactGroupId: group.id,
            preferredChannel: .whatsapp,
            preferredChannelValue: "+15555550201")
        let unrelated = Contact(
            systemContactRef: "sys-other",
            displayName: "Not Mom",
            preferredChannel: .phoneCall,
            preferredChannelValue: "+15555550999")

        // Set the group reference on the primary too, so all 3 are members.
        var primaryWithGroup = primary
        primaryWithGroup.contactGroupId = group.id
        try await repos.contacts.upsert(primaryWithGroup)
        try await repos.contacts.upsert(member1)
        try await repos.contacts.upsert(member2)
        try await repos.contacts.upsert(unrelated)

        let members = try await repos.contacts.fetchMembers(ofGroup: group.id)
        #expect(Set(members.map(\.id)) == Set([primary.id, member1.id, member2.id]))
    }

    @Test("archive sets archivedAt; fetch by id still returns the row")
    func archivePersistsArchivedAt() async throws {
        let queue = try DatabaseFactory.makeInMemoryDatabase()
        let repo = GRDBRepositories(dbQueue: queue).contacts

        let c = Contact(
            systemContactRef: "sys-arch",
            displayName: "To Archive",
            preferredChannel: .phoneCall,
            preferredChannelValue: "+15555550300")
        try await repo.upsert(c)

        let archivedAt = Date(timeIntervalSince1970: 1_800_000_000)
        try await repo.archive(id: c.id, at: archivedAt)

        let loaded = try await repo.fetch(id: c.id)
        #expect(loaded?.archivedAt == archivedAt)
        #expect(loaded?.isActive == false)
    }

    // MARK: - ContactGroupRepository

    @Test("ContactGroup upsert / fetchAll / fetch(id:) round-trips and delete removes the row")
    func contactGroupCRUD() async throws {
        let queue = try DatabaseFactory.makeInMemoryDatabase()
        let repos = GRDBRepositories(dbQueue: queue)

        let primary = Contact(
            systemContactRef: "sys-grp-primary",
            displayName: "Group Primary",
            preferredChannel: .phoneCall,
            preferredChannelValue: "+15555550400")
        try await repos.contacts.upsert(primary)

        let group = ContactGroup(
            displayName: "Family",
            primaryContactId: primary.id,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            createdBy: .suggestionAccepted)
        try await repos.groups.upsert(group)

        let all = try await repos.groups.fetchAll()
        #expect(all.count == 1)
        #expect(all.first?.displayName == "Family")
        #expect(all.first?.createdBy == .suggestionAccepted)

        let one = try await repos.groups.fetch(id: group.id)
        #expect(one == group)

        try await repos.groups.delete(id: group.id)
        let after = try await repos.groups.fetchAll()
        #expect(after.isEmpty)
    }

    // MARK: - ReminderRepository

    @Test("fetchPending(forContact:) filters by contact and ignores fired reminders")
    func fetchPendingByContact() async throws {
        let queue = try DatabaseFactory.makeInMemoryDatabase()
        let repos = GRDBRepositories(dbQueue: queue)

        let alex = Contact(
            systemContactRef: "sys-alex",
            displayName: "Alex",
            tracked: true, cadenceDays: 30,
            preferredChannel: .phoneCall,
            preferredChannelValue: "+15555550500")
        let jordan = Contact(
            systemContactRef: "sys-jordan",
            displayName: "Jordan",
            tracked: true, cadenceDays: 30,
            preferredChannel: .sms,
            preferredChannelValue: "+15555550501")
        try await repos.contacts.upsert(alex)
        try await repos.contacts.upsert(jordan)

        let alexPending = ScheduledReminder(
            contactId: alex.id, kind: .cadence,
            scheduledFor: Date(timeIntervalSince1970: 1_800_000_000),
            osNotificationId: "n-alex-1")
        let alexFired = ScheduledReminder(
            contactId: alex.id, kind: .cadence,
            scheduledFor: Date(timeIntervalSince1970: 1_700_000_000),
            osNotificationId: "n-alex-2", state: .fired)
        let jordanPending = ScheduledReminder(
            contactId: jordan.id, kind: .birthday,
            occasionDate: "06-15", occasionLabel: "Birthday",
            scheduledFor: Date(timeIntervalSince1970: 1_900_000_000),
            osNotificationId: "n-jordan-1")
        try await repos.reminders.upsert(alexPending)
        try await repos.reminders.upsert(alexFired)
        try await repos.reminders.upsert(jordanPending)

        let alexResult = try await repos.reminders.fetchPending(forContact: alex.id)
        #expect(alexResult.map(\.id) == [alexPending.id])

        let jordanResult = try await repos.reminders.fetchPending(forContact: jordan.id)
        #expect(jordanResult.map(\.id) == [jordanPending.id])
    }

    @Test("Reminder delete removes the row from fetchAllPending")
    func reminderDeleteRemovesRow() async throws {
        let queue = try DatabaseFactory.makeInMemoryDatabase()
        let repos = GRDBRepositories(dbQueue: queue)

        let c = Contact(
            systemContactRef: "sys-del",
            displayName: "Delete Target",
            preferredChannel: .phoneCall,
            preferredChannelValue: "+15555550600")
        try await repos.contacts.upsert(c)

        let r = ScheduledReminder(
            contactId: c.id, kind: .cadence,
            scheduledFor: Date(timeIntervalSince1970: 1_800_000_000),
            osNotificationId: "n-del")
        try await repos.reminders.upsert(r)
        #expect(try await repos.reminders.fetchAllPending().count == 1)

        try await repos.reminders.delete(id: r.id)
        #expect(try await repos.reminders.fetchAllPending().isEmpty)
    }

    // MARK: - InteractionRepository

    @Test("fetchRecent returns logs newest-first up to limit")
    func interactionFetchRecentOrdersAndLimits() async throws {
        let queue = try DatabaseFactory.makeInMemoryDatabase()
        let repos = GRDBRepositories(dbQueue: queue)

        let c = Contact(
            systemContactRef: "sys-int",
            displayName: "Interactor",
            preferredChannel: .phoneCall,
            preferredChannelValue: "+15555550700")
        try await repos.contacts.upsert(c)

        let oldest = InteractionLog(
            contactId: c.id,
            occurredAt: Date(timeIntervalSince1970: 1_700_000_000),
            source: .manual, channel: .phoneCall)
        let middle = InteractionLog(
            contactId: c.id,
            occurredAt: Date(timeIntervalSince1970: 1_750_000_000),
            source: .reminderTap, channel: .whatsapp)
        let newest = InteractionLog(
            contactId: c.id,
            occurredAt: Date(timeIntervalSince1970: 1_800_000_000),
            source: .reminderCaughtUp)
        try await repos.interactions.append(oldest)
        try await repos.interactions.append(middle)
        try await repos.interactions.append(newest)

        let limited = try await repos.interactions.fetchRecent(forContact: c.id, limit: 2)
        #expect(limited.map(\.id) == [newest.id, middle.id])
    }

    @Test("fetchRecent ignores logs from a different contact")
    func interactionFetchRecentScopesByContact() async throws {
        let queue = try DatabaseFactory.makeInMemoryDatabase()
        let repos = GRDBRepositories(dbQueue: queue)

        let me = Contact(
            systemContactRef: "sys-me",
            displayName: "Me",
            preferredChannel: .phoneCall,
            preferredChannelValue: "+15555550800")
        let other = Contact(
            systemContactRef: "sys-other",
            displayName: "Other",
            preferredChannel: .phoneCall,
            preferredChannelValue: "+15555550801")
        try await repos.contacts.upsert(me)
        try await repos.contacts.upsert(other)

        try await repos.interactions.append(InteractionLog(
            contactId: me.id,
            occurredAt: Date(timeIntervalSince1970: 1_800_000_000),
            source: .manual))
        try await repos.interactions.append(InteractionLog(
            contactId: other.id,
            occurredAt: Date(timeIntervalSince1970: 1_800_000_000),
            source: .manual))

        let mine = try await repos.interactions.fetchRecent(forContact: me.id, limit: 10)
        #expect(mine.count == 1)
        #expect(mine.first?.contactId == me.id)
    }

    // MARK: - ReminderWindowRepository

    @Test("ReminderWindow singleton: migrator seeds it; saveGlobal overwrites")
    func reminderWindowSingletonOverwrite() async throws {
        let queue = try DatabaseFactory.makeInMemoryDatabase()
        let repo = GRDBRepositories(dbQueue: queue).window

        // Migrator seeded a row; fetch should succeed.
        let seeded = try await repo.fetchGlobal()
        #expect(seeded.allowedTimeRanges.isEmpty == false)

        let updated = ReminderWindow(
            allowedDays: .all,
            allowedTimeRanges: [TimeRange(start: TimeOfDay(hour: 9), end: TimeOfDay(hour: 10))],
            quietHours: nil,
            timezoneIdentifier: "America/Los_Angeles")
        try await repo.saveGlobal(updated)

        let reloaded = try await repo.fetchGlobal()
        #expect(reloaded.allowedDays == .all)
        #expect(reloaded.allowedTimeRanges.count == 1)
        #expect(reloaded.timezoneIdentifier == "America/Los_Angeles")
        #expect(reloaded.quietHours == nil)
    }

    // MARK: - UserProfileRepository

    @Test("UserProfile singleton: migrator seeds defaults; save overwrites")
    func userProfileSingletonOverwrite() async throws {
        let queue = try DatabaseFactory.makeInMemoryDatabase()
        let repo = GRDBRepositories(dbQueue: queue).profile

        let seeded = try await repo.fetch()
        #expect(seeded.entitlementTier == .free)
        #expect(seeded.onboardingCompletedAt == nil)

        let onboardingDate = Date(timeIntervalSince1970: 1_800_000_000)
        let refreshedAt = Date(timeIntervalSince1970: 1_800_500_000)
        try await repo.save(UserProfile(
            onboardingCompletedAt: onboardingDate,
            entitlementTier: .lifetime,
            entitlementRefreshedAt: refreshedAt))

        let reloaded = try await repo.fetch()
        #expect(reloaded.onboardingCompletedAt == onboardingDate)
        #expect(reloaded.entitlementTier == .lifetime)
        #expect(reloaded.entitlementRefreshedAt == refreshedAt)
    }
}
