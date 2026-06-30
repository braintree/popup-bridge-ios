import XCTest
@testable import PopupBridge

final class PayPalAppSwitchHandler_UnitTests: XCTestCase {

    let mockAnalyticsService = MockAnalyticsService()
    let returnURLScheme = "my-app-scheme"

    private var completedScripts: [String] = []
    private var launchFailedURLs: [URL] = []

    override func tearDown() {
        // The switcher is a shared singleton; clear any pending registration left by a test.
        PopupBridgeAppContextSwitcher.shared.pendingHandler = nil
        super.tearDown()
    }

    private func makeHandler(
        application: URLOpener,
        returnURLScheme: String = "my-app-scheme"
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

        handler.launch(URL(string: "https://example.com/checkout")!)

        XCTAssertEqual(mockURLOpener.lastOpenedURL?.absoluteString, "https://example.com/checkout")
    }

    func testLaunch_whenSucceeds_sendsAppLaunchStartedThenSucceeded() {
        let mockURLOpener = MockURLOpener()
        mockURLOpener.openURLSuccess = true
        let handler = makeHandler(application: mockURLOpener)

        handler.launch(URL(string: "https://example.com/checkout")!)

        XCTAssertEqual(
            mockAnalyticsService.sentEventNames,
            [PopupBridgeAnalytics.appSwitchStarted, PopupBridgeAnalytics.appSwitchSucceeded]
        )
    }

    func testLaunch_whenSucceeds_registersAsPendingHandler() {
        let mockURLOpener = MockURLOpener()
        mockURLOpener.openURLSuccess = true
        let handler = makeHandler(application: mockURLOpener)

        handler.launch(URL(string: "https://example.com/checkout")!)

        XCTAssertTrue(PopupBridgeAppContextSwitcher.shared.pendingHandler === handler)
    }

    func testLaunch_whenFails_doesNotRegisterAsPendingHandler() {
        let mockURLOpener = MockURLOpener()
        mockURLOpener.openURLSuccess = false
        let handler = makeHandler(application: mockURLOpener)

        handler.launch(URL(string: "https://example.com/checkout")!)

        XCTAssertNil(PopupBridgeAppContextSwitcher.shared.pendingHandler)
    }

    func testLaunch_whenFails_sendsAppLaunchFailedAndCallsOnLaunchFailed() {
        let mockURLOpener = MockURLOpener()
        mockURLOpener.openURLSuccess = false
        let handler = makeHandler(application: mockURLOpener)
        let url = URL(string: "https://example.com/checkout")!

        handler.launch(url)

        XCTAssertEqual(launchFailedURLs, [url])
        XCTAssertEqual(
            mockAnalyticsService.sentEventNames,
            [PopupBridgeAnalytics.appSwitchStarted, PopupBridgeAnalytics.appSwitchFailed]
        )
    }

    // MARK: - Return URL Routing Tests

    func testCanHandleReturnURL_whenSchemeAndHostMatch_returnsTrue() {
        let handler = makeHandler(application: MockURLOpener())
        let url = URL(string: "my-app-scheme://popupbridgev1/return?token=EC-123")!

        XCTAssertTrue(handler.canHandleReturnURL(url))
    }

    func testCanHandleReturnURL_whenHostDoesNotMatch_returnsFalse() {
        let handler = makeHandler(application: MockURLOpener())
        let url = URL(string: "my-app-scheme://attacker-host/return?token=EC-123")!

        XCTAssertFalse(handler.canHandleReturnURL(url))
    }

    func testCanHandleReturnURL_whenSchemeDoesNotMatch_returnsFalse() {
        let handler = makeHandler(application: MockURLOpener())
        let url = URL(string: "other-scheme://popupbridgev1/return?token=EC-123")!

        XCTAssertFalse(handler.canHandleReturnURL(url))
    }

    func testCanHandleReturnURL_whenSchemeAndHostMatchWithDifferentCasing_returnsTrue() {
        let handler = makeHandler(application: MockURLOpener())
        let url = URL(string: "MY-APP-SCHEME://POPUPBRIDGEV1/return")!

        XCTAssertTrue(handler.canHandleReturnURL(url))
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
