import Foundation

/// Priority tiers a user can assign a contact. Rendered as sections on the
/// Overdue / All Contacts views (ARCHITECTURE.md §10 screen 1, §10 screen 3).
///
/// Lower raw value = higher priority.
public enum PriorityTier: Int, CaseIterable, Codable, Sendable {
    case innerCircle = 0
    case close = 1
    case regular = 2
    case acquaintance = 3
}
