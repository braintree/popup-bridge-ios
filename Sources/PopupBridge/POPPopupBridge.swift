import Foundation
import SafariServices
import WebKit

@objcMembers
public class POPPopupBridge: NSObject, WKScriptMessageHandler, SFSafariViewControllerDelegate {
    
    // MARK: - Private Properties
    
    private let messageHandlerName = "POPPopupBridge"
    private let hostName = "popupbridgev1"
    
    private let webView: WKWebView
    private let urlScheme: String
    private let delegate: POPPopupBridgeDelegate
    private var safariViewController: SFSafariViewController?
    
    private static var returnBlock: ((URL) -> Bool)?
    
    // MARK: - Initializer
        
    /// Initialize a Popup Bridge.
    /// - Parameters:
    ///   - webView: The web view to add a script message handler to. Do not change the web view's configuration or user content controller after initializing Popup Bridge.
    ///   - urlScheme: The URL Scheme that you have registered in your Info.plist.
    ///   - delegate: A delegate that presents and dismisses the pop-up (a SFSafariViewController).
    public init(
        webView: WKWebView,
        urlScheme: String,
        delegate: POPPopupBridgeDelegate
    ) {
        self.webView = webView
        self.urlScheme = urlScheme
        self.delegate = delegate
        
        super.init()
        
        configureWebView(scheme: urlScheme)
        
        POPPopupBridge.returnBlock = { (url : URL) -> Bool in
            guard let script = self.constructJavaScriptCompletionResult(returnURL: url) else {
                return false
            }
            
            self.injectWebView(webView: webView, withJavaScript: script)
            return true
        }
    }
    
    // MARK: - Public Methods
    
    /// Handle completion of the popup flow by calling this method from either
    /// your scene:openURLContexts: scene delegate method or
    /// your application:openURL:sourceApplication:annotation: app delegate method.
    @objc(openURL:)
    public static func open(url: URL) -> Bool {
        if let returnBlock {
            return returnBlock(url)
        } else {
            return false
        }
    }
    
    // MARK: - Internal Methods
    
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
    
    /// Constructs custom JavaScript to be injected into the merchant's WKWebView, based on redirectURL details from the SFSafariViewController pop-up result.
    /// - Parameter url: returnURL from the result of the SFSafariViewController being dismissed. Provided via the merchant's AppDelegate or SceneDelegate.
    /// - Returns: JavaScript formatted completion.
    private func constructJavaScriptCompletionResult(returnURL: URL) -> String? {
        guard let urlComponents = URLComponents(url: returnURL, resolvingAgainstBaseURL: false),
              urlComponents.scheme?.caseInsensitiveCompare(urlScheme) == .orderedSame,
              urlComponents.host?.caseInsensitiveCompare(hostName) == .orderedSame
        else {
            return nil
        }
        
        self.dismissSafariViewController()

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
    
    private func dismissSafariViewController() {
        if let safariViewController {
            delegate.popupBridge(self, requestsDismissalOfViewController: safariViewController)
        }
    }
    
    private func injectWebView(webView: WKWebView, withJavaScript script: String) {
        webView.evaluateJavaScript(script) { _, error in
            if let error {
                NSLog("Error: PopupBridge requires onComplete callback. Details: %@", error.localizedDescription)
            }
        }
    }
        
    // MARK: - SFSafariViewControllerDelegate conformance
    
    /// :nodoc: This method is not covered by Semantic Versioning. Do not use.
    ///
    /// Called when the user exits the pop-up (SFSafariViewController) by clicking "Done"
    public func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        let script = """
            if (typeof window.popupBridge.onCancel === 'function') {\
              window.popupBridge.onCancel();\
            } else {\
              window.popupBridge.onComplete(null, null);\
            }
            """
        injectWebView(webView: webView, withJavaScript: script)
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
            
            if let urlString = script.url,
               let url = URL(string: urlString) {
                dismissSafariViewController()
                
                delegate.popupBridge?(self, willOpenURL: url)
                
                let viewController = SFSafariViewController(url: url)
                safariViewController = viewController
                safariViewController?.delegate = self
                
                self.delegate.popupBridge(self, requestsPresentationOfViewController: viewController)
                return
            } else if let name = script.message?.name {
                delegate.popupBridge?(self, receivedMessage: name, data: script.message?.data)
                return
            }
        }
    }
}
