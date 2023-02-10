import Foundation
import SafariServices

public class POPPopupBridgeSwift: NSObject, WKScriptMessageHandler, SFSafariViewControllerDelegate {
    
    // Constants
    let kPOPScriptMessageHandlerName = "POPPopupBridge"
    let kPOPURLHost = "popupbridgev1"
    
    // Properties
    let webView: WKWebView
    let delegate: POPPopupBridgeDelegateSwift
    var scheme: String?
    var safariViewController: SFSafariViewController?
    
    private static var returnBlock: ((URL?) -> Bool)?
    
    // TODO: - make unfailable
    init?(webView: WKWebView, delegate: POPPopupBridgeDelegateSwift) {
        guard let scheme = scheme else {
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
        let javascript = javascriptTemplate
            .replacingOccurrences(of: "%%SCHEME%%", with: scheme)
            .replacingOccurrences(of: "%%SCRIPT_MESSAGE_HANDLER_NAME%%", with: kPOPScriptMessageHandlerName)
            .replacingOccurrences(of: "%%HOST%%", with: kPOPURLHost)
        let script = WKUserScript(
            source: javascript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        webView.configuration.userContentController.addUserScript(script)
        
//        weak var weakSelf = self
        POPPopupBridgeSwift.returnBlock = { (url : URL?) -> Bool in
            let error = "null"
            let payload = "null"
            let script: String
    
            if let url {
                let urlComponents = URLComponents.init(url: url, resolvingAgainstBaseURL: false)
                let path = urlComponents?.path
    
                if (urlComponents?.scheme?.localizedCaseInsensitiveCompare(scheme) != ComparisonResult.orderedSame ||
                    urlComponents?.host?.localizedCaseInsensitiveCompare(self.kPOPURLHost) != ComparisonResult.orderedSame) {
                    return false
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
                    let payload = String(data: payloadData, encoding: .utf8)!
                    
                    script = "window.popupBridge.onComplete(null, \(payload);"
                } catch {
                    script = "window.popupBridge.onComplete(null, null);"
                }

            } else {
                script = """
                if (typeof window.popupBridge.onCancel === 'function') {\
                  window.popupBridge.onCancel();\
                } else {\
                  window.popupBridge.onComplete(null, null);\
                }
                """
            }
            
            self.injectWebView(webView: webView, withJavaScript: script)
            return true
        }
    }
    
    func setReturlURLScheme(returnURLScheme: String) {
        scheme = returnURLScheme
    }

    let javascriptTemplate = "        ;(function () {            if (!window.popupBridge) { window.popupBridge = {}; };                        window.popupBridge.getReturnUrlPrefix = function getReturnUrlPrefix() {                return '%%SCHEME%%://%%HOST%%/';            };                        window.popupBridge.open = function open(url) {                window.webkit.messageHandlers.%%SCRIPT_MESSAGE_HANDLER_NAME%%.postMessage({                    url: url                });            };                        window.popupBridge.sendMessage = function sendMessage(message, data) {                window.webkit.messageHandlers.%%SCRIPT_MESSAGE_HANDLER_NAME%%.postMessage({                    message: {                        name: message,                        data: data                    }                });            };                        return 0;        })();"

    static func openURL(url: URL, sourceApplication: String) -> Bool {
        return POPPopupBridgeSwift.openURL(url: url)
    }
    
    static func openURL(url: URL, options: [UIApplication.OpenURLOptionsKey: Any]) -> Bool {
        return POPPopupBridgeSwift.openURL(url: url)
    }
    
    static func openURL(url: URL) -> Bool {
        if let returnBlock {
            return returnBlock(url)
        } else {
            return false
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
    
    public func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        //
    }
    
    // MARK: - WKScriptMessageHandler conformance
    // Receives messages from JS
    
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == kPOPScriptMessageHandlerName {
            let params = message.body as! [String: Any]
            let urlString = params["url"] as! String?
            if urlString != nil {
                dismissSafariViewController()
                
                let url = URL(string: urlString!)
                
                // do we need to do this responds to selector thing?
                if delegate.responds(to: #selector(POPPopupBridgeDelegate.popupBridge(_:willOpen:))) {
                    delegate.popupBridge?(self, willOpenURL: url!)
                }
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
        webView.evaluateJavaScript(script) { result, error in
            if let error {
                // TODO log error
            }
        }
    }
    
}
