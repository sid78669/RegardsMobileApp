import Foundation
import Testing
@testable import Regards

/// Tests for the platform-layer Contacts importer. Avoids `CNContactStore`
/// entirely by injecting a `FakeContactsSource`; the only thing CI runs
/// against is the in-memory GRDB DB plus the fake.
struct ContactsImporterTests {

    // MARK: - map(systemContact:now:) — pure rules

    @Test("Display name uses 'Given Family' when both are present")
    func mapDisplayNameFullName() {
        let sc = SystemContact(
            identifier: "id-1",
            givenName: "Priya",
            familyName: "Raghavan",
            phoneNumbers: ["+15555550100"],
            emailAddresses: [])
        let c = ContactsImporter.map(systemContact: sc, now: Self.now)
        #expect(c.displayName == "Priya Raghavan")
    }

    @Test("Display name falls back to the first phone number when name is empty")
    func mapDisplayNameFallsBackToPhone() {
        let sc = SystemContact(
            identifier: "id-2",
            givenName: "",
            familyName: "",
            phoneNumbers: ["+15555550101", "+15555550199"],
            emailAddresses: ["alex@example.com"])
        let c = ContactsImporter.map(systemContact: sc, now: Self.now)
        #expect(c.displayName == "+15555550101")
    }

    @Test("Display name falls back to the first email when name and phones are empty")
    func mapDisplayNameFallsBackToEmail() {
        let sc = SystemContact(
            identifier: "id-3",
            givenName: "",
            familyName: "",
            phoneNumbers: [],
            emailAddresses: ["alex@example.com"])
        let c = ContactsImporter.map(systemContact: sc, now: Self.now)
        #expect(c.displayName == "alex@example.com")
    }

    @Test("Display name falls back to 'Unknown' when nothing else is available")
    func mapDisplayNameFallsBackToUnknown() {
        let sc = SystemContact(
            identifier: "id-4",
            givenName: "",
            familyName: "",
            phoneNumbers: [],
            emailAddresses: [])
        let c = ContactsImporter.map(systemContact: sc, now: Self.now)
        #expect(c.displayName == "Unknown")
    }

    @Test("Preferred channel prefers phone over email when both exist")
    func mapPreferredChannelPrefersPhone() {
        let sc = SystemContact(
            identifier: "id-5",
            givenName: "Mom",
            familyName: "",
            phoneNumbers: ["+15555550200"],
            emailAddresses: ["mom@example.com"])
        let c = ContactsImporter.map(systemContact: sc, now: Self.now)
        #expect(c.preferredChannel == .phoneCall)
        #expect(c.preferredChannelValue == "+15555550200")
    }

    @Test("Preferred channel falls back to email when no phone is present")
    func mapPreferredChannelFallsBackToEmail() {
        let sc = SystemContact(
            identifier: "id-6",
            givenName: "Alex",
            familyName: "",
            phoneNumbers: [],
            emailAddresses: ["alex@example.com"])
        let c = ContactsImporter.map(systemContact: sc, now: Self.now)
        #expect(c.preferredChannel == .email)
        #expect(c.preferredChannelValue == "alex@example.com")
    }

    @Test("Imported contacts always start with tracked == false")
    func mapImportsAreUntracked() {
        let sc = SystemContact(
            identifier: "id-7",
            givenName: "Sam", familyName: "",
            phoneNumbers: ["+15555550300"], emailAddresses: [])
        let c = ContactsImporter.map(systemContact: sc, now: Self.now)
        #expect(c.tracked == false)
        #expect(c.cadenceDays == nil)
    }

    @Test("systemContactRef carries the platform identifier through unchanged")
    func mapPreservesIdentifier() {
        let sc = SystemContact(
            identifier: "ABCDEFGH-1234-5678-9012-ABCDEFGHIJKL",
            givenName: "Ref", familyName: "Test",
            phoneNumbers: ["+15555550400"], emailAddresses: [])
        let c = ContactsImporter.map(systemContact: sc, now: Self.now)
        #expect(c.systemContactRef == "ABCDEFGH-1234-5678-9012-ABCDEFGHIJKL")
    }

    // MARK: - runFirstLaunchImport — orchestration

    @Test("Empty source returns 0 imported, 0 skipped")
    func runImportEmptySource() async throws {
        let source = FakeContactsSource(status: .authorized, contacts: [])
        let repo = GRDBRepositories(
            dbQueue: try DatabaseFactory.makeInMemoryDatabase()).contacts
        let importer = ContactsImporter(source: source, repo: repo,
                                        clock: { Self.now })

        let result = try await importer.runFirstLaunchImport()
        #expect(result == .init(imported: 0, skipped: 0))
        #expect(try await repo.fetchAll().isEmpty)
    }

