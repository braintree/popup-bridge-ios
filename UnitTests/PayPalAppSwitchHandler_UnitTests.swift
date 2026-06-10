import XCTest
@testable import PopupBridge

final class PayPalAppSwitchHandler_UnitTests: XCTestCase {

    let mockAnalyticsService = MockAnalyticsService()
    let returnURLScheme = "my-app-scheme"

    private var completedScripts: [String] = []
    private var launchFailedURLs: [URL] = []

    private func makeHandler(
        application: URLOpener,
        returnURLScheme: String? = "my-app-scheme"
    ) -> PayPalAppSwitchHandler {
        PayPalAppSwitchHandler(
            application: application,
            returnURLScheme: returnURLScheme,
            sessionID: "fake-session-id",
            analyticsService: mockAnalyticsService,
            onComplete: { [weak self] script in self?.completedScripts.append(script) },
            onLaunchFailed: { [weak self] url in self?.launchFailedURLs.append(url) }
        )
    }

    // MARK: - Launch Tests

    func testLaunch_opensURL() {
        let mockURLOpener = MockURLOpener()
        mockURLOpener.openURLSuccess = true
        let handler = makeHandler(application: mockURLOpener)

        handler.launch(url: URL(string: "https://example.com/checkout")!)

        XCTAssertEqual(mockURLOpener.lastOpenedURL?.absoluteString, "https://example.com/checkout")
    }

    func testLaunch_whenSucceeds_sendsAppLaunchStartedThenSucceeded() {
        let mockURLOpener = MockURLOpener()
        mockURLOpener.openURLSuccess = true
        let handler = makeHandler(application: mockURLOpener)

        handler.launch(url: URL(string: "https://example.com/checkout")!)

        XCTAssertEqual(
            mockAnalyticsService.sentEventNames,
            [PopupBridgeAnalytics.appLaunchStarted, PopupBridgeAnalytics.appLaunchSucceeded]
        )
    }

    func testLaunch_whenFails_sendsAppLaunchFailedAndCallsOnLaunchFailed() {
        let mockURLOpener = MockURLOpener()
        mockURLOpener.openURLSuccess = false
        let handler = makeHandler(application: mockURLOpener)
        let url = URL(string: "https://example.com/checkout")!

        handler.launch(url: url)

        XCTAssertEqual(launchFailedURLs, [url])
        XCTAssertEqual(
            mockAnalyticsService.sentEventNames,
            [PopupBridgeAnalytics.appLaunchStarted, PopupBridgeAnalytics.appLaunchFailed]
        )
    }

    // MARK: - Return URL Validation Tests

    func testIsValidPayPalReturnURL_whenSchemeAndHostMatch_returnsTrue() {
        let handler = makeHandler(application: MockURLOpener())
        let components = URLComponents(string: "my-app-scheme://popupbridgev1/return?token=EC-123")!

        XCTAssertTrue(handler.isValidPayPalReturnURL(components))
    }

    func testIsValidPayPalReturnURL_whenHostDoesNotMatch_returnsFalse() {
        let handler = makeHandler(application: MockURLOpener())
        let components = URLComponents(string: "my-app-scheme://attacker-host/return?token=EC-123")!

        XCTAssertFalse(handler.isValidPayPalReturnURL(components))
    }

    func testIsValidPayPalReturnURL_whenSchemeDoesNotMatch_returnsFalse() {
        let handler = makeHandler(application: MockURLOpener())
        let components = URLComponents(string: "other-scheme://popupbridgev1/return?token=EC-123")!

        XCTAssertFalse(handler.isValidPayPalReturnURL(components))
    }

    func testIsValidPayPalReturnURL_whenSchemeAndHostMatchWithDifferentCasing_returnsTrue() {
        let handler = makeHandler(application: MockURLOpener())
        let components = URLComponents(string: "MY-APP-SCHEME://POPUPBRIDGEV1/return")!

        XCTAssertTrue(handler.isValidPayPalReturnURL(components))
    }

    // MARK: - Return Handling Tests

    func testHandlePayPalLaunchAppReturn_whenValidReturnURL_completesWithScriptAndSendsSucceeded() {
        let handler = makeHandler(application: MockURLOpener())

        handler.handlePayPalLaunchAppReturn(url: URL(string: "my-app-scheme://popupbridgev1/return?token=EC-123")!)

        XCTAssertEqual(mockAnalyticsService.lastEventName, PopupBridgeAnalytics.succeeded)
        XCTAssertEqual(completedScripts.count, 1)
        XCTAssertTrue(completedScripts.first?.contains("window.popupBridge.onComplete(null,") ?? false)
    }

    func testHandlePayPalLaunchAppReturn_whenInvalidReturnURL_doesNotCompleteOrSendSucceeded() {
        let handler = makeHandler(application: MockURLOpener())

        // Arbitrary URL posted to the return notification by other code — wrong host.
        handler.handlePayPalLaunchAppReturn(url: URL(string: "my-app-scheme://attacker-host/return?token=EC-123")!)

        XCTAssertTrue(completedScripts.isEmpty)
        XCTAssertEqual(mockAnalyticsService.eventCount, 0)
    }
}
