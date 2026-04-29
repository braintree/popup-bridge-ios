import AuthenticationServices
import XCTest
import WebKit
@testable import PopupBridge

final class PopupBridge_IntegrationTests: XCTestCase {

    override func setUp() {
        super.setUp()
        StubURLProtocol.reset()
        POPPopupBridge.analyticsService = AnalyticsService()
    }

    override func tearDown() {
        StubURLProtocol.reset()
        POPPopupBridge.analyticsService = AnalyticsService()
        super.tearDown()
    }

    // MARK: - init

    func test_init_withRealWKWebView_injectsUserScriptAtDocumentStart() {
        let webView = WKWebView()
        XCTAssertEqual(webView.configuration.userContentController.userScripts.count, 0)

        let _ = POPPopupBridge(webView: webView)

        XCTAssertEqual(webView.configuration.userContentController.userScripts.count, 1)
        XCTAssertEqual(webView.configuration.userContentController.userScripts[0].injectionTime, .atDocumentStart)
        XCTAssertFalse(webView.configuration.userContentController.userScripts[0].isForMainFrameOnly)
    }

    @MainActor
    func test_init_withRealAnalyticsService_sendsStartedEvent() async {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        POPPopupBridge.analyticsService = AnalyticsService(session: URLSession(configuration: config))

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            var resumed = false
            StubURLProtocol.onRequest = { request in
                guard let body = request.httpBody,
                      let decoded = try? JSONDecoder().decode(FPTIBatchData.self, from: body),
                      decoded.events.first?.fptiEvents.first?.eventName == PopupBridgeAnalytics.started,
                      !resumed else { return }
                resumed = true
                continuation.resume()
            }
            let _ = POPPopupBridge(webView: WKWebView())
        }
    }

    // MARK: - userContentController

    func test_userContentController_withNonJSONSerializableBody_returnsEarlyWithoutStartingSession() {
        let webView = WKWebView()
        let mockSession = MockWebAuthSession()
        let bridge = POPPopupBridge(webView: webView, webAuthenticationSession: mockSession)

        let message = MockScriptMessage()
        message.stubName = "POPPopupBridge"
        message.stubBody = ["this-is-an-array-not-a-dict"]

        bridge.userContentController(WKUserContentController(), didReceive: message)

        XCTAssertFalse(mockSession.startWasCalled, "ASWebAuthenticationSession should not start for a non-JSON-serializable message body")
    }

    func test_userContentController_withMessageMissingURL_doesNotStartSession() {
        let webView = WKWebView()
        let mockSession = MockWebAuthSession()
        let bridge = POPPopupBridge(webView: webView, webAuthenticationSession: mockSession)

        let message = MockScriptMessage()
        message.stubName = "POPPopupBridge"
        message.stubBody = ["key": "value"]

        bridge.userContentController(WKUserContentController(), didReceive: message)

        XCTAssertFalse(mockSession.startWasCalled, "ASWebAuthenticationSession should not start when the message body has no URL")
    }

    func test_userContentController_withValidURL_startsSession() {
        let webView = WKWebView()
        let mockSession = MockWebAuthSession()
        let bridge = POPPopupBridge(webView: webView, webAuthenticationSession: mockSession)

        let message = MockScriptMessage()
        message.stubName = "POPPopupBridge"
        message.stubBody = ["url": "https://example.com/auth"]

        bridge.userContentController(WKUserContentController(), didReceive: message)

        XCTAssertTrue(mockSession.startWasCalled, "ASWebAuthenticationSession should start for a message with a valid URL")
        XCTAssertEqual(mockSession.capturedURL, URL(string: "https://example.com/auth"))
    }

    // MARK: - constructJavaScriptCompletionResult

    func test_constructJavaScriptCompletionResult_validURL_returnsOnCompleteScript() {
        let bridge = POPPopupBridge(webView: WKWebView())
        let url = URL(string: "\(PopupBridgeConstants.callbackURLScheme)://popupbridgev1/return?color=red")!

        let result = bridge.constructJavaScriptCompletionResult(returnURL: url)

        XCTAssertNotNil(result)
        XCTAssertTrue(result!.hasPrefix("window.popupBridge.onComplete(null,"))
        XCTAssertTrue(result!.contains("\"path\":\"\\/return\""))
    }

    func test_constructJavaScriptCompletionResult_wrongScheme_returnsNil() {
        let bridge = POPPopupBridge(webView: WKWebView())
        let url = URL(string: "https://popupbridgev1/return?color=red")!

        XCTAssertNil(bridge.constructJavaScriptCompletionResult(returnURL: url))
    }

    func test_constructJavaScriptCompletionResult_wrongHost_returnsNil() {
        let bridge = POPPopupBridge(webView: WKWebView())
        let url = URL(string: "\(PopupBridgeConstants.callbackURLScheme)://differenthost/return?color=red")!

        XCTAssertNil(bridge.constructJavaScriptCompletionResult(returnURL: url))
    }

    func test_constructJavaScriptCompletionResult_withQueryParams_includesThemInPayload() {
        let bridge = POPPopupBridge(webView: WKWebView())
        let url = URL(string: "\(PopupBridgeConstants.callbackURLScheme)://popupbridgev1/return?token=abc&status=success")!

        let result = bridge.constructJavaScriptCompletionResult(returnURL: url)

        XCTAssertNotNil(result)
        XCTAssertTrue(result!.contains("token"))
        XCTAssertTrue(result!.contains("abc"))
    }

    func test_constructJavaScriptCompletionResult_withFragment_includesHashInPayload() {
        let bridge = POPPopupBridge(webView: WKWebView())
        let url = URL(string: "\(PopupBridgeConstants.callbackURLScheme)://popupbridgev1/return#section=top")!

        let result = bridge.constructJavaScriptCompletionResult(returnURL: url)

        XCTAssertNotNil(result)
        XCTAssertTrue(result!.contains("section=top"))
    }
}
