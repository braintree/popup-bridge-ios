import Foundation
@testable import PopupBridge

class MockSession: Sessionable {
    
    var mockData: Data?
    var mockResponse: URLResponse?
    
    func data(for request: URLRequest, delegate: (any URLSessionTaskDelegate)?) async throws -> (Data, URLResponse) {
        (mockData ?? Data(), mockResponse ?? URLResponse())
    }
}

struct NonEncodable: Encodable {
    
    func encode(to encoder: Encoder) throws {
        throw EncodingError.invalidValue(self, EncodingError.Context(codingPath: [], debugDescription: "Non-Encodable type"))
    }
}
