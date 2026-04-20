import Foundation

/// WCAG 2.1 contrast-ratio math (https://www.w3.org/TR/WCAG21/#dfn-contrast-ratio).
/// Pure Swift — no UIKit/SwiftUI dependency so the test harness can run it on
/// any target. Inputs are sRGB components in [0, 1].
public enum WCAGContrast {

    /// Relative luminance of an sRGB color (WCAG §1.4.3).
    public static func relativeLuminance(red: Double, green: Double, blue: Double) -> Double {
        func channel(_ c: Double) -> Double {
            if c <= 0.04045 { return c / 12.92 }
            return pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(red)
             + 0.7152 * channel(green)
             + 0.0722 * channel(blue)
    }

    /// Contrast ratio between two sRGB colors. Always ≥ 1.
    public static func ratio(
        foreground: (red: Double, green: Double, blue: Double),
        background: (red: Double, green: Double, blue: Double)
    ) -> Double {
        let l1 = relativeLuminance(red: foreground.red,
                                   green: foreground.green,
                                   blue: foreground.blue)
        let l2 = relativeLuminance(red: background.red,
                                   green: background.green,
                                   blue: background.blue)
        let lighter = max(l1, l2)
        let darker  = min(l1, l2)
        return (lighter + 0.05) / (darker + 0.05)
    }
}
