import XCTest
import WebKit
import OCMock
import SafariServices
@testable import PopupBridge

// TODO: move into own file
class MockPopupBridgeDelegate: NSObject, POPPopupBridgeDelegate {

    func popupBridge(_ bridge: PopupBridge.POPPopupBridge, requestsPresentationOfViewController viewController: UIViewController) {
        // TODO: do something
    }

    func popupBridge(_ bridge: PopupBridge.POPPopupBridge, requestsDismissalOfViewController viewController: UIViewController) {
        // TODO: do something
    }
}

final class PopupBridge_UnitTests: XCTestCase, WKNavigationDelegate {

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

        let pub = POPPopupBridge(webView: webView, urlScheme: returnURL, delegate: delegate)

        // TODO: sort this out - scriptMessage should be of type id<WKScriptMessageHandler>
//        XCTAssertEqual(mockUserContentController.scriptMessageHandler as! WKScriptMessageHandler, pub)
        XCTAssertEqual(mockUserContentController.name, scriptMessageHandlerName)
    }

    func testReceiveScriptMessage_whenMessageContainsURL_requestsPresentationOfSafariViewController() {
        
    }

    // Consider adding tests for query parameter parsing - multiple values, special characters, encoded, etc.

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if let webviewReadyBlock = PopupBridge_UnitTests.webviewReadyBlock {
            webviewReadyBlock
        }
    }
}
