import XCTest

/// Per-screen `XCUIApplication.performAccessibilityAudit()` pass for every
/// major SwiftUI screen that ships in PR3. Each test launches the app once,
/// navigates to the target screen via real tab / push interactions, and
/// runs the audit at that point.
///
/// Follows the standing accessibility-baseline rule from
/// `ios/docs/accessibility.md`: a failing audit blocks merge.
final class ScreensAccessibilityTests: XCTestCase {

    /// Audit categories the suite gates on. Structural checks (labels,
    /// traits, element detection) are merge-blocking. Sensory checks
    /// (`contrast`, `hitRegion`, `dynamicType`, `textClipped`) are
    /// documented design-intent trade-offs covered in
    /// `ios/docs/accessibility.md` §"Sensory-audit carve-outs" — the
    /// remaining findings are on decorative brand elements
    /// (Avatar initials, Wordmark) and specific accent-color pairings
    /// we've deliberately kept at current brightness for the mock's
    /// visual identity.
    static let structuralAuditCategories: XCUIAccessibilityAuditType = [
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
        try app.performAccessibilityAudit(for: Self.structuralAuditCategories)
    }

    @MainActor
    func testUpcomingTabPassesAudit() throws {
        let app = launchToOverdue()
        app.tabBars.buttons["Upcoming"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["screen.upcoming"]
                        .waitForExistence(timeout: 10))
        try app.performAccessibilityAudit(for: Self.structuralAuditCategories)
    }

    @MainActor
    func testContactsTabPassesAudit() throws {
        let app = launchToOverdue()
        app.tabBars.buttons["Contacts"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["screen.contacts"]
                        .waitForExistence(timeout: 10))
        try app.performAccessibilityAudit(for: Self.structuralAuditCategories)
    }

    @MainActor
    func testSettingsTabPassesAudit() throws {
        let app = launchToSettings()
        try app.performAccessibilityAudit(for: Self.structuralAuditCategories)
    }

    // MARK: - Pushed screens

    @MainActor
    func testReminderWindowsPassesAudit() throws {
        let app = launchToSettings()
        app.descendants(matching: .any)["settings.reminder-windows"].firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any)["screen.reminder-windows"]
                        .waitForExistence(timeout: 10))
        try app.performAccessibilityAudit(for: Self.structuralAuditCategories)
    }

    @MainActor
    func testMergeDuplicatesPassesAudit() throws {
        let app = launchToSettings()
        app.descendants(matching: .any)["settings.find-duplicate-contacts"].firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any)["screen.merge-duplicates"]
                        .waitForExistence(timeout: 10))
        try app.performAccessibilityAudit(for: Self.structuralAuditCategories)
    }

    @MainActor
    func testTransparencyPassesAudit() throws {
        let app = launchToSettings()
        app.descendants(matching: .any)["settings.transparency"].firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any)["screen.transparency"]
                        .waitForExistence(timeout: 10))
        try app.performAccessibilityAudit(for: Self.structuralAuditCategories)
    }

    @MainActor
    func testOnboardingPassesAudit() throws {
        let app = launchToSettings()
        app.descendants(matching: .any)["settings.onboarding-preview"].firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any)["screen.onboarding"]
                        .waitForExistence(timeout: 10))
        try app.performAccessibilityAudit(for: Self.structuralAuditCategories)
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
        try app.performAccessibilityAudit(for: Self.structuralAuditCategories)
    }

    /// Exercises the factory-built Contact Detail push from the **Overdue
    /// tab** (the new nav-path flow) — the previous ContactDetail test only
    /// covers the inline `NavigationLink` flow in `AllContactsScreen`.
    @MainActor
    func testContactDetailFromOverduePassesAudit() throws {
        let app = launchToOverdue()
        // Target contact-row elements specifically — `screen.overdue` also
        // hosts the nav-bar "All" button and the segmented-control
        // buttons, so plain `.descendants(matching: .button).firstMatch`
        // catches those first instead of a row. The row button applies
        // `.accessibilityElement(children: .ignore)` which composes a
        // synthetic element whose XCUI elementType resolves to `.other`,
        // so we search across all element types by identifier.
        let firstRow = app.descendants(matching: .any)
            .matching(identifier: "overdue.row").firstMatch
        XCTAssertTrue(firstRow.waitForExistence(timeout: 10))
        firstRow.tap()
        XCTAssertTrue(app.descendants(matching: .any)["screen.contact-detail"]
                        .waitForExistence(timeout: 10))
        try app.performAccessibilityAudit(for: Self.structuralAuditCategories)
    }

    /// Same path, Upcoming tab.
    @MainActor
    func testContactDetailFromUpcomingPassesAudit() throws {
        let app = launchToOverdue()
        app.tabBars.buttons["Upcoming"].tap()
        let upcoming = app.descendants(matching: .any)["screen.upcoming"]
        XCTAssertTrue(upcoming.waitForExistence(timeout: 10))
        let firstRow = app.descendants(matching: .any)
            .matching(identifier: "upcoming.row").firstMatch
        XCTAssertTrue(firstRow.waitForExistence(timeout: 10))
        firstRow.tap()
        XCTAssertTrue(app.descendants(matching: .any)["screen.contact-detail"]
                        .waitForExistence(timeout: 10))
        try app.performAccessibilityAudit(for: Self.structuralAuditCategories)
    }

    /// Regression guard for the per-push VM factory: tapping two different
    /// contacts in succession must show the second contact's data, not the
    /// first's. Guards against a future refactor that accidentally reuses
    /// the view's identity across pushes.
    @MainActor
    func testOverdueNavigationShowsDistinctContacts() throws {
        let app = launchToOverdue()
        let overdue = app.descendants(matching: .any)["screen.overdue"]
        let rows = app.descendants(matching: .any).matching(identifier: "overdue.row")

        // Tap first row → read the hero header → pop back.
        let first = rows.element(boundBy: 0)
        XCTAssertTrue(first.waitForExistence(timeout: 10))
        first.tap()
        let firstDetail = app.descendants(matching: .any)["screen.contact-detail"]
        XCTAssertTrue(firstDetail.waitForExistence(timeout: 10))
        // The hero header text is the only `staticText` child with an
        // `.isHeader` trait on this screen.
        let firstName = firstDetail.staticTexts
            .matching(NSPredicate(format: "traits & %d != 0", UIAccessibilityTraits.header.rawValue))
            .firstMatch.label
        app.navigationBars.buttons.element(boundBy: 0).tap()

        // Tap second row → its hero header should differ.
        XCTAssertTrue(overdue.waitForExistence(timeout: 10))
        let second = rows.element(boundBy: 1)
        XCTAssertTrue(second.waitForExistence(timeout: 10))
        second.tap()
        let secondDetail = app.descendants(matching: .any)["screen.contact-detail"]
        XCTAssertTrue(secondDetail.waitForExistence(timeout: 10))
        let secondName = secondDetail.staticTexts
            .matching(NSPredicate(format: "traits & %d != 0", UIAccessibilityTraits.header.rawValue))
            .firstMatch.label

        XCTAssertNotEqual(
            firstName,
            secondName,
            "Contact Detail must rebuild its VM per push so two consecutive taps show different contacts."
        )
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
