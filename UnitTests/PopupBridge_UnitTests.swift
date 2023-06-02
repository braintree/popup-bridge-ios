import XCTest
import WebKit
import SafariServices
@testable import PopupBridge

// TODO: move into own file
class MockPopupBridgeDelegate: NSObject, POPPopupBridgeDelegate {

    var didRequestPresentationOfViewController: Bool = false
    var didRequestDismissalOfViewController: Bool = false

    func popupBridge(_ bridge: PopupBridge.POPPopupBridge, requestsPresentationOfViewController viewController: UIViewController) {
        didRequestPresentationOfViewController = true
    }

    func popupBridge(_ bridge: PopupBridge.POPPopupBridge, requestsDismissalOfViewController viewController: UIViewController) {
        didRequestDismissalOfViewController = true
    }

    func popupBridge(_ bridge: POPPopupBridge, receivedMessage messageName: String, data: String?) {
        // no-op
    }
}

final class PopupBridge_UnitTests: XCTestCase, WKNavigationDelegate {

    let scriptMessageHandlerName: String = "POPPopupBridge"
    let returnURL: String = "com.braintreepayments.popupbridgeexample"

    var webViewReadyBlock: (Void)?

    func testInit_addsUserScript() {
        let webView = WKWebView()
        let delegate = MockPopupBridgeDelegate()

        XCTAssertEqual(webView.configuration.userContentController.userScripts.count, 0)

        let _ = POPPopupBridge(webView: webView, urlScheme: returnURL, delegate: delegate)

        XCTAssertEqual(webView.configuration.userContentController.userScripts.count, 1)

        let userScript = webView.configuration.userContentController.userScripts[0]

        XCTAssertEqual(userScript.injectionTime, WKUserScriptInjectionTime.atDocumentStart)
        XCTAssertTrue(userScript.isForMainFrameOnly)
    }


    func testInit_addsScriptMessageHandler() {
        let configuration = WKWebViewConfiguration()
        let mockUserContentController = MockUserContentController()
        let delegate = MockPopupBridgeDelegate()

        configuration.userContentController = mockUserContentController

        let webView = WKWebView(frame: CGRect(), configuration: configuration)
        let pub = POPPopupBridge(webView: webView, urlScheme: returnURL, delegate: delegate)

        XCTAssertEqual(mockUserContentController.scriptMessageHandler as? POPPopupBridge, pub)
        XCTAssertEqual(mockUserContentController.name, scriptMessageHandlerName)
    }

    func testReceiveScriptMessage_whenMessageContainsURL_requestsPresentationOfSafariViewController() {
        let stubMessageBody: [String: String] = ["url": "http://example.com/?hello=world"]
        let stubMessageName = scriptMessageHandlerName
        let stubMessage = MockScriptMessage()
        stubMessage.body = stubMessageBody
        stubMessage.name = stubMessageName

        let configuration = WKWebViewConfiguration()
        let mockUserContentController = MockUserContentController()
        let delegate = MockPopupBridgeDelegate()

        configuration.userContentController = mockUserContentController

        let webView = WKWebView(frame: CGRect(), configuration: configuration)
        let pub = POPPopupBridge(webView: webView, urlScheme: returnURL, delegate: delegate)

        pub.userContentController(WKUserContentController(), didReceive: stubMessage)
        delegate.popupBridge(pub, requestsDismissalOfViewController: UIViewController())

        XCTAssertTrue(delegate.didRequestPresentationOfViewController)
    }

    func testReceiveScriptMessage_whenMessageContainsURL_informsDelegateThatURLWillBeLoaded() {
        let stubMessageBody: [String?: Any?] = [:]
        let stubMessageName = scriptMessageHandlerName
        let stubMessage = MockScriptMessage()
        stubMessage.body = stubMessageBody
        stubMessage.name = stubMessageName

        let configuration = WKWebViewConfiguration()
        let mockUserContentController = MockUserContentController()
        let delegate = MockPopupBridgeDelegate()

        configuration.userContentController = mockUserContentController

        let webView = WKWebView(frame: CGRect(), configuration: configuration)
        let pub = POPPopupBridge(webView: webView, urlScheme: returnURL, delegate: delegate)

        pub.userContentController(WKUserContentController(), didReceive: stubMessage)
    }

