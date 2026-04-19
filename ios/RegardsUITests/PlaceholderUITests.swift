import XCTest

final class PlaceholderUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAppLaunches() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["regards"].waitForExistence(timeout: 5),
                      "The wordmark should render on the root view.")
    }
}
