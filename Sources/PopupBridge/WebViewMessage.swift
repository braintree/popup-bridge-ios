/// A model type to represent details in the [`WKScriptMessage.body`](https://developer.apple.com/documentation/webkit/wkscriptmessage/1417901-body), sent by JavaScript code from a webpage.
struct WebViewMessage: Codable {
    
    let url: String?
    let message: MessageDetails?
    let launchPayPalAppSwitch: String?

    enum CodingKeys: String, CodingKey {
        case url
        case message
        // The wire protocol key stays `launchApp` (the JS contract used by
        // `window.popupBridge.launchApp(url)`); only the Swift property name is
        // PayPal-specific to signal this is an exclusive PayPal app switch flow.
        case launchPayPalAppSwitch = "launchApp"
    }
}

struct MessageDetails: Codable {
    
    let name: String
    let data: String
}
