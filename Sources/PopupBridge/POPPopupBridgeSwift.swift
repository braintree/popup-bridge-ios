import Foundation
import SafariServices

@objcMembers
public class POPPopupBridgeSwift: NSObject, WKScriptMessageHandler, SFSafariViewControllerDelegate {
    
    // Constants
    let kPOPScriptMessageHandlerName = "POPPopupBridge"
    let kPOPURLHost = "popupbridgev1"
    
    // Properties
    let webView: WKWebView
    let delegate: POPPopupBridgeDelegateSwift
    static var scheme: String?
    var safariViewController: SFSafariViewController?
    
    private static var returnBlock: ((URL) -> Bool)?
    
    // TODO: - make unfailable & require scheme in init, versus injecting via static method.
    @objc public init?(webView: WKWebView, delegate: POPPopupBridgeDelegateSwift) {
        guard let scheme = POPPopupBridgeSwift.scheme else {
            let exception = NSException(
                name: NSExceptionName(rawValue: "POPPopupBridgeSchemeNotSet"),
                reason: "PopupBridge requires a URL scheme to be set"
            )
            exception.raise()
            return nil
        }
        
        // Step 1 - get merchant's webView
        self.webView = webView
        self.delegate = delegate // merchant implements POPUpBridgeDelegate
        
        super.init() // do we need this?
        
        // Step 2 - construct a POPMessageDelegate
        let scriptMessageHandler = POPWeakScriptMessageDelegateSwift(delegate: self)
        webView.configuration.userContentController.add(scriptMessageHandler, name: kPOPScriptMessageHandlerName)
        
        
        // Step 3 - Create javascript code and inject into WebView
        let javascript = UserScript(
            scheme: scheme,
            scriptMessageHandlerName: kPOPScriptMessageHandlerName,
            host: kPOPURLHost
        ).rawJavascript
        
        let script = WKUserScript(
            source: javascript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        webView.configuration.userContentController.addUserScript(script)
        
//        weak var weakSelf = self
        // Handle URL from pop up
        POPPopupBridgeSwift.returnBlock = { (url : URL) -> Bool in
            guard let script = self.parseResponseFromPopUpToPassBacktoWebView(url: url) else {
                return false
            }
            
            self.injectWebView(webView: webView, withJavaScript: script)
            return true
        }
    }
    
    // TODO: - Remove this static method and require scheme in init
    public static func setReturnURLScheme(_ returnURLScheme: String?) {
        self.scheme = returnURLScheme
    }

    public static func openURL(url: URL, sourceApplication: String) -> Bool {
        return POPPopupBridgeSwift.openURL(url)
    }
    
    // TODO: - Remove unused methods
    public static func openURL(url: URL, options: [UIApplication.OpenURLOptionsKey: Any]) -> Bool {
        return POPPopupBridgeSwift.openURL(url)
    }
    
    public static func openURL(_ url: URL) -> Bool {
        if let returnBlock {
            return returnBlock(url)
        } else {
            return false
        }
    }
    
    // URL from SceneDelegate --> JS, to be injected back into merchant WebView
    func parseResponseFromPopUpToPassBacktoWebView(url: URL) -> String? {
        guard let urlComponents = URLComponents.init(url: url, resolvingAgainstBaseURL: false),
              let scheme = POPPopupBridgeSwift.scheme,
              urlComponents.scheme?.caseInsensitiveCompare(scheme) == .orderedSame,
              urlComponents.host?.caseInsensitiveCompare(kPOPURLHost) == .orderedSame
        else {
            return nil
        }
        
        self.dismissSafariViewController()
        
        print(urlComponents)
        
        var payloadDictionary: [String: Any] = [:]
        payloadDictionary["path"] = urlComponents.path
        payloadDictionary["queryItems"] = url.queryDictionary
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
    
    func dismissSafariViewController() {
        if let safariViewController {
            if delegate.responds(to: #selector(POPPopupBridgeDelegate.popupBridge(_:requestsDismissalOf:))) {
                delegate.popupBridge(self, requestsDismissalOfViewController: safariViewController)
            }
        }
    }
    
    // MARK: - SFSafariViewControllerDelegate
    
    // User clicked "Done"
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
    // Receives messages from JS
    
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == kPOPScriptMessageHandlerName {
            let params = message.body as! [String: Any]
            if let urlString = params["url"] as! String?,
               let url = URL(string: urlString) {
                dismissSafariViewController()
                                
//                 do we need to do this responds to selector thing?
//                if delegate.responds(to: #selector(POPPopupBridgeDelegate.popupBridge(_:willOpen:))) {
                delegate.popupBridge?(self, willOpenURL: url)
//                }
                
                safariViewController = SFSafariViewController(url: url)
                safariViewController?.delegate = self
                self.delegate.popupBridge(self, requestsPresentationOfViewController: safariViewController!)
                return
            }
            
            // TODO - this parsing is awful
            if let name = (params as? [String: [String: String]])?["message"]?["name"],
               delegate.responds(to: #selector(POPPopupBridgeDelegate.popupBridge(_:receivedMessage:data:))) {
                let data = (params as? [String: [String: String]])?["message"]?["data"]
                delegate.popupBridge?(self, receivedMessage: name, data: data)
            }
        }
    }
    
    // MARK: - Helpers
    
    func injectWebView(webView: WKWebView, withJavaScript script: String) {
        webView.evaluateJavaScript(script) { _, error in
            if let error {
                NSLog("Error: PopupBridge requires onComplete callback. Details: %@", error.localizedDescription)
            }
        }
    }
    
}
