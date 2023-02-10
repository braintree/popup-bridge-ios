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
    
    // TODO: - make unfailable
    @objc public init?(webView: WKWebView, delegate: POPPopupBridgeDelegateSwift) {
        guard let scheme = POPPopupBridgeSwift.scheme else {
            // TODO: - Raise exception
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
    
    public static func setReturnURLScheme(_ returnURLScheme: String) {
        self.scheme = returnURLScheme
    }

    public static func openURL(url: URL, sourceApplication: String) -> Bool {
        return POPPopupBridgeSwift.openURL(url: url)
    }
    
    public static func openURL(url: URL, options: [UIApplication.OpenURLOptionsKey: Any]) -> Bool {
        return POPPopupBridgeSwift.openURL(url: url)
    }
    
    public static func openURL(url: URL) -> Bool {
        if let returnBlock {
            return returnBlock(url)
        } else {
            return false
        }
    }
    
    func parseResponseFromPopUpToPassBacktoWebView(url: URL) -> String? {
        let urlComponents = URLComponents.init(url: url, resolvingAgainstBaseURL: false)
        let path = urlComponents?.path
        
        guard let scheme = POPPopupBridgeSwift.scheme,
              urlComponents?.scheme?.caseInsensitiveCompare(scheme) == .orderedSame,
              urlComponents?.host?.caseInsensitiveCompare(kPOPURLHost) == .orderedSame
        else {
            return nil
        }
        
        self.dismissSafariViewController()
        
        var payloadDictionary: [String: Any] = [:]
        payloadDictionary["path"] = path
        payloadDictionary["queryItems"] = self.dictionaryFor(queryString: url.query!)
        if let fragment = url.fragment {
            payloadDictionary["hash"] = fragment
        }
        
        do {
            let payloadData = try JSONSerialization.data(withJSONObject: payloadDictionary)
            
            let load = NSString.init(data: payloadData, encoding: NSUTF8StringEncoding) // why formatted different?
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
            let urlString = params["url"] as! String?
            if let url = URL(string: urlString!) {
                dismissSafariViewController()
                                
//                 do we need to do this responds to selector thing?
                if delegate.responds(to: #selector(POPPopupBridgeDelegate.popupBridge(_:willOpen:))) {
                    delegate.popupBridge?(self, willOpenURL: url)
                }
                
                safariViewController = SFSafariViewController(url: url)
                safariViewController?.delegate = self
                self.delegate.popupBridge(self, requestsPresentationOfViewController: safariViewController)
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
    
    func dictionaryFor(queryString: String) -> Dictionary<String, String?> {
        var parameters: [String: String?] = [:]
        let components = queryString.components(separatedBy: "&")
        for keyValueString in components {
            if keyValueString.count == 0 {
                continue
            }
            
            let keyValueArray = keyValueString.components(separatedBy: "=")
            let key = percentDecodedStringFor(string: keyValueArray[0])
//            if (key = nil) {
//                continue
//            }
            if keyValueArray.count == 2 {
                let value = percentDecodedStringFor(string: keyValueArray[1])
                parameters[key] = value
            } else {
                parameters[key] = nil
            }
        }
        
        return parameters
    }
    
    func percentDecodedStringFor(string: String) -> String {
        return string.replacingOccurrences(of: "+", with: " ").removingPercentEncoding ?? "" // todo
    }
    
    func injectWebView(webView: WKWebView, withJavaScript script: String) {
        webView.evaluateJavaScript(script) { _, error in
            if let error {
                NSLog("Error: PopupBridge requires onComplete callback. Details: %@", error.localizedDescription)
            }
        }
    }
    
}