    @Test("All-new contacts are inserted with imported counter equal to source count")
    func runImportAllNew() async throws {
        let sources = [
            SystemContact(identifier: "id-A", givenName: "Priya", familyName: "R",
                          phoneNumbers: ["+15555550501"], emailAddresses: []),
            SystemContact(identifier: "id-B", givenName: "Mom", familyName: "",
                          phoneNumbers: ["+15555550502"], emailAddresses: []),
            SystemContact(identifier: "id-C", givenName: "Alex", familyName: "Chen",
                          phoneNumbers: [], emailAddresses: ["alex@example.com"]),
        ]
        let source = FakeContactsSource(status: .authorized, contacts: sources)
        let repo = GRDBRepositories(
            dbQueue: try DatabaseFactory.makeInMemoryDatabase()).contacts
        let importer = ContactsImporter(source: source, repo: repo,
                                        clock: { Self.now })

        let result = try await importer.runFirstLaunchImport()
        #expect(result == .init(imported: 3, skipped: 0))
        #expect(try await repo.fetchAll().count == 3)
    }

    @Test("Contacts already in the DB are skipped, not duplicated or modified")
    func runImportSkipsExisting() async throws {
        let queue = try DatabaseFactory.makeInMemoryDatabase()
        let repo = GRDBRepositories(dbQueue: queue).contacts

        // Pre-seed an existing contact whose systemContactRef matches one
        // the source will return. The importer should leave it alone, not
        // overwrite with the system version.
        let preExisting = Contact(
            systemContactRef: "id-already-here",
            displayName: "Custom Name (user-edited)",
            tracked: true, cadenceDays: 14,
            preferredChannel: .whatsapp,
            preferredChannelValue: "+15555550600")
        try await repo.upsert(preExisting)

        let sources = [
            SystemContact(identifier: "id-already-here",
                          givenName: "System", familyName: "Name",
                          phoneNumbers: ["+15555550600"], emailAddresses: []),
            SystemContact(identifier: "id-new",
                          givenName: "New", familyName: "Person",
                          phoneNumbers: ["+15555550601"], emailAddresses: []),
        ]
        let source = FakeContactsSource(status: .authorized, contacts: sources)
        let importer = ContactsImporter(source: source, repo: repo,
                                        clock: { Self.now })

        let result = try await importer.runFirstLaunchImport()
        #expect(result == .init(imported: 1, skipped: 1))

        // The pre-existing row must still have its user-edited fields.
        let reloaded = try await repo.fetch(id: preExisting.id)
        #expect(reloaded?.displayName == "Custom Name (user-edited)")
        #expect(reloaded?.tracked == true)
        #expect(reloaded?.cadenceDays == 14)
    }

    @Test("Importer throws notAuthorized when current status isn't authorized or limited")
    func runImportThrowsWhenNotAuthorized() async throws {
        let queue = try DatabaseFactory.makeInMemoryDatabase()
        let repo = GRDBRepositories(dbQueue: queue).contacts
        let source = FakeContactsSource(status: .denied, contacts: [])
        let importer = ContactsImporter(source: source, repo: repo,
                                        clock: { Self.now })

        // do-catch is intentional over `#expect(throws:)` so the matched
        // status value can be asserted directly.
        do {
            _ = try await importer.runFirstLaunchImport()
            Issue.record("Expected ContactsImporter.ImportError.notAuthorized")
        } catch let ContactsImporter.ImportError.notAuthorized(status) {
            #expect(status == .denied)
        }
    }

    @Test("Limited authorization is treated as authorized for import purposes")
    func runImportAcceptsLimitedAuthorization() async throws {
        let source = FakeContactsSource(
            status: .limited,
            contacts: [SystemContact(identifier: "id-lim",
                                     givenName: "Visible", familyName: "Subset",
                                     phoneNumbers: ["+15555550700"],
                                     emailAddresses: [])])
        let repo = GRDBRepositories(
            dbQueue: try DatabaseFactory.makeInMemoryDatabase()).contacts
        let importer = ContactsImporter(source: source, repo: repo,
                                        clock: { Self.now })

        let result = try await importer.runFirstLaunchImport()
        #expect(result == .init(imported: 1, skipped: 0))
    }

    // MARK: - Helpers

    private static let now = Date(timeIntervalSince1970: 1_800_000_000)
}

// MARK: - FakeContactsSource

/// In-memory `ContactsSource` for tests. Status is fixed at construction;
/// call `setStatus` between import passes to simulate the user changing
/// permission. `requestAccess` reports the current status without touching
/// the system.
private final class FakeContactsSource: ContactsSource, @unchecked Sendable {
    private let lock = NSLock()
    private var status: ContactsAuthorizationStatus
    private var contacts: [SystemContact]

    init(status: ContactsAuthorizationStatus, contacts: [SystemContact]) {
        self.status = status
        self.contacts = contacts
    }

    func currentAuthorization() async -> ContactsAuthorizationStatus {
        lock.withLock { status }
    }

    func requestAccess() async throws -> ContactsAuthorizationStatus {
        lock.withLock { status }
    }

    func fetchAllContacts() async throws -> [SystemContact] {
        lock.withLock { contacts }
    }
}
