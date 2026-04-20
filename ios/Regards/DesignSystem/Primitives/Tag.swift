import SwiftUI

/// Pill-sized labeled tag. Ports the JSX `<Tag tone="...">` to SwiftUI.
public struct RegardsTag: View {
    public enum Tone: Sendable {
        case neutral
        case accent
        case overdue
        case soon
        case ok
    }

    public let text: String
    public let tone: Tone

    public init(_ text: String, tone: Tone = .neutral) {
        self.text = text
        self.tone = tone
    }

    public var body: some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .kerning(0.1)
            .foregroundStyle(foreground)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(background, in: Capsule(style: .continuous))
            .accessibilityLabel(text)
    }

    private var foreground: Color {
        switch tone {
        case .neutral: return RegardsDS.ink
        case .accent:  return RegardsDS.accentInk
        case .overdue: return RegardsDS.danger
        case .soon:    return RegardsDS.muted
        case .ok:      return .green
        }
    }

    private var background: Color {
        switch tone {
        case .neutral: return RegardsDS.hairSoft
        case .accent:  return RegardsDS.accentSoft
        case .overdue: return RegardsDS.accentSoft.opacity(0.6)
        case .soon:    return RegardsDS.hairSoft
        case .ok:      return Color.green.opacity(0.12)
        }
    }
}
