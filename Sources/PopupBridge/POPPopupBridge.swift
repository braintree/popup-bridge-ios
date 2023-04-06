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
        
        // TODO: - Remove returnBlock definition from init
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
                
        // TODO: - Use URLComponents.queryItems and move parsing logic into Encodable struct
        var payloadDictionary: [String: Any] = [:]
        payloadDictionary["path"] = urlComponents.path
        payloadDictionary["queryItems"] = returnURL.queryDictionary
        payloadDictionary["hash"] = urlComponents.fragment
        
        do {
            let payloadData = try JSONSerialization.data(withJSONObject: payloadDictionary)
            
            if let payload = String(data: payloadData, encoding: .utf8) {
                return "window.popupBridge.onComplete(null, \(payload));"
            } else {
                // TODO: - Add unit test for this case & refactor error creation logic
                let errorMessage = "Failed to encode URL parameters to JSON."
                let errorResponse = "new Error(\"\(errorMessage)\")"
                return "window.popupBridge.onComplete(null, \(errorResponse));"
            }
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
        if message.name == messageHandlerName {
            guard let params = message.body as? [String: Any] else {
                // TODO: - create error case & add unit test
                return
            }
            
            if let urlString = params["url"] as? String,
               let url = URL(string: urlString) {
                dismissSafariViewController()
                
                delegate.popupBridge?(self, willOpenURL: url)
                
                let viewController = SFSafariViewController(url: url)
                self.delegate.popupBridge(self, requestsPresentationOfViewController: viewController)
                
                safariViewController = viewController
                safariViewController?.delegate = self
                return
            }
            
            // TODO: - Use struct for nested dictionary decoding instead
            if let name = (params as? [String: [String: String]])?["message"]?["name"] {
                let data = (params as? [String: [String: String]])?["message"]?["data"]
                delegate.popupBridge?(self, receivedMessage: name, data: data)
            }
        }
    }
    
}
