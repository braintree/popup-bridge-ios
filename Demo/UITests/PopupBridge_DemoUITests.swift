import XCTest

final class PopupBridge_DemoUITests: XCTestCase {

    let app: XCUIApplication = XCUIApplication()

    override func setUpWithError() throws {
        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // UI tests must launch the application that they test.
        // Doing this in setup will make sure it happens for each test method.
        app.launch()
    }

    func testClickingColors_returnsColors() {
        let colors = ["Red", "Green", "Blue"]

        colors.forEach { color in
            runTest(for: color)
        }
    }

    func testClickingDoNotLikeColors_returnsDoNotLikeColors() {
        let query = app.descendants(matching: XCUIElement.ElementType.webView)
        let webView = query.element(boundBy: 0)
        let launchPopupButton = webView.buttons["Launch Popup"]

        waitForElement(launchPopupButton)
        launchPopupButton.tap()

        let text = app.staticTexts["What's your favorite color?"]
        waitForElement(text, timeout: 10)

        let doNotLikeLink = app.links["I don't like any of these colors"]
        waitForElement(text, timeout: 10)
        doNotLikeLink.tap()

        waitForElement(app.staticTexts["You did not like any of our colors"], timeout: 10)
    }

    func testClickingSafariCancel_returnsCancel() {
        let query = app.descendants(matching: XCUIElement.ElementType.webView)
        let webView = query.element(boundBy: 0)
        let launchPopupButton = webView.buttons["Launch Popup"]

        waitForElement(launchPopupButton)
        launchPopupButton.tap()

        let cancelButton = app.buttons["Cancel"]
        waitForElement(cancelButton)
        cancelButton.tap()

        waitForElement(app.staticTexts["You did not choose a color"], timeout: 10)
    }

    // MARK: - Helpers

    func waitForElement(_ element: XCUIElement, timeout: TimeInterval = 5) {
        expectation(for: NSPredicate(format: "exists ==1"), evaluatedWith: element)
        waitForExpectations(timeout: timeout)
    }

    func runTest(for color: String) {
        let query = app.descendants(matching: XCUIElement.ElementType.webView)
        let webView = query.element(boundBy: 0)
        let launchPopupButton = webView.buttons["Launch Popup"]

        waitForElement(launchPopupButton)
        launchPopupButton.tap()

        let text = app.staticTexts["What's your favorite color?"]
        waitForElement(text, timeout: 10)

        let colorLink = app.links[color]
        waitForElement(colorLink)

        colorLink.tap()

        waitForElement(app.staticTexts["PopupBridge Example"])
        waitForElement(app.staticTexts["Your favorite color:"])
        waitForElement(app.staticTexts[color.lowercased()])
    }
}
