import Foundation
import Testing
@testable import Regards

/// Parametric deep-link catalog test (ARCHITECTURE.md §13: "Deep-link catalog
/// test … parametric … one entry per channel"). Catches typos in the URL
/// templates and any drift between the channel enum and the builder.
struct DeepLinkBuilderTests {

    struct DeepLinkCase: Sendable {
        let channel: Channel
        let input: String
        let expected: String?
    }

    static let cases: [DeepLinkCase] = [
        .init(channel: .phoneCall,    input: "+1 (555) 123-4567", expected: "tel:+15551234567"),
        .init(channel: .sms,          input: "+15551234567",      expected: "sms:+15551234567"),
        .init(channel: .facetime,     input: "+15551234567",      expected: "facetime:15551234567"),
        .init(channel: .email,        input: "alex@example.com",  expected: "mailto:alex@example.com"),
        .init(channel: .whatsapp,     input: "+15551234567",      expected: "https://wa.me/15551234567"),
        .init(channel: .telegram,     input: "alexc",             expected: "https://t.me/alexc"),
        .init(channel: .signal,       input: "+15551234567",      expected: "https://signal.me/#p/+15551234567"),
        .init(channel: .messenger,    input: "alexc",             expected: "https://m.me/alexc"),
        .init(channel: .instagramDM,  input: "alexc",             expected: "https://ig.me/m/alexc"),
        .init(channel: .linkedinMsg,  input: "alex-chen",         expected: "https://linkedin.com/in/alex-chen"),
        .init(channel: .linkedinMsg,  input: "https://www.linkedin.com/in/alex-chen",
              expected: "https://www.linkedin.com/in/alex-chen"),
        .init(channel: .custom,       input: "https://slack.com/app_redirect?team=T1&channel=C1",
              expected: "https://slack.com/app_redirect?team=T1&channel=C1"),
        .init(channel: .inPerson,     input: "",                  expected: nil),
    ]

    @Test("Every catalog entry produces the expected URL", arguments: cases)
    func catalogRow(tc: DeepLinkCase) {
        let url = DeepLinkBuilder.build(channel: tc.channel, value: tc.input)
        #expect(url?.absoluteString == tc.expected,
                "\(tc.channel.rawValue) with \(tc.input) expected \(tc.expected ?? "nil") got \(url?.absoluteString ?? "nil")")
    }

    @Test("Invalid input returns nil for strictly-validated channels")
    func invalidInputRejected() {
        #expect(DeepLinkBuilder.build(channel: .whatsapp, value: "not-a-number") == nil)
        #expect(DeepLinkBuilder.build(channel: .email, value: "garbled@") == nil)
        #expect(DeepLinkBuilder.build(channel: .email, value: "no-at-sign") == nil)
        #expect(DeepLinkBuilder.build(channel: .custom, value: "not a url") == nil)
    }

    @Test("Discord with a snowflake ID produces a user-DM deep link")
    func discordWithId() {
        let url = DeepLinkBuilder.build(channel: .discord, value: "alexc#123456789012345678")
        #expect(url?.absoluteString == "discord://discord.com/users/123456789012345678")
    }

    @Test("Discord without an ID falls back to the generic scheme")
    func discordWithoutId() {
        let url = DeepLinkBuilder.build(channel: .discord, value: "alexc")
        #expect(url?.absoluteString == "discord://")
    }

    @Test("Phone-number normalization strips separators and parens")
    func phoneNormalization() {
        #expect(ChannelCatalog.normalizedPhone("+1 (415) 555-0134") == "+14155550134")
        #expect(ChannelCatalog.normalizedPhone("(415) 555.0134") == "4155550134")
        #expect(ChannelCatalog.normalizedPhone("+91 98765 43210") == "+919876543210")
    }

    @Test("Email validation rejects obvious bad shapes")
    func emailValidation() {
        #expect(ChannelCatalog.isEmail("a@b.co"))
        #expect(ChannelCatalog.isEmail("alex@example.com"))
        #expect(!ChannelCatalog.isEmail("no-at-sign"))
        #expect(!ChannelCatalog.isEmail("double@@sign.com"))
        #expect(!ChannelCatalog.isEmail("@leading.com"))
        #expect(!ChannelCatalog.isEmail("trailing@"))
        #expect(!ChannelCatalog.isEmail("no-domain-dot@foo"))
    }

    @Test("Every channel enum case is reachable from the catalog metadata")
    func everyChannelHasMetadata() {
        for channel in Channel.allCases {
            let meta = ChannelCatalog.metadata(for: channel)
            #expect(meta.channel == channel)
            #expect(!meta.helpText.isEmpty)
        }
    }
}
