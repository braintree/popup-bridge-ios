/// A model type to represent details in the [`WKScriptMessage.body`](https://developer.apple.com/documentation/webkit/wkscriptmessage/1417901-body)
struct ScriptMessage: Codable {
    
    let url: String?
    let message: MessageDetails?
}

struct MessageDetails: Codable {
    
    let name: String
    let data: String
}
