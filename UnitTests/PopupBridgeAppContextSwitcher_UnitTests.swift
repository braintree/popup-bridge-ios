import XCTest
@testable import PopupBridge

final class PopupBridgeAppContextSwitcher_UnitTests: XCTestCase {

    let mockAnalyticsService = MockAnalyticsService()

    private var completedScripts: [String] = []

    override func tearDown() {
        PopupBridgeAppContextSwitcher.shared.pendingHandler = nil
        super.tearDown()
    }

    private func makeHandler(returnURLScheme: String = "my-app-scheme") -> PayPalAppSwitchHandler {
        PayPalAppSwitchHandler(
            application: MockURLOpener(),
            returnURLScheme: returnURLScheme,
            sessionID: "fake-session-id",
            analyticsService: mockAnalyticsService,
            onComplete: { [weak self] script in self?.completedScripts.append(script) },
            onLaunchFailed: { _ in }
        )
    }

    func testHandleReturnURL_whenNoPendingHandler_returnsFalse() {
        let handled = PopupBridgeAppContextSwitcher.shared.handleReturnURL(
            URL(string: "my-app-scheme://popupbridgev1/return?token=EC-123")!
        )

        XCTAssertFalse(handled)
        XCTAssertTrue(completedScripts.isEmpty)
    }

    func testHandleReturnURL_whenPendingHandlerAndValidURL_handlesCompletesAndClearsPending() {
        let handler = makeHandler()
        PopupBridgeAppContextSwitcher.shared.register(handler)

        let handled = PopupBridgeAppContextSwitcher.shared.handleReturnURL(
            URL(string: "my-app-scheme://popupbridgev1/return?token=EC-123")!
        )

        XCTAssertTrue(handled)
        XCTAssertEqual(completedScripts.count, 1)
        XCTAssertTrue(completedScripts.first?.contains("window.popupBridge.onComplete(null,") ?? false)
        XCTAssertNil(PopupBridgeAppContextSwitcher.shared.pendingHandler)
    }

    func testHandleReturnURL_whenPendingHandlerButNonMatchingURL_returnsFalseAndKeepsPending() {
        let handler = makeHandler()
        PopupBridgeAppContextSwitcher.shared.register(handler)

        let handled = PopupBridgeAppContextSwitcher.shared.handleReturnURL(
            URL(string: "my-app-scheme://attacker-host/return?token=EC-123")!
        )

        XCTAssertFalse(handled)
        XCTAssertTrue(completedScripts.isEmpty)
        // A non-matching URL must not consume the one-shot registration, so a later legitimate
        // return still completes the flow.
        XCTAssertTrue(PopupBridgeAppContextSwitcher.shared.pendingHandler === handler)
    }
}
