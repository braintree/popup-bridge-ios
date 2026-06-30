import Foundation

/// Response details returned to the merchant's JavaScript `POPPopupBridge.onComplete()` callback
struct URLDetailsPayload: Encodable {

    var path: String
    var queryItems: [String: String]
    var hash: String?
}

extension URLDetailsPayload {

    /// Builds a payload from a return URL's components, flattening query items into a dictionary.
    init(components: URLComponents) {
        let queryItems = components.queryItems?.reduce(into: [String: String]()) { partialResult, queryItem in
            partialResult[queryItem.name] = queryItem.value
        } ?? [:]

        self.init(
            path: components.path,
            queryItems: queryItems,
            hash: components.fragment
        )
    }
}
