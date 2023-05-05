/// A model type to represent details in the [`WKScriptMessage.body`](https://developer.apple.com/documentation/webkit/wkscriptmessage/1417901-body), sent by JavaScript code from a webpage.
struct WebViewMessage: Codable {
    
    let url: String?
    let message: MessageDetails?
}

struct MessageDetails: Codable {
    
    let name: String
    let data: String
}