    func testReceiveScriptMessage_whenMessageNameIsNotScriptMessageHandlerName_doesNotRequestPresentationOfViewControllers() {
        let stubMessageBody: [String: String] = ["url": "http://example.com/?hello=world"]
        let stubMessageName = "foo"
        let stubMessage = MockScriptMessage()
        stubMessage.body = stubMessageBody
        stubMessage.name = stubMessageName

        let configuration = WKWebViewConfiguration()
        let mockUserContentController = MockUserContentController()
        let delegate = MockPopupBridgeDelegate()

        configuration.userContentController = mockUserContentController

        let webView = WKWebView(frame: CGRect(), configuration: configuration)
        let pub = POPPopupBridge(webView: webView, urlScheme: returnURL, delegate: delegate)

        pub.userContentController(WKUserContentController(), didReceive: stubMessage)
    }

    func testPopupBridge_whenDoneButtonTappedOnSafariViewController_callsOnCancelOrOnCompleteWithNoPayloadOrError() {
        let stubMessageBody: [String: String] = ["url": "http://example.com/?hello=world"]
        let stubMessageName = scriptMessageHandlerName
        let stubMessage = MockScriptMessage()
        stubMessage.body = stubMessageBody
        stubMessage.name = stubMessageName

        let configuration = WKWebViewConfiguration()
        let mockUserContentController = MockUserContentController()
        let delegate = MockPopupBridgeDelegate()

        configuration.userContentController = mockUserContentController

        let webView = WKWebView(frame: CGRect(), configuration: configuration)
        let pub = POPPopupBridge(webView: webView, urlScheme: returnURL, delegate: delegate)
        let stubSafari = SFSafariViewController(url: URL(string: "http://example.com")!)

        pub.userContentController(WKUserContentController(), didReceive: stubMessage)
        pub.safariViewControllerDidFinish(stubSafari)

        webView.evaluateJavaScript("""
        "if (typeof window.popupBridge.onCancel === 'function') {"
        "  window.popupBridge.onCancel();"
        "} else {"
        "  window.popupBridge.onComplete(null, null);"
        "}"
        """)
    }

    func testOpenURL_whenReturnURLHasQueryParams_passesPayloadWithQueryItemsToWebView() {
        let stubMessageBody: [String: String] = ["url": "http://example.com/?hello=world"]
        let stubMessageName = scriptMessageHandlerName
        let stubMessage = MockScriptMessage()
        stubMessage.body = stubMessageBody
        stubMessage.name = stubMessageName

        let configuration = WKWebViewConfiguration()
        let mockUserContentController = MockUserContentController()
        let delegate = MockPopupBridgeDelegate()

        configuration.userContentController = mockUserContentController

        let webView = WKWebView(frame: CGRect(), configuration: configuration)
        let pub = POPPopupBridge(webView: webView, urlScheme: returnURL, delegate: delegate)
        let mockURL = URL(string: "com.braintreepayments.popupbridgeexample://popupbridgev1/return?something=foo&other=bar")!
        let _ = POPPopupBridge.open(url: mockURL)
        let expectedResult = "window.popupBridge.onComplete(null, {\"path\":\"\\/return\",\"queryItems\":{\"other\":\"bar\",\"something\":\"foo\"}});"
        let result = pub.constructJavaScriptCompletionResult(returnURL: mockURL)

        XCTAssertEqual(result, expectedResult)
    }

    func testOpenURL_whenReturnURLHasNoQueryParams_passesPayloadWithNoQueryItemsToWebView() {
        let stubMessageBody: [String: String] = ["url": "http://example.com/?hello=world"]
        let stubMessageName = scriptMessageHandlerName
        let stubMessage = MockScriptMessage()
        stubMessage.body = stubMessageBody
        stubMessage.name = stubMessageName

        let configuration = WKWebViewConfiguration()
        let mockUserContentController = MockUserContentController()
        let delegate = MockPopupBridgeDelegate()

        configuration.userContentController = mockUserContentController

        let webView = WKWebView(frame: CGRect(), configuration: configuration)
        let pub = POPPopupBridge(webView: webView, urlScheme: returnURL, delegate: delegate)
        let mockURL = URL(string: "com.braintreepayments.popupbridgeexample://popupbridgev1/return")!
        let _ = POPPopupBridge.open(url: mockURL)
        let expectedResult = "window.popupBridge.onComplete(null, {\"path\":\"\\/return\",\"queryItems\":{}});"
        let result = pub.constructJavaScriptCompletionResult(returnURL: mockURL)

        XCTAssertEqual(result, expectedResult)
    }

