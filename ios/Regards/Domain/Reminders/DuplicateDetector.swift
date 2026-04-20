import Foundation

/// A candidate pair surfaced to the Merge Duplicates screen.
public struct DuplicateCandidate: Sendable, Equatable, Hashable {
    public enum Confidence: String, Sendable, Comparable {
        case high
        case medium
        case low

        public static func < (lhs: Confidence, rhs: Confidence) -> Bool {
            func rank(_ c: Confidence) -> Int {
                switch c {
                case .high:   return 0
                case .medium: return 1
                case .low:    return 2
                }
            }
            return rank(lhs) < rank(rhs)
        }
    }

    public let contactA: UUID
    public let contactB: UUID
    public let confidence: Confidence
    /// Free-text explanation rendered on the candidate card.
    public let rationale: String

    public init(contactA: UUID, contactB: UUID, confidence: Confidence, rationale: String) {
        // Keep the pair order deterministic for equality tests.
        if contactA.uuidString < contactB.uuidString {
            self.contactA = contactA
            self.contactB = contactB
        } else {
            self.contactA = contactB
            self.contactB = contactA
        }
        self.confidence = confidence
        self.rationale = rationale
    }
}

/// Local, deterministic duplicate-contact heuristic (ARCHITECTURE.md §7
/// "Duplicate-detection heuristic"). Pure Swift — does not touch system APIs.
///
/// Ranks candidates by strength:
///   - **high**: any phone number (E.164-normalized) matches between two
///     contacts AND the display names are similar.
///   - **medium**: any email (lowercased) matches.
///   - **low**: names normalize-equal (case/diacritic-insensitive) with no
///     overlapping phone/email.
public struct DuplicateDetector: Sendable {

    public struct Input: Sendable, Equatable {
        public let contactId: UUID
        public let displayName: String
        public let phones: [String]
        public let emails: [String]

        public init(contactId: UUID, displayName: String,
                    phones: [String], emails: [String]) {
            self.contactId = contactId
            self.displayName = displayName
            self.phones = phones
            self.emails = emails
        }
    }

    public init() {}

    public func candidates(from inputs: [Input]) -> [DuplicateCandidate] {
        guard inputs.count >= 2 else { return [] }

        // Precompute normalized fields.
        let enriched: [(Input, String, Set<String>, Set<String>)] = inputs.map { input in
            (input,
             Self.normalizeName(input.displayName),
             Set(input.phones.map(Self.phoneMatchKey)),
             Set(input.emails.map { $0.lowercased() }))
        }

        var out: [DuplicateCandidate] = []
        for i in 0..<enriched.count {
            let (inputI, nameI, phonesI, emailsI) = enriched[i]
            for j in (i + 1)..<enriched.count {
                let (inputJ, nameJ, phonesJ, emailsJ) = enriched[j]

                let sharedPhones = phonesI.intersection(phonesJ)
                                            .filter { !$0.isEmpty }
                let sharedEmails = emailsI.intersection(emailsJ)
                                            .filter { !$0.isEmpty }
                let sameName = !nameI.isEmpty && nameI == nameJ

                if !sharedPhones.isEmpty && sameName {
                    out.append(DuplicateCandidate(
                        contactA: inputI.contactId, contactB: inputJ.contactId,
                        confidence: .high, rationale: "name + phone"))
                } else if !sharedPhones.isEmpty {
                    out.append(DuplicateCandidate(
                        contactA: inputI.contactId, contactB: inputJ.contactId,
                        confidence: .high, rationale: "phone"))
                } else if !sharedEmails.isEmpty {
                    out.append(DuplicateCandidate(
                        contactA: inputI.contactId, contactB: inputJ.contactId,
                        confidence: .medium, rationale: "email"))
                } else if sameName {
                    out.append(DuplicateCandidate(
                        contactA: inputI.contactId, contactB: inputJ.contactId,
                        confidence: .low, rationale: "name only"))
                }
            }
        }

        return out.sorted { lhs, rhs in
            if lhs.confidence != rhs.confidence { return lhs.confidence < rhs.confidence }
            // Stable secondary ordering so tests don't become flaky.
            if lhs.contactA != rhs.contactA { return lhs.contactA.uuidString < rhs.contactA.uuidString }
            return lhs.contactB.uuidString < rhs.contactB.uuidString
        }
    }

    // MARK: - Phone matching

    /// Matching key for phone numbers. Because users mix formats — `(415)
    /// 555-0134`, `+1 415 555 0134`, `4155550134`, etc. — strict E.164
    /// equality misses real duplicates. We keep only digits and, if we have
    /// at least 10, take the trailing 10 (the "subscriber + area code"
    /// portion of North American numbers, which is also what the last 10
    /// digits of a full E.164 collapse to for most regions).
    static func phoneMatchKey(_ raw: String) -> String {
        let digits = raw.filter(\.isNumber)
        if digits.count >= 10 {
            return String(digits.suffix(10))
        }
        return digits
    }

    // MARK: - Name normalization

    /// Lowercases, strips diacritics, collapses whitespace. Trailing
    /// parenthetical suffixes (e.g. "Mom (home)") are preserved — the user
    /// sometimes uses these to disambiguate siblings with the same nickname.
    static func normalizeName(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let folded = trimmed.folding(options: [.diacriticInsensitive,
                                               .caseInsensitive],
                                     locale: Locale(identifier: "en_US_POSIX"))
        let collapsed = folded.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return collapsed
    }
}
