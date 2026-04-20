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

        // RootView collapses its children into a single accessibility element
        // tagged "launch.root"; the brand image is decorative (hidden from
        // VoiceOver) and the spoken label describes the full scene in one go.
        let root = app.descendants(matching: .any)["launch.root"]
        XCTAssertTrue(root.waitForExistence(timeout: 5),
                      "RootView's combined accessibility element should be present.")

        // iOS 17+: audits contrast, dynamic-type, hit regions, element
        // detection, parent-child order, trait consistency, and text clipping.
        try app.performAccessibilityAudit()
    }
}
