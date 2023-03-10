import Foundation
import SafariServices

@objcMembers
public class POPPopupBridgeSwift: NSObject, WKScriptMessageHandler, SFSafariViewControllerDelegate {
    
    // MARK: - Private Properties
    
    private let messageHandlerName = "POPPopupBridge"
    private let hostName = "popupbridgev1"
    
    private let webView: WKWebView
    private let delegate: POPPopupBridgeDelegateSwift
    private var safariViewController: SFSafariViewController?
    
    private static var scheme: String?
    private static var returnBlock: ((URL) -> Bool)?
    
    // MARK: - Initializer
    
    // TODO: - make unfailable
    public init?(webView: WKWebView, delegate: POPPopupBridgeDelegateSwift) {
        // TODO: - require scheme in init, versus injecting via static method.
        guard let scheme = POPPopupBridgeSwift.scheme else {
            let exception = NSException(
                name: NSExceptionName(rawValue: "POPPopupBridgeSchemeNotSet"),
                reason: "PopupBridge requires a URL scheme to be set"
            )
            exception.raise()
            return nil
        }
        
        self.webView = webView
        self.delegate = delegate
        
        super.init()
        
        configureWebView(scheme: scheme)
        
        // TODO: - Remove returnBlock definition from init
        POPPopupBridgeSwift.returnBlock = { (url : URL) -> Bool in
            guard let script = self.constructJavaScriptCompletionResult(returnURL: url) else {
                return false
            }
            
            self.injectWebView(webView: webView, withJavaScript: script)
            return true
        }
    }
    
    // MARK: - Public Methods
    
    // TODO: - Remove this static method and require scheme in init
    /// Set the URL Scheme that you have registered in your Info.plist.
    public static func setReturnURLScheme(_ returnURLScheme: String?) {
        self.scheme = returnURLScheme
    }
    
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
        guard let urlComponents = URLComponents.init(url: returnURL, resolvingAgainstBaseURL: false),
              let scheme = POPPopupBridgeSwift.scheme,
              urlComponents.scheme?.caseInsensitiveCompare(scheme) == .orderedSame,
              urlComponents.host?.caseInsensitiveCompare(hostName) == .orderedSame
        else {
            return nil
        }
        
        self.dismissSafariViewController()
        
        print(urlComponents)
        
        var payloadDictionary: [String: Any] = [:]
        payloadDictionary["path"] = urlComponents.path
        payloadDictionary["queryItems"] = returnURL.queryDictionary
        payloadDictionary["hash"] = urlComponents.fragment
        
        do {
            let payloadData = try JSONSerialization.data(withJSONObject: payloadDictionary)
            
            let payload = String(data: payloadData, encoding: .utf8)!
            
            return "window.popupBridge.onComplete(null, \(payload));"
        } catch {
            let errorMessage = "Failed to parse query items from return URL. \(error.localizedDescription)"
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
    
    // TODO: - Make below methods private by moving protocol conformances into helper classes.
    
    // MARK: - SFSafariViewControllerDelegate conformance
    
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
    
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == kPOPScriptMessageHandlerName {
            let params = message.body as! [String: Any]
            if let urlString = params["url"] as! String?,
               let url = URL(string: urlString) {
                dismissSafariViewController()
                
                delegate.popupBridge?(self, willOpenURL: url)
                
                safariViewController = SFSafariViewController(url: url)
                safariViewController?.delegate = self
                self.delegate.popupBridge(self, requestsPresentationOfViewController: safariViewController!)
                return
            }
            
            // TODO - this parsing is awful
            if let name = (params as? [String: [String: String]])?["message"]?["name"] {
                let data = (params as? [String: [String: String]])?["message"]?["data"]
                delegate.popupBridge?(self, receivedMessage: name, data: data)
            }
        }
    }
    
}
