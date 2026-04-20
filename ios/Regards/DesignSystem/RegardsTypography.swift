import SwiftUI

/// Named typography used across the UI. Centralizing these keeps Dynamic Type
/// scaling consistent (every call site goes through a text style so the
/// accessibility audit doesn't flag font-size regressions).
public enum RegardsFont {

    /// Large display titles — e.g. the 34pt nav-bar title on Overdue /
    /// Upcoming. Uses `.largeTitle` so Dynamic Type scales through accessibility5.
    public static func largeTitle() -> Font { .system(.largeTitle, weight: .bold) }

    /// Section header caps — "INNER CIRCLE · OVERDUE" style.
    public static func sectionHeader() -> Font { .footnote.weight(.medium) }

    /// Primary row title — contact name.
    public static func rowTitle() -> Font { .body.weight(.semibold) }

    /// Secondary row text — cadence descriptor, relative time.
    public static func rowSubtitle() -> Font { .subheadline }

    /// Pill / chip copy inside accent-colored CTAs.
    public static func pill() -> Font { .subheadline.weight(.semibold) }

    /// Monospace for timestamps, phone numbers, proofs (§11 transparency).
    public static func mono(_ size: Font.TextStyle = .footnote) -> Font {
        .system(size, design: .monospaced)
    }

    /// Warm serif-italic for the "regards" wordmark and a few literary
    /// moments (window settings subtitle, transparency hero claim).
    public static func serifItalic(_ size: Font.TextStyle = .title2) -> Font {
        .system(size, design: .serif).italic()
    }
}
