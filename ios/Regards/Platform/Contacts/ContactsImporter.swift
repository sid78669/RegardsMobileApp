import Foundation

/// Orchestrates a one-shot first-launch import: read every contact the user
/// authorized us to see, map each into our `Contact` domain type, and insert
/// new rows into the `ContactRepository`. Existing rows (matched by
/// `systemContactRef`) are left alone — this importer is additive, not a
/// reconciler. Delete-detection and change-detection arrive in a follow-up
/// (ARCHITECTURE.md §7 "Re-import logic").
///
/// All imported contacts land as `tracked: false`. The user opts each contact
/// in from the All Contacts screen.
public struct ContactsImporter: Sendable {
    private let source: any ContactsSource
    private let repo: any ContactRepository
    private let clock: @Sendable () -> Date

    public init(
        source: any ContactsSource,
        repo: any ContactRepository,
        clock: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.source = source
        self.repo = repo
        self.clock = clock
    }

    /// Outcome of an import pass. `imported` is rows freshly written;
    /// `skipped` is rows the importer found already in the DB and left alone.
    public struct Result: Sendable, Equatable {
        public let imported: Int
        public let skipped: Int
    }

    /// Errors the importer surfaces to the caller.
    public enum ImportError: Error, Equatable {
        /// Caller invoked the importer without an authorized status.
        case notAuthorized(ContactsAuthorizationStatus)
    }

    /// Reads everything from the system store and inserts new rows.
    /// Throws `ImportError.notAuthorized` if the source's current status
    /// isn't `.authorized` or `.limited`.
    public func runFirstLaunchImport() async throws -> Result {
        let status = await source.currentAuthorization()
        guard status == .authorized || status == .limited else {
            throw ImportError.notAuthorized(status)
        }

        let systemContacts = try await source.fetchAllContacts()
        let existing = try await repo.fetchAll()
        let existingRefs = Set(existing.map(\.systemContactRef))

        var imported = 0
        var skipped = 0
        let now = clock()
        for sc in systemContacts {
            if existingRefs.contains(sc.identifier) {
                skipped += 1
                continue
            }
            try await repo.upsert(Self.map(systemContact: sc, now: now))
            imported += 1
        }
        return Result(imported: imported, skipped: skipped)
    }

    /// Pure mapping function. Exposed for unit tests so each translation
    /// rule can be checked without going through the importer's I/O.
    ///
    /// Mapping rules:
    /// - `displayName`: "Given Family", trimmed empties out. Falls back to
    ///   the first phone number, then the first email, then "Unknown".
    /// - `preferredChannel` + `preferredChannelValue`: first phone number
    ///   under `.phoneCall`. If no phones, first email under `.email`.
    ///   If neither, `.phoneCall` with empty value (user fills in later).
    /// - Phone numbers are NOT normalized to E.164 here; that's a follow-up.
    public static func map(systemContact sc: SystemContact, now: Date) -> Contact {
        let resolvedDisplayName: String
        if !sc.displayName.isEmpty {
            resolvedDisplayName = sc.displayName
        } else if let phone = sc.phoneNumbers.first {
            resolvedDisplayName = phone
        } else if let email = sc.emailAddresses.first {
            resolvedDisplayName = email
        } else {
            resolvedDisplayName = "Unknown"
        }

        let primaryPhone = sc.phoneNumbers.first ?? ""
        let primaryEmail = sc.emailAddresses.first ?? ""
        let preferredChannel: Channel
        let preferredChannelValue: String
        if !primaryPhone.isEmpty {
            preferredChannel = .phoneCall
            preferredChannelValue = primaryPhone
        } else if !primaryEmail.isEmpty {
            preferredChannel = .email
            preferredChannelValue = primaryEmail
        } else {
            preferredChannel = .phoneCall
            preferredChannelValue = ""
        }

        return Contact(
            systemContactRef: sc.identifier,
            displayName: resolvedDisplayName,
            tracked: false,
            preferredChannel: preferredChannel,
            preferredChannelValue: preferredChannelValue,
            createdAt: now)
    }
}
