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
        let deepLinkAccessorJS: String
        let deepLinkPropertyAssignment: String

        if let returnURLScheme {
            let deepLinkReturnURLPrefix = "\(returnURLScheme)://\(host)/"
            deepLinkAccessorJS = """

                        window.popupBridge.getDeepLinkReturnUrlPrefix = function getDeepLinkReturnUrlPrefix() {
                            return '\(deepLinkReturnURLPrefix)';
                        };
            """
            deepLinkPropertyAssignment = """

            window.popupBridge.deepLinkReturnUrlPrefix = '\(deepLinkReturnURLPrefix)';
            """
        } else {
            deepLinkAccessorJS = ""
            deepLinkPropertyAssignment = ""
        }

        return """
        ;(function () {
            if (!window.popupBridge) { window.popupBridge = {}; };

            window.popupBridge.getReturnUrlPrefix = function getReturnUrlPrefix() {
                return '\(returnURLPrefix)';
            };\(deepLinkAccessorJS)\(deepLinkPropertyAssignment)

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
