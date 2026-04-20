import Foundation

/// Communication channels the V1 catalog supports (ARCHITECTURE.md §8).
///
/// Adding a channel requires an app update because iOS `canOpenURL` needs the
/// scheme declared in `LSApplicationQueriesSchemes` (populated in Phase 1 —
/// this enum is the source of truth for that list).
public enum Channel: String, CaseIterable, Codable, Sendable, Hashable {
    case phoneCall    = "phone_call"
    case sms          = "sms"
    case facetime     = "facetime"
    case email        = "email"
    case whatsapp     = "whatsapp"
    case telegram     = "telegram"
    case signal       = "signal"
    case messenger    = "messenger"
    case instagramDM  = "instagram_dm"
    case linkedinMsg  = "linkedin_msg"
    case discord      = "discord"
    case inPerson     = "in_person"
    case custom       = "custom"

    /// Human-readable name used in rows, detail screens, and deep-link CTAs.
    public var displayName: String {
        switch self {
        case .phoneCall:   return "Call"
        case .sms:         return "Text"
        case .facetime:    return "FaceTime"
        case .email:       return "Email"
        case .whatsapp:    return "WhatsApp"
        case .telegram:    return "Telegram"
        case .signal:      return "Signal"
        case .messenger:   return "Messenger"
        case .instagramDM: return "Instagram"
        case .linkedinMsg: return "LinkedIn"
        case .discord:     return "Discord"
        case .inPerson:    return "In person"
        case .custom:      return "Custom"
        }
    }

    /// Whether this channel is available on iOS. (`facetime` is iOS-only; the
    /// Kotlin port hides it on Android — see §8.)
    public var isAvailableOnIOS: Bool { true }
}
