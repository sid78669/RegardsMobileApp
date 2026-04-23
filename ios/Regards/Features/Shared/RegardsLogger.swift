import Foundation
import os

/// Central `os.Logger` factory. Views and view models pull subsystem-scoped
/// loggers from here so repository errors and unexpected states surface in
/// Console.app / the Xcode debug console instead of being swallowed silently.
///
/// Usage:
/// ```
/// static let log = RegardsLogger.feature("Overdue")
/// log.error("failed to load contacts: \(error, privacy: .public)")
/// ```
public enum RegardsLogger {

    /// Subsystem matches the primary app bundle identifier so filtering in
    /// Console.app is straightforward (`subsystem:com.sdahiya.regards`).
    public static let subsystem = "com.sdahiya.regards"

    public static func feature(_ name: String) -> Logger {
        Logger(subsystem: subsystem, category: name)
    }
}
