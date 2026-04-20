import Foundation
import Testing
@testable import Regards

struct DuplicateDetectorTests {

    @Test("Name + phone match is high confidence")
    func highConfidenceNameAndPhone() {
        let a = UUID(); let b = UUID()
        let input = [
            DuplicateDetector.Input(contactId: a, displayName: "Mom",
                                     phones: ["(415) 555-0134"], emails: []),
            DuplicateDetector.Input(contactId: b, displayName: "Mom",
                                     phones: ["+1 415 555 0134"], emails: []),
        ]
        let pairs = DuplicateDetector().candidates(from: input)
        #expect(pairs.count == 1)
        #expect(pairs.first?.confidence == .high)
        #expect(pairs.first?.rationale == "name + phone")
    }

    @Test("Shared phone only still produces high confidence")
    func highConfidencePhoneOnly() {
        let a = UUID(); let b = UUID()
        let input = [
            DuplicateDetector.Input(contactId: a, displayName: "Alex Chen",
                                     phones: ["+14155550198"], emails: ["alex@chen.me"]),
            DuplicateDetector.Input(contactId: b, displayName: "Alex C.",
                                     phones: ["+14155550198"], emails: []),
        ]
        let pairs = DuplicateDetector().candidates(from: input)
        #expect(pairs.first?.confidence == .high)
        #expect(pairs.first?.rationale == "phone")
    }

    @Test("Shared email without shared phone is medium confidence")
    func mediumConfidenceEmail() {
        let a = UUID(); let b = UUID()
        let input = [
            DuplicateDetector.Input(contactId: a, displayName: "Jordan (work)",
                                     phones: ["+12125550176"], emails: ["jpark@work.co"]),
            DuplicateDetector.Input(contactId: b, displayName: "Jordan",
                                     phones: ["+12125550999"], emails: ["JPARK@WORK.co"]),
        ]
        let pairs = DuplicateDetector().candidates(from: input)
        #expect(pairs.first?.confidence == .medium)
    }

    @Test("Name-only match is low confidence")
    func lowConfidenceNameOnly() {
        let a = UUID(); let b = UUID()
        let input = [
            DuplicateDetector.Input(contactId: a, displayName: "Jordan Park",
                                     phones: [], emails: ["jpark@work.co"]),
            DuplicateDetector.Input(contactId: b, displayName: "jordan park",
                                     phones: [], emails: ["jordan.p@gmail.com"]),
        ]
        let pairs = DuplicateDetector().candidates(from: input)
        #expect(pairs.first?.confidence == .low)
    }

    @Test("International phone variants normalize to a single match")
    func internationalPhoneNormalization() {
        let a = UUID(); let b = UUID()
        let input = [
            DuplicateDetector.Input(contactId: a, displayName: "Priya",
                                     phones: ["+91 98765 43210"], emails: []),
            DuplicateDetector.Input(contactId: b, displayName: "Priya",
                                     phones: ["+919876543210"], emails: []),
        ]
        let pairs = DuplicateDetector().candidates(from: input)
        #expect(pairs.count == 1)
        #expect(pairs.first?.confidence == .high)
    }

    @Test("Diacritic / case differences still count as the same name")
    func diacriticNormalization() {
        #expect(DuplicateDetector.normalizeName("Noor Abbasi")
                == DuplicateDetector.normalizeName("noor  abbasi"))
        #expect(DuplicateDetector.normalizeName("José")
                == DuplicateDetector.normalizeName("jose"))
    }

    @Test("No candidates when there are no overlapping fields")
    func noFalsePositives() {
        let a = UUID(); let b = UUID()
        let input = [
            DuplicateDetector.Input(contactId: a, displayName: "Alex Chen",
                                     phones: ["+1"], emails: ["alex@chen.me"]),
            DuplicateDetector.Input(contactId: b, displayName: "Sam Okafor",
                                     phones: ["+2"], emails: ["sam@ok.co"]),
        ]
        let pairs = DuplicateDetector().candidates(from: input)
        #expect(pairs.isEmpty)
    }

    @Test("Results are ranked with high confidence first")
    func ranking() {
        let a = UUID(); let b = UUID(); let c = UUID(); let d = UUID()
        let input = [
            DuplicateDetector.Input(contactId: a, displayName: "X", phones: [], emails: ["q@q.com"]),
            DuplicateDetector.Input(contactId: b, displayName: "X", phones: [], emails: ["q@q.com"]),
            DuplicateDetector.Input(contactId: c, displayName: "Y", phones: ["+911"], emails: []),
            DuplicateDetector.Input(contactId: d, displayName: "y", phones: ["+911"], emails: []),
        ]
        let pairs = DuplicateDetector().candidates(from: input)
        #expect(pairs.first?.confidence == .high)
    }
}
