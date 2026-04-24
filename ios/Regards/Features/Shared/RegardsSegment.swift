import Foundation

/// Shared state for the Overdue ↔ Upcoming segmented control. Lives here so
/// both feature modules can import it without cross-coupling their view
/// models (was previously reached in as `OverdueViewModel.Tab`).
public enum RegardsSegment: Hashable, Sendable {
    case overdue
    case upcoming
}
