import Foundation

/// sRGB components (0-1) for every color the design system exposes. The asset
/// catalog (Assets.xcassets) holds the rendered values; this struct is the
/// Swift-level source of truth for the **contrast tests** that run in CI —
/// they compute WCAG ratios from these tuples without having to crack open
/// the xcassets JSON.
///
/// Keep this file in sync with `ios/Regards/Resources/Assets.xcassets/*` —
/// PR2's `ColorContrastTests` asserts the pairs listed in
/// `ios/docs/accessibility.md`.
public enum RegardsPalette {

    public struct SRGB: Sendable, Equatable {
        public let red: Double
        public let green: Double
        public let blue: Double

        public init(_ red: Double, _ green: Double, _ blue: Double) {
            self.red = red; self.green = green; self.blue = blue
        }

        public var tuple: (red: Double, green: Double, blue: Double) {
            (red, green, blue)
        }
    }

    // MARK: - Light mode

    public static let backgroundLight = SRGB(0.984, 0.973, 0.945)   // warm off-white
    public static let surfaceLight    = SRGB(1.000, 1.000, 1.000)
    public static let inkLight        = SRGB(0.165, 0.149, 0.133)   // near-black warm
    public static let mutedLight      = SRGB(0.420, 0.390, 0.360)   // darkened post-PR1-audit
    public static let accentLight     = SRGB(0.784, 0.419, 0.247)   // terracotta

    // MARK: - Dark mode

    public static let backgroundDark  = SRGB(0.082, 0.075, 0.059)
    public static let surfaceDark     = SRGB(0.125, 0.114, 0.094)
    public static let inkDark         = SRGB(0.957, 0.945, 0.918)
    public static let mutedDark       = SRGB(0.576, 0.565, 0.545)
    public static let accentDark      = SRGB(0.843, 0.490, 0.318)

    // MARK: - Commonly-paired combinations

    /// Contrast-pair registry — every fg/bg combo actually rendered in the
    /// app, with its required WCAG minimum. `ColorContrastTests` asserts each
    /// meets or exceeds its minimum.
    public struct Pair: Sendable, CustomStringConvertible {
        public let name: String
        public let foreground: SRGB
        public let background: SRGB
        public let minimumRatio: Double    // WCAG AA: 4.5 body, 3.0 large/icon

        public var description: String { name }
    }

    public static let contrastPairs: [Pair] = [
        .init(name: "Ink on Background (light)",
              foreground: inkLight, background: backgroundLight, minimumRatio: 4.5),
        .init(name: "Ink on Background (dark)",
              foreground: inkDark,  background: backgroundDark,  minimumRatio: 4.5),
        .init(name: "Muted on Background (light)",
              foreground: mutedLight, background: backgroundLight, minimumRatio: 4.5),
        .init(name: "Muted on Background (dark)",
              foreground: mutedDark, background: backgroundDark,   minimumRatio: 4.5),
        .init(name: "White on Accent (light)",
              foreground: SRGB(1, 1, 1), background: accentLight,  minimumRatio: 3.0),
        .init(name: "White on Accent (dark)",
              foreground: SRGB(1, 1, 1), background: accentDark,   minimumRatio: 3.0),
    ]
}
