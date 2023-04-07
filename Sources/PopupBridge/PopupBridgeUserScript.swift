import Foundation

struct PopupBridgeUserScript {

    let scheme: String
    let scriptMessageHandlerName: String
    let host: String
    
    var rawJavascript: String {
        """
        ;(function () {
            if (!window.popupBridge) { window.popupBridge = {}; };

            window.popupBridge.getReturnUrlPrefix = function getReturnUrlPrefix() {
                return '\(scheme)://\(host)/';
            };
            
            window.popupBridge.open = function open(url) {
                window.webkit.messageHandlers.\(scriptMessageHandlerName)
                    .postMessage({
                    url: url
                });
            };
        
            window.popupBridge.sendMessage = function sendMessage(message, data) {
                window.webkit.messageHandlers.\(scriptMessageHandlerName)
                    .postMessage({
                    message: {
                        name: message,
                        data: data
                    }
                });
            };
        
            return 0;
        })();
        """
    }
}
