import WebKit

/// An internal class used to obfuscate `WKScriptMessageHandler` conformance from the merchant-facing `POPPopupBridge` API.
class JavaScriptMessageHandler: NSObject, WKScriptMessageHandler {
        
    private let didReceiveMessage: (WKScriptMessage) -> Void
    
    /// Initialize a `JavaScriptMessageHandler`.
    /// - Parameter callback: The code to be invoked when `userContentController.didReceiveScriptMessage` is called.
    init(didReceiveMessage callback: @escaping (WKScriptMessage) -> Void) {
        self.didReceiveMessage = callback
    }
    
    // MARK: - WKScriptMessageHandler
    
    /// A webpage sent a JavaScript message.
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        didReceiveMessage(message)
    }
}
