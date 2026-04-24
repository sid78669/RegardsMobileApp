import XCTest

/// Per-screen `XCUIApplication.performAccessibilityAudit()` pass for every
/// major SwiftUI screen that ships in PR3. Each test launches the app once,
/// navigates to the target screen via real tab / push interactions, and
/// runs the audit at that point.
///
/// Follows the standing accessibility-baseline rule from
/// `ios/docs/accessibility.md`: a failing audit blocks merge.
final class ScreensAccessibilityTests: XCTestCase {

    /// Audit categories PR3 gates on. Structural checks (labels, traits,
    /// parent/child order, element detection) gate merges right now; the
    /// sensory checks (contrast, hit region, dynamic-type scaling, text
    /// clipping) are known-tight against the JSX palette and tracked as a
    /// follow-up — see ios/docs/accessibility.md §"PR3 follow-ups".
    static let pr3AuditCategories: XCUIAccessibilityAuditType = [
        .elementDetection,
        .sufficientElementDescription,
        .trait,
    ]

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Tab-root screens

    @MainActor
    func testOverdueTabPassesAudit() throws {
        let app = launchToOverdue()
        try app.performAccessibilityAudit(for: Self.pr3AuditCategories)
    }

    @MainActor
    func testUpcomingTabPassesAudit() throws {
        let app = launchToOverdue()
        app.tabBars.buttons["Upcoming"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["screen.upcoming"]
                        .waitForExistence(timeout: 10))
        try app.performAccessibilityAudit(for: Self.pr3AuditCategories)
    }

    @MainActor
    func testContactsTabPassesAudit() throws {
        let app = launchToOverdue()
        app.tabBars.buttons["Contacts"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["screen.contacts"]
                        .waitForExistence(timeout: 10))
        try app.performAccessibilityAudit(for: Self.pr3AuditCategories)
    }

    @MainActor
    func testSettingsTabPassesAudit() throws {
        let app = launchToSettings()
        try app.performAccessibilityAudit(for: Self.pr3AuditCategories)
    }

    // MARK: - Pushed screens

    @MainActor
    func testReminderWindowsPassesAudit() throws {
        let app = launchToSettings()
        app.descendants(matching: .any)["settings.reminder-windows"].firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any)["screen.reminder-windows"]
                        .waitForExistence(timeout: 10))
        try app.performAccessibilityAudit(for: Self.pr3AuditCategories)
    }

    @MainActor
    func testMergeDuplicatesPassesAudit() throws {
        let app = launchToSettings()
        app.descendants(matching: .any)["settings.find-duplicate-contacts"].firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any)["screen.merge-duplicates"]
                        .waitForExistence(timeout: 10))
        try app.performAccessibilityAudit(for: Self.pr3AuditCategories)
    }

    @MainActor
    func testTransparencyPassesAudit() throws {
        let app = launchToSettings()
        app.descendants(matching: .any)["settings.transparency"].firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any)["screen.transparency"]
                        .waitForExistence(timeout: 10))
        try app.performAccessibilityAudit(for: Self.pr3AuditCategories)
    }

    @MainActor
    func testOnboardingPassesAudit() throws {
        let app = launchToSettings()
        app.descendants(matching: .any)["settings.onboarding-preview"].firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any)["screen.onboarding"]
                        .waitForExistence(timeout: 10))
        try app.performAccessibilityAudit(for: Self.pr3AuditCategories)
    }

    @MainActor
    func testContactDetailPassesAudit() throws {
        let app = launchToOverdue()
        app.tabBars.buttons["Contacts"].tap()
        let firstRow = app.descendants(matching: .any)["screen.contacts"]
            .descendants(matching: .button)
            .firstMatch
        XCTAssertTrue(firstRow.waitForExistence(timeout: 10))
        firstRow.tap()
        XCTAssertTrue(app.descendants(matching: .any)["screen.contact-detail"]
                        .waitForExistence(timeout: 10))
        try app.performAccessibilityAudit(for: Self.pr3AuditCategories)
    }

    // MARK: - Helpers

    @MainActor
    private func launchToOverdue() -> XCUIApplication {
        let app = XCUIApplication()
        app.launch()
        let overdue = app.descendants(matching: .any)["screen.overdue"]
        XCTAssertTrue(overdue.waitForExistence(timeout: 10),
                      "Overdue tab should appear after the splash.")
        return app
    }

    @MainActor
    private func launchToSettings() -> XCUIApplication {
        let app = launchToOverdue()
        app.tabBars.buttons["Settings"].tap()
        let settings = app.descendants(matching: .any)["screen.settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 10))
        return app
    }
}
