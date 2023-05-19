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
}

// TODO: rename class
final class PopupBridgeSwift_UnitTests: XCTestCase, WKNavigationDelegate {

    let scriptMessageHandlerName: String = "POPPopupBridge"
    let returnURL: String = "com.braintreepayments.popupbridgeexample"

    static var webviewReadyBlock: (Void)?

    override class func tearDown() {
        webviewReadyBlock = nil
    }

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

        let _ = POPPopupBridge(webView: webView, urlScheme: returnURL, delegate: delegate)

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

    }


    // Consider adding tests for query parameter parsing - multiple values, special characters, encoded, etc.

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if let webviewReadyBlock = PopupBridgeSwift_UnitTests.webviewReadyBlock {
            webviewReadyBlock
        }
    }
}
