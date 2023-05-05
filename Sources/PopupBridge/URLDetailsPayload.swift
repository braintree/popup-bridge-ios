/// Response details returned to the merchant's JavaScript `POPPopupBridge.onComplete()` callback
struct URLDetailsPayload: Encodable {
    
    var path: String
    var queryItems: [String: String]
    var hash: String?
}
