import Foundation

struct PopupBridgeUserScript {
    let scheme: String
    let scriptMessageHandlerName: String
    let host: String
    let isVenmoInstalled: Bool
    let isPayPalInstalled: Bool
    let returnURLScheme: String?

    var rawJavascript: String {
        let returnURLPrefix = "\(scheme)://\(host)/"
        let deepLinkJs: String
        let deepLinkProperty: String

        if let returnURLScheme {
            let deepLinkReturnURLPrefix = "\(returnURLScheme)://\(host)/"
            deepLinkJs = """

                        window.popupBridge.getDeepLinkReturnUrlPrefix = function getDeepLinkReturnUrlPrefix() {
                            return '\(deepLinkReturnURLPrefix)';
                        };
            """
            deepLinkProperty = """

            window.popupBridge.deepLinkReturnUrlPrefix = '\(deepLinkReturnURLPrefix)';
            """
        } else {
            deepLinkJs = ""
            deepLinkProperty = ""
        }

        return """
        ;(function () {
            if (!window.popupBridge) { window.popupBridge = {}; };

            window.popupBridge.getReturnUrlPrefix = function getReturnUrlPrefix() {
                return '\(returnURLPrefix)';
            };\(deepLinkJs)\(deepLinkProperty)

            window.popupBridge.isVenmoInstalled = \(isVenmoInstalled);
            window.popupBridge.isPayPalInstalled = \(isPayPalInstalled);

            window.popupBridge.launchApp = function launchApp(url) {
                window.webkit.messageHandlers.\(scriptMessageHandlerName).postMessage({
                    launchApp: url
                });
            };

            window.popupBridge.open = function open(url) {
                window.webkit.messageHandlers.\(scriptMessageHandlerName).postMessage({
                    url: url
                });
            };

            window.popupBridge.sendMessage = function sendMessage(message, data) {
                window.webkit.messageHandlers.\(scriptMessageHandlerName).postMessage({
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
