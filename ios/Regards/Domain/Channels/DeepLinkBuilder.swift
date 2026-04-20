import Foundation

/// Builds the `URL` that gets handed to the platform-open adapter
/// (ARCHITECTURE.md §8). Universal HTTPS links are preferred where available
/// (`wa.me`, `t.me`, `ig.me`, `m.me`) because they fall back to Safari when
/// the target app isn't installed and don't require an Info.plist declaration.
public enum DeepLinkBuilder {

    public static func build(channel: Channel, value: String) -> URL? {
        guard ChannelCatalog.validate(value: value, for: channel) else { return nil }

        let phone = ChannelCatalog.normalizedPhone(value)
        let phoneDigitsOnly = String(phone.drop(while: { $0 == "+" }))

        switch channel {
        case .phoneCall:
            return URL(string: "tel:\(phone)")
        case .sms:
            return URL(string: "sms:\(phone)")
        case .facetime:
            return URL(string: "facetime:\(phoneDigitsOnly)")
        case .email:
            return URL(string: "mailto:\(value.trimmingCharacters(in: .whitespacesAndNewlines))")
        case .whatsapp:
            return URL(string: "https://wa.me/\(phoneDigitsOnly)")
        case .telegram:
            return URL(string: "https://t.me/\(value.trimmingCharacters(in: .whitespacesAndNewlines))")
        case .signal:
            // Signal uses the full E.164 with '+' in the path.
            return URL(string: "https://signal.me/#p/\(phone)")
        case .messenger:
            return URL(string: "https://m.me/\(value.trimmingCharacters(in: .whitespacesAndNewlines))")
        case .instagramDM:
            return URL(string: "https://ig.me/m/\(value.trimmingCharacters(in: .whitespacesAndNewlines))")
        case .linkedinMsg:
            let stripped = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if let url = URL(string: stripped), url.scheme != nil { return url }
            return URL(string: "https://linkedin.com/in/\(stripped)")
        case .discord:
            let stripped = value.trimmingCharacters(in: .whitespacesAndNewlines)
            // If the value contains a numeric Discord ID, use the DM deep link.
            if let id = discordUserId(from: stripped) {
                return URL(string: "discord://discord.com/users/\(id)")
            }
            return URL(string: "discord://")
        case .inPerson:
            return nil
        case .custom:
            let stripped = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let url = URL(string: stripped), url.scheme != nil else { return nil }
            return url
        }
    }

    /// Discord user IDs are 17-20 digit snowflakes. Users typically write
    /// `alexch#1234` or `alexch|123456789012345678` — we accept either form
    /// and extract the ID if present.
    static func discordUserId(from value: String) -> String? {
        // First try a trailing 17-20 digit run preceded by a separator.
        let digits = value.split(whereSeparator: { !$0.isNumber })
        if let last = digits.last, (17...20).contains(last.count) {
            return String(last)
        }
        return nil
    }
}
