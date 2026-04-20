import Foundation

/// Static metadata describing how each channel is validated and deep-linked
/// (ARCHITECTURE.md §8). The Android columns in the doc are informational
/// only in the iOS repo — the Kotlin port will mirror this file.
public enum ChannelValueKind: Sendable, Equatable {
    case phoneE164
    case phoneOrEmail
    case email
    case handle
    case vanityOrURL
    case usernameWithOptionalID
    case arbitraryURL
    case none
}

public struct ChannelMetadata: Sendable, Equatable {
    public let channel: Channel
    public let valueKind: ChannelValueKind
    public let helpText: String

    public init(channel: Channel, valueKind: ChannelValueKind, helpText: String) {
        self.channel = channel
        self.valueKind = valueKind
        self.helpText = helpText
    }
}

public enum ChannelCatalog {

    public static func metadata(for channel: Channel) -> ChannelMetadata {
        switch channel {
        case .phoneCall:
            return .init(channel: channel, valueKind: .phoneE164,
                         helpText: "Phone number in international format.")
        case .sms:
            return .init(channel: channel, valueKind: .phoneE164,
                         helpText: "Phone number — iMessage routes automatically if available.")
        case .facetime:
            return .init(channel: channel, valueKind: .phoneOrEmail,
                         helpText: "Phone number or Apple ID email.")
        case .email:
            return .init(channel: channel, valueKind: .email,
                         helpText: "Email address, RFC 5322 format.")
        case .whatsapp:
            return .init(channel: channel, valueKind: .phoneE164,
                         helpText: "Phone number registered with WhatsApp.")
        case .telegram:
            return .init(channel: channel, valueKind: .handle,
                         helpText: "Username without the @ (e.g. 'alexc').")
        case .signal:
            return .init(channel: channel, valueKind: .phoneE164,
                         helpText: "Phone number registered with Signal.")
        case .messenger:
            return .init(channel: channel, valueKind: .handle,
                         helpText: "Messenger handle or m.me suffix.")
        case .instagramDM:
            return .init(channel: channel, valueKind: .handle,
                         helpText: "Instagram username without the @.")
        case .linkedinMsg:
            return .init(channel: channel, valueKind: .vanityOrURL,
                         helpText: "Vanity handle (e.g. 'alex-chen') or full profile URL.")
        case .discord:
            return .init(channel: channel, valueKind: .usernameWithOptionalID,
                         helpText: "Discord username; optional user ID enables direct DM links.")
        case .inPerson:
            return .init(channel: channel, valueKind: .none,
                         helpText: "No deep link — the reminder fires as a nudge.")
        case .custom:
            return .init(channel: channel, valueKind: .arbitraryURL,
                         helpText: "Any URL — Slack, Teams, Matrix, etc.")
        }
    }

    // MARK: - Validation

    public static func validate(value: String, for channel: Channel) -> Bool {
        let stripped = value.trimmingCharacters(in: .whitespacesAndNewlines)
        switch metadata(for: channel).valueKind {
        case .phoneE164:
            return isPhoneE164(stripped)
        case .phoneOrEmail:
            return isPhoneE164(stripped) || isEmail(stripped)
        case .email:
            return isEmail(stripped)
        case .handle:
            return isHandle(stripped)
        case .vanityOrURL:
            return isHandle(stripped) || URL(string: stripped)?.scheme != nil
        case .usernameWithOptionalID:
            return !stripped.isEmpty
        case .arbitraryURL:
            guard let url = URL(string: stripped), let scheme = url.scheme else { return false }
            return scheme == "https" || scheme == "http"
        case .none:
            return true
        }
    }

    /// Accepts E.164 (`+15551234567`) or any well-formed phone with common
    /// separators — Regards normalizes before storing.
    public static func isPhoneE164(_ value: String) -> Bool {
        let normalized = normalizedPhone(value)
        guard normalized.hasPrefix("+") else { return false }
        let digits = normalized.dropFirst()
        return (7...15).contains(digits.count) && digits.allSatisfy(\.isNumber)
    }

    /// Strips separators and parens; preserves a leading `+`.
    public static func normalizedPhone(_ value: String) -> String {
        var out = ""
        out.reserveCapacity(value.count)
        for ch in value {
            if ch == "+" && out.isEmpty { out.append(ch) }
            else if ch.isNumber { out.append(ch) }
        }
        return out
    }

    /// Minimal RFC 5322-ish email check — good enough for user-input
    /// validation, not a full parser.
    public static func isEmail(_ value: String) -> Bool {
        guard let at = value.firstIndex(of: "@") else { return false }
        let local = value[..<at]
        let domain = value[value.index(after: at)...]
        guard !local.isEmpty, !domain.isEmpty else { return false }
        guard domain.contains(".") else { return false }
        guard at == value.lastIndex(of: "@") else { return false }
        let allowed = CharacterSet(charactersIn:
            "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._+-@")
        return value.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    public static func isHandle(_ value: String) -> Bool {
        guard !value.isEmpty, value.count <= 64 else { return false }
        let allowed = CharacterSet(charactersIn:
            "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._-")
        return value.unicodeScalars.allSatisfy { allowed.contains($0) }
    }
}
