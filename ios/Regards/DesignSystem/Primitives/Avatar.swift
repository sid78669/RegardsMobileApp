import SwiftUI

/// Initials placeholder avatar. Mirrors the JSX `<Avatar>`:
///   - Two-letter initials from name words.
///   - Deterministic tone picked from a 5-palette by summed-char-code hash.
///   - Optional accent ring for inner-circle contacts.
///
/// The mock explicitly says "initials placeholders until real photos load"
/// (regards-ui.jsx top comment) — real `CNContact` photo loading is a Phase 1
/// responsibility.
public struct Avatar: View {
    public let name: String
    public let size: CGFloat
    public let hasAccentRing: Bool

    public init(name: String, size: CGFloat = 44, hasAccentRing: Bool = false) {
        self.name = name
        self.size = size
        self.hasAccentRing = hasAccentRing
    }

    public var body: some View {
        ZStack {
            Circle()
                .fill(tone.background)
                .frame(width: size, height: size)
            Text(initials)
                .font(.system(size: size * 0.38, weight: .medium))
                .foregroundStyle(tone.foreground)
                .kerning(0.2)
        }
        .overlay {
            if hasAccentRing {
                Circle()
                    .stroke(RegardsDS.accent, lineWidth: 1.5)
                    .frame(width: size + 6, height: size + 6)
            }
        }
        .frame(width: size + (hasAccentRing ? 6 : 0),
               height: size + (hasAccentRing ? 6 : 0))
        .accessibilityHidden(true)
    }

    // MARK: - Private

    private var initials: String {
        let letters = name
            .split(whereSeparator: { $0.isWhitespace })
            .prefix(2)
            .compactMap { $0.first.map(String.init) }
            .joined()
            .uppercased()
        return letters.isEmpty ? "·" : letters
    }

    private var tone: AvatarTone {
        let hash = name.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return AvatarTone.palette[hash % AvatarTone.palette.count]
    }
}

/// Fixed 5-tone palette. Values approximate the JSX OKLCH palette in sRGB.
struct AvatarTone: Sendable {
    let background: Color
    let foreground: Color

    static let palette: [AvatarTone] = [
        AvatarTone(background: Color(red: 0.89, green: 0.87, blue: 0.81),
                   foreground: Color(red: 0.38, green: 0.34, blue: 0.27)),
        AvatarTone(background: Color(red: 0.85, green: 0.91, blue: 0.84),
                   foreground: Color(red: 0.22, green: 0.38, blue: 0.27)),
        AvatarTone(background: Color(red: 0.83, green: 0.89, blue: 0.94),
                   foreground: Color(red: 0.22, green: 0.32, blue: 0.47)),
        AvatarTone(background: Color(red: 0.92, green: 0.86, blue: 0.84),
                   foreground: Color(red: 0.44, green: 0.25, blue: 0.22)),
        AvatarTone(background: Color(red: 0.90, green: 0.85, blue: 0.92),
                   foreground: Color(red: 0.37, green: 0.22, blue: 0.42)),
    ]
}
