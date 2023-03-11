import WebKit

typealias UserContentControllerDidReceiveMessage = (WKScriptMessage) -> ()

class WKHelper: NSObject, WKScriptMessageHandler {
        
    private let callback: UserContentControllerDidReceiveMessage
    
    init(callback: @escaping UserContentControllerDidReceiveMessage) {
        self.callback = callback
    }
    
    // MARK: - WKScriptMessageHandler
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        callback(message)
    }
    
}
