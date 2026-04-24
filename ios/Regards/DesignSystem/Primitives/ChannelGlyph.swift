import SwiftUI

/// Monochrome line icon for each channel. PR3 uses SF Symbols as stand-ins —
/// Apple provides a broad catalog of phone/message/video glyphs that read
/// cleanly at small sizes and support Dynamic Type automatically. Replacing
/// the custom-SVG per-brand glyphs from the JSX mocks is tracked for a later
/// visual pass (branded logos risk trademark issues anyway).
public struct ChannelGlyph: View {
    public let channel: Channel
    public let size: CGFloat
    public let color: Color

    public init(channel: Channel, size: CGFloat = 18, color: Color = RegardsDS.muted) {
        self.channel = channel
        self.size = size
        self.color = color
    }

    public var body: some View {
        Image(systemName: Self.symbol(for: channel))
            .font(.system(size: size * 0.95, weight: .regular))
            .foregroundStyle(color)
            .accessibilityHidden(true)
    }

    static func symbol(for channel: Channel) -> String {
        switch channel {
        case .phoneCall:   return "phone.fill"
        case .sms:         return "message.fill"
        case .facetime:    return "video.fill"
        case .email:       return "envelope.fill"
        case .whatsapp:    return "bubble.left.and.bubble.right.fill"
        case .telegram:    return "paperplane.fill"
        case .signal:      return "shield.lefthalf.filled"
        case .messenger:   return "ellipsis.message.fill"
        case .instagramDM: return "camera.fill"
        case .linkedinMsg: return "briefcase.fill"
        case .discord:     return "gamecontroller.fill"
        case .inPerson:    return "person.2.wave.2.fill"
        case .custom:      return "link"
        }
    }
}
