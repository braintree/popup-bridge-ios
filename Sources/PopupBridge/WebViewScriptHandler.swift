import UIKit
import WebKit

class WebViewScriptHandler: NSObject {
    
    weak var proxy: WKScriptMessageHandler?
    
    init(proxy: WKScriptMessageHandler) {
        self.proxy = proxy
    }
    
}

extension WebViewScriptHandler: WKScriptMessageHandler {
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        proxy?.userContentController(userContentController, didReceive: message)
    }
    
}
