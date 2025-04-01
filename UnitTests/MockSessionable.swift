import Foundation
@testable import PopupBridge

class MockSession: Sessionable {
    
    var requestedURL: URL?
    var requestedBody: Data?
    var requestHttpMethod: String?
    var requestAllHTTPHeaderFields: [String: String] = [:]
    var response: (data: Data, response: URLResponse)?
    var error: Error?
    
    func data(for request: URLRequest, delegate: (any URLSessionTaskDelegate)?) async throws -> (Data, URLResponse) {
        
        requestedURL = request.url
        requestedBody = request.httpBody
        requestHttpMethod = request.httpMethod
        requestAllHTTPHeaderFields = request.allHTTPHeaderFields ?? [:]
        
        if let error {
            throw error
        } else if let response {
            return response
        } else {
            throw NetworkError.invalidResponse
        }
    }
}
