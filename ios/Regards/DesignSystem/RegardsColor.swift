import SwiftUI
import UIKit

/// SwiftUI entry points for the design-system palette. Each property returns a
/// dynamic `Color` that resolves to the light or dark variant based on the
/// current `UITraitCollection.userInterfaceStyle` — one definition, works in
/// light + dark without callers having to branch.
///
/// Values live in `RegardsPalette` (sRGB tuples) so the WCAG contrast tests in
/// `RegardsTests` can assert every pair without re-instantiating SwiftUI.
public enum RegardsDS {

    public static var background: Color { dynamic(RegardsPalette.backgroundLight, RegardsPalette.backgroundDark) }
    public static var surface:    Color { dynamic(RegardsPalette.surfaceLight,    RegardsPalette.surfaceDark) }
    public static var ink:        Color { dynamic(RegardsPalette.inkLight,        RegardsPalette.inkDark) }
    public static var muted:      Color { dynamic(RegardsPalette.mutedLight,      RegardsPalette.mutedDark) }
    public static var faint:      Color { dynamic(RegardsPalette.faintLight,      RegardsPalette.faintDark) }
    public static var hair:       Color { dynamic(RegardsPalette.hairLight,       RegardsPalette.hairDark) }
    public static var hairSoft:   Color { dynamic(RegardsPalette.hairSoftLight,   RegardsPalette.hairSoftDark) }
    public static var accent:     Color { dynamic(RegardsPalette.accentLight,     RegardsPalette.accentDark) }
    public static var accentSoft: Color { dynamic(RegardsPalette.accentSoftLight, RegardsPalette.accentSoftDark) }
    public static var accentInk:  Color { dynamic(RegardsPalette.accentInkLight,  RegardsPalette.accentInkDark) }
    public static var danger:     Color { dynamic(RegardsPalette.dangerLight,     RegardsPalette.dangerDark) }

    private static func dynamic(_ light: RegardsPalette.SRGB,
                                _ dark: RegardsPalette.SRGB) -> Color {
        Color(uiColor: UIColor { trait in
            let rgb = trait.userInterfaceStyle == .dark ? dark : light
            return UIColor(red:   CGFloat(rgb.red),
                           green: CGFloat(rgb.green),
                           blue:  CGFloat(rgb.blue),
                           alpha: 1.0)
        })
    }
}
