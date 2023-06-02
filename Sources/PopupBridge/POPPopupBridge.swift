import Foundation
import WebKit
import AuthenticationServices

@objcMembers
public class POPPopupBridge: NSObject, WKScriptMessageHandler {
    
    // MARK: - Private Properties
    
    private let messageHandlerName = "POPPopupBridge"
    private let hostName = "popupbridgev1"

    // TODO: extract into constants file
    let callbackURLScheme: String = "sdk.ios.popup-bridge"
    
    private let webView: WKWebView
    private let delegate: POPPopupBridgeDelegate
    private var webAuthenticationSession: WebAuthenticationSession
    
    private var returnBlock: ((URL) -> Bool)? = nil
    
    // MARK: - Initializers
        
    /// Initialize a Popup Bridge.
    /// - Parameters:
    ///   - webView: The web view to add a script message handler to. Do not change the web view's configuration or user content controller after initializing Popup Bridge.
    ///   - delegate: A delegate that presents and dismisses the pop-up (a SFSafariViewController).
    public init(
        webView: WKWebView,
        delegate: POPPopupBridgeDelegate
    ) {
        self.webView = webView
        self.delegate = delegate
        self.webAuthenticationSession = WebAuthenticationSession()
        
        super.init()

        configureWebView(scheme: callbackURLScheme)
                
        returnBlock = { (url: URL) -> Bool in
            guard let script = self.constructJavaScriptCompletionResult(returnURL: url) else {
                return false
            }

            self.injectWebView(webView: webView, withJavaScript: script)
            return true
        }
    }

    /// :nodoc: This method is not covered by Semantic Versioning. Do not use.
    /// Exposed for testing in Objective-C
    init(
        webView: WKWebView,
        delegate: POPPopupBridgeDelegate,
        webAuthenticationSession: WebAuthenticationSession
    ) {
        self.webView = webView
        self.delegate = delegate
        self.webAuthenticationSession = webAuthenticationSession

        super.init()

        configureWebView(scheme: callbackURLScheme)

        returnBlock = { (url: URL) -> Bool in
            guard let script = self.constructJavaScriptCompletionResult(returnURL: url) else {
                return false
            }

            self.injectWebView(webView: webView, withJavaScript: script)
            return true
        }
    }
    
    // MARK: - Internal Methods

    /// Exposed for testing
    /// 
    /// Constructs custom JavaScript to be injected into the merchant's WKWebView, based on redirectURL details from the SFSafariViewController pop-up result.
    /// - Parameter url: returnURL from the result of the SFSafariViewController being dismissed. Provided via the merchant's AppDelegate or SceneDelegate.
    /// - Returns: JavaScript formatted completion.
    func constructJavaScriptCompletionResult(returnURL: URL) -> String? {
        guard let urlComponents = URLComponents(url: returnURL, resolvingAgainstBaseURL: false),
              urlComponents.scheme?.caseInsensitiveCompare(callbackURLScheme) == .orderedSame,
              urlComponents.host?.caseInsensitiveCompare(hostName) == .orderedSame
        else {
            return nil
        }

        let queryItems = urlComponents.queryItems?.reduce(into: [:]) { partialResult, queryItem in
            partialResult[queryItem.name] = queryItem.value
        }

        let payload = URLDetailsPayload(
            path: urlComponents.path,
            queryItems: queryItems ?? [:],
            hash: urlComponents.fragment
        )

        if let payloadData = try? JSONEncoder().encode(payload),
           let payload = String(data: payloadData, encoding: .utf8) {
            return "window.popupBridge.onComplete(null, \(payload));"
        } else {
            let errorMessage = "Failed to parse query items from return URL."
            let errorResponse = "new Error(\"\(errorMessage)\")"
            return "window.popupBridge.onComplete(\(errorResponse), null);"
        }
    }
    
    /// Injects custom JavaScript into the merchant's webpage.
    /// - Parameter scheme: the url scheme provided by the merchant
    private func configureWebView(scheme: String) {
        webView.configuration.userContentController.add(self, name: messageHandlerName)
        
        let javascript = PopupBridgeUserScript(
            scheme: scheme,
            scriptMessageHandlerName: messageHandlerName,
            host: hostName
        ).rawJavascript
        
        let script = WKUserScript(
            source: javascript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        
        webView.configuration.userContentController.addUserScript(script)
    }
    
    private func injectWebView(webView: WKWebView, withJavaScript script: String) {
        webView.evaluateJavaScript(script) { _, error in
            if let error {
                NSLog("Error: PopupBridge requires onComplete callback. Details: %@", error.localizedDescription)
            }
        }
    }
    
    // MARK: - WKScriptMessageHandler conformance
    
    /// :nodoc: This method is not covered by Semantic Versioning. Do not use.
    ///
    /// Called when the webpage sends a JavaScript message back to the native app
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == messageHandlerName {
            guard let jsonData = try? JSONSerialization.data(withJSONObject: message.body),
                  let script = try? JSONDecoder().decode(WebViewMessage.self, from: jsonData) else {
                return
            }
            
            if let urlString = script.url, let url = URL(string: urlString) {
                webAuthenticationSession.start(url: url, context: self) { url, error in
                    if let error = error {
                        switch error {
                        case ASWebAuthenticationSessionError.canceledLogin:
                            let script = """
                                if (typeof window.popupBridge.onCancel === 'function') {\
                                    window.popupBridge.onCancel();\
                                } else {\
                                    window.popupBridge.onComplete(null, null);\
                                }
                            """

                            self.injectWebView(webView: self.webView, withJavaScript: script)
                            return
                        default:
                            // TODO: handle error
                            return
                        }
                    } else if let url, let returnBlock = self.returnBlock {
                        // TODO: handle this
                        returnBlock(url)
                        return
                    } else {
                        // TODO: handle error
                    }
                }
            } else if let name = script.message?.name {
                delegate.popupBridge?(self, receivedMessage: name, data: script.message?.data)
                return
            }
        }
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding conformance

extension POPPopupBridge: ASWebAuthenticationPresentationContextProviding {

    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        if #available(iOS 15, *) {
            let firstScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
            let window = firstScene?.windows.first { $0.isKeyWindow }
            return window ?? ASPresentationAnchor()
        } else {
            let window = UIApplication.shared.windows.first { $0.isKeyWindow }
            return window ?? ASPresentationAnchor()
        }
    }
}