    func testOpenURL_whenReturnURLHasURLFragment_passesPayloadWithHashToWebView() {
        let stubMessageBody: [String: String] = ["url": "http://example.com/?hello=world"]
        let stubMessageName = scriptMessageHandlerName
        let stubMessage = MockScriptMessage()
        stubMessage.body = stubMessageBody
        stubMessage.name = stubMessageName

        let delegate = MockPopupBridgeDelegate()
        let pub = POPPopupBridge(webView: WKWebView(), urlScheme: returnURL, delegate: delegate)

        pub.userContentController(WKUserContentController(), didReceive: stubMessage)

        let mockURL = URL(string: "com.braintreepayments.popupbridgeexample://popupbridgev1/return#something=foo&other=bar")!
        let _ = POPPopupBridge.open(url: mockURL)
        let expectedResult = "window.popupBridge.onComplete(null, {\"path\":\"\\/return\",\"hash\":\"something=foo&other=bar\",\"queryItems\":{}});"
        let result = pub.constructJavaScriptCompletionResult(returnURL: mockURL)

        XCTAssertEqual(result, expectedResult)
    }

    func testOpenURL_whenReturnURLHasNoURLFragment_passesPayloadWithNilHashToWebView() {
        let stubMessageBody: [String: String] = ["url": "http://example.com/?hello=world"]
        let stubMessageName = scriptMessageHandlerName
        let stubMessage = MockScriptMessage()
        stubMessage.body = stubMessageBody
        stubMessage.name = stubMessageName

        let delegate = MockPopupBridgeDelegate()
        let pub = POPPopupBridge(webView: WKWebView(), urlScheme: returnURL, delegate: delegate)

        pub.userContentController(WKUserContentController(), didReceive: stubMessage)

        let mockURL = URL(string: "com.braintreepayments.popupbridgeexample://popupbridgev1/return")!
        let _ = POPPopupBridge.open(url: mockURL)
        let expectedResult = "window.popupBridge.onComplete(null, {\"path\":\"\\/return\",\"queryItems\":{}});"
        let result = pub.constructJavaScriptCompletionResult(returnURL: mockURL)

        XCTAssertEqual(result, expectedResult)
    }

    func testOpenURL_whenReturnURLDoesNotMatchScheme_returnsFalseAndDoesNotCallOnComplete() {
        let stubMessageBody: [String: String] = ["url": "http://example.com/?hello=world"]
        let stubMessageName = scriptMessageHandlerName
        let stubMessage = MockScriptMessage()
        stubMessage.body = stubMessageBody
        stubMessage.name = stubMessageName

        let delegate = MockPopupBridgeDelegate()
        let pub = POPPopupBridge(webView: WKWebView(), urlScheme: returnURL, delegate: delegate)

        pub.userContentController(WKUserContentController(), didReceive: stubMessage)

        let result = POPPopupBridge.open(url: URL(string: "not.the.right.scheme://popupbridgev1/return?something=foo")!)
        XCTAssertFalse(result)
    }

    func testOpenURL_whenReturnURLDoesNotMatchHost_returnsFalseAndDoesNotCallOnComplete() {
        let stubMessageBody: [String: String] = ["url": "http://example.com/?hello=world"]
        let stubMessageName = scriptMessageHandlerName
        let stubMessage = MockScriptMessage()
        stubMessage.body = stubMessageBody
        stubMessage.name = stubMessageName

        let delegate = MockPopupBridgeDelegate()
        let pub = POPPopupBridge(webView: WKWebView(), urlScheme: returnURL, delegate: delegate)

        pub.userContentController(WKUserContentController(), didReceive: stubMessage)

        let result = POPPopupBridge.open(url: URL(string: "com.braintreepayments.popupbridgeexample://notcorrect/return?something=foo")!)
        XCTAssertFalse(result)
    }

    func testDelegate_whenWebViewCallsPopupBridgeSendMessage_receivesMessage() {
        let delegate = MockPopupBridgeDelegate()
        let webView = WKWebView()
        webView.navigationDelegate = self

        let pub = POPPopupBridge(webView: webView, urlScheme: returnURL, delegate: delegate)
        let expectation = expectation(description: "Called JS")

        webViewReadyBlock = {
            webView.evaluateJavaScript("window.popupBridge.sendMessage('myMessageName', JSON.stringify({foo: 'bar'}));") {_, _ in
                delegate.popupBridge(pub, receivedMessage: "myMessageName", data: "{\"foo\":\"bar\"}")
                expectation.fulfill()
            }
        }()

        webView.loadHTMLString("<html></html>", baseURL: nil)

        waitForExpectations(timeout: 10)
    }

    // Consider adding tests for query parameter parsing - multiple values, special characters, encoded, etc.

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if let webViewReadyBlock {
            webViewReadyBlock
        }
    }
}
