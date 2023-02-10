import Foundation

@objc public class POPWeakScriptMessageDelegateSwift: NSObject, WKScriptMessageHandler {
    
    let delegate: WKScriptMessageHandler // must be weak?
    
    @objc public init(delegate: WKScriptMessageHandler) {
        self.delegate = delegate
    }
    
    // MARK: - WKScriptMessageHandler conformance
    
    @objc public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        delegate.userContentController(userContentController, didReceive: message)
    }
    
}
