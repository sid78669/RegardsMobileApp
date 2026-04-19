import XCTest

/// Phase 0 accessibility smoke audit. Launches the app and runs Apple's built-in
/// accessibility audit against whatever's on screen. If the audit surfaces any
/// findings — missing labels, contrast failures, too-small hit regions,
/// dynamic-type clipping, VoiceOver-focus traps — this test fails and the PR
/// cannot merge.
///
/// Per PR2/PR3 this file grows to a per-screen audit. For PR1 the root view
/// (just the wordmark + subtitle) is the only surface in the app.
final class LaunchAccessibilityTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchScreenPassesAccessibilityAudit() throws {
        let app = XCUIApplication()
        app.launch()

        // Wait for the wordmark so we aren't auditing a blank launch screen.
        XCTAssertTrue(app.staticTexts["regards"].waitForExistence(timeout: 5))

        // iOS 17+: audits contrast, dynamic-type, hit regions, element
        // detection, parent-child order, trait consistency, and text clipping.
        try app.performAccessibilityAudit()
    }
}
